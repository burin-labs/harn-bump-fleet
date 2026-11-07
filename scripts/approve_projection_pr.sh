#!/usr/bin/env bash
# Approve the release bot's own orchestration-pin projection pull request.
#
# A Harn release promotes this repository's orchestration pin through a
# `automation/fleet-projections-<id>` pull request that the release bot opens and
# labels `ship`. Smart Ship lands only an approved head, the bot cannot approve
# its own pull request, and nothing else reviews it, so every release waited for
# a person. This approves one only when its diff is provably nothing but the pin
# move to a published Harn release commit.
#
# Decided from the pull request's data, never from code it carries:
#   1. Author is the release bot, the head is in this repository on a
#      projection branch, it targets main, and every commit is GitHub-verified.
#   2. Only fleet.toml and .github/workflows/bump-harn.yml change, in place. With
#      every 40-hex commit replaced by one token, the removed lines equal the
#      added lines, so nothing but commit pins moved.
#   3. Every added commit is one SHA: the commit of a published stable Harn
#      release.
#   4. No review requests changes.
#
# APPROVAL_SCOPE=consumer applies the same trust anchor (release bot author,
# GitHub-verified commits, head bound) to a fleet consumer repository, where the
# release bot opens two kinds of pull request:
#   runtime bump       `automation/bump-harn-runtime`; only the files named by
#                      `runtime_bump` in projection-approval-paths.json change, in
#                      place, and only a Harn version number moves, to one
#                      published stable release.
#   projection restore `automation/fleet-projections-<id>`; every file is a
#                      fleet-rendered path (`other_projections`, plus the bump
#                      adapter from `orchestration_pin`), and the body's
#                      `Fleet-owned-projection-restore:` trailers name exactly
#                      the changed files.
# Both also need green checks (the `CI status` aggregate) and no unresolved
# review thread. The path lists are the security boundary: one file outside them
# declines the pull request. A consumer pull request that is not yet eligible is
# declined with a receipt and exit 0 so a pending check does not turn a workflow
# red; an unreadable pull request, check list or policy file still exits 1.
#
# Usage: approve_projection_pr.sh <pull-request-number>
# Environment: GH_TOKEN (pull-requests: write, checks: read), GITHUB_REPOSITORY,
# APPROVAL_SCOPE (pin by default, or consumer), RELEASE_BOT_LOGIN (default
# harn-release-bot[bot]), APPROVE_DRY_RUN=1 to decide without approving.
set -euo pipefail

pr=${1:?usage: approve_projection_pr.sh <pull-request-number>}
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "pull request number must be numeric: $pr" >&2; exit 2; }
repo=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}
bot=${RELEASE_BOT_LOGIN:-harn-release-bot[bot]}
scope=${APPROVAL_SCOPE:-pin}
[[ "$scope" == pin || "$scope" == consumer ]] || { echo "APPROVAL_SCOPE must be pin or consumer: $scope" >&2; exit 2; }

# A fault is a read or policy failure and always fails the run. A refusal is a
# decision: it fails the run in the pin scope, and in the consumer scope it
# declines with a receipt, because a pull request waiting for CI is not an error.
fault() {
  echo "::error title=Projection approval fault::#$pr: $1" >&2
  echo "Cannot decide #$pr: $1" >&2
  exit 1
}

refuse() {
  if [[ "$scope" == consumer ]]; then
    jq -cn --arg reason "$1" --argjson pr "$pr" \
      '{schema: "harn.projection-approval.v1", status: "DECLINED", approved: false, pull_request: $pr, reason: $reason}'
    echo "Not approving #$pr: $1" >&2
    exit 0
  fi
  echo "::error title=Projection approval refused::#$pr: $1" >&2
  echo "Not approving #$pr: $1" >&2
  exit 1
}

meta=$(gh api "repos/$repo/pulls/$pr") || fault "the pull request could not be read"
read -r state draft base author author_type head_repo head_ref head_sha < <(
  jq -r '[.state, .draft, .base.ref, .user.login, .user.type,
          (.head.repo.full_name // "-"), .head.ref, .head.sha] | @tsv' <<< "$meta"
) || refuse "the pull request metadata was malformed"

[[ "$state" == open && "$draft" == false ]] || refuse "it is not an open, ready pull request"
[[ "$base" == main ]] || refuse "it does not target main"
[[ "$author" == "$bot" && "$author_type" == Bot ]] || refuse "its author is $author, not $bot"
[[ "$head_repo" == "$repo" ]] || refuse "its head is not in $repo"
if [[ "$scope" == consumer ]]; then
  [[ "$head_ref" == automation/bump-harn-runtime || "$head_ref" =~ ^automation/fleet-projections-[0-9a-f]+$ ]] \
    || refuse "branch $head_ref is not a fleet automation branch"
else
  [[ "$head_ref" =~ ^automation/fleet-projections-[0-9a-f]+$ ]] || refuse "branch $head_ref is not a projection branch"
fi
[[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] || refuse "its head SHA is malformed"

commits=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/commits?per_page=100" | jq 'add // []') \
  || fault "the commits could not be read"
jq -e 'length > 0 and all(.[]; .commit.verification.verified == true)' <<< "$commits" > /dev/null \
  || refuse "a commit is missing or not GitHub-verified"

files=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/files?per_page=100" | jq 'add // []') \
  || fault "the changed files could not be read"
policy="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/projection-approval-paths.json"
jq -e '
  . as $p
  | ($p | keys | sort) == ["orchestration_pin", "other_projections", "runtime_bump"]
    and ([$p[] | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)] | all)
    and ([$p[][]] | length == (unique | length))' "$policy" > /dev/null \
  || fault "the projection approval path policy is invalid"

if [[ "$scope" == consumer ]]; then
  body=$(jq -r '.body // ""' <<< "$meta")
  # Every changed file is read, in place, and carries a textual patch.
  jq -e 'length > 0 and all(.[]; type == "object" and (.filename | type) == "string"
      and .status == "modified" and (.patch | type) == "string" and (.patch | length) > 0
      and (.previous_filename // null) == null)' <<< "$files" > /dev/null \
    || refuse "a changed file is missing, renamed, deleted or has no textual patch"
  changed=$(jq -r '[.[].filename] | sort | .[]' <<< "$files")
  if [[ "$head_ref" == automation/bump-harn-runtime ]]; then
    kind=runtime-bump
    outside=$(jq -r --slurpfile policy "$policy" '.[] | .filename | select(. as $f | $policy[0].runtime_bump | index($f) | not)' <<< "$files")
    [[ -z "$outside" ]] || refuse "files outside the runtime bump allowlist: $(tr '\n' ' ' <<< "$outside")"
    # Line shape: a version number may move, and nothing else on those lines.
    shape_bad=$(jq -r '
      .[] | . as $f
      | .patch | split("\n")[]
      | select(test("^[-+]"))
      | select(
          ($f.filename == ".harn-version" and (test("^[-+][0-9]+\\.[0-9]+\\.[0-9]+$") | not))
          or ($f.filename != ".harn-version" and (test("^[-+](generator_version|protocol_artifact_version) = \"[0-9]+\\.[0-9]+\\.[0-9]+\"$") | not)))
      | "\($f.filename): \(.)"' <<< "$files")
    [[ -z "$shape_bad" ]] || refuse "more than a Harn version number changed: $(tr '\n' ';' <<< "$shape_bad")"
    unbalanced=$(jq -r '.[] | select(([.patch | split("\n")[] | select(startswith("-"))] | length)
        != ([.patch | split("\n")[] | select(startswith("+"))] | length)) | .filename' <<< "$files")
    [[ -z "$unbalanced" ]] || refuse "lines were added or removed, not only replaced: $(tr '\n' ' ' <<< "$unbalanced")"
    versions=$(jq -r '[.[].patch | split("\n")[] | select(startswith("+")) | scan("[0-9]+\\.[0-9]+\\.[0-9]+")] | unique | .[]' <<< "$files")
    [[ "$(wc -l <<< "$versions" | tr -d ' ')" == 1 && "$versions" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
      || refuse "the added versions are not exactly one release: $(tr '\n' ' ' <<< "$versions")"
    published=$(gh api "repos/burin-labs/harn/releases/tags/v$versions" --jq '[.draft, .prerelease] | @tsv' 2>/dev/null || true)
    [[ "$published" == $'false\tfalse' ]] || refuse "v$versions is not a published stable Harn release"
    what="the Harn runtime version to the published v$versions release"
  else
    kind=projection-restore
    allowed=$(jq -c --slurpfile policy "$policy" -n '$policy[0] | (.other_projections + (.orchestration_pin - ["fleet.toml"]))')
    outside=$(jq -r --argjson allowed "$allowed" '.[] | .filename | select(. as $f | $allowed | index($f) | not)' <<< "$files")
    [[ -z "$outside" ]] || refuse "files outside the fleet-rendered allowlist: $(tr '\n' ' ' <<< "$outside")"
    claimed=$(grep -E '^Fleet-owned-projection-restore: ' <<< "$body" | sed 's/^Fleet-owned-projection-restore: //; s/[[:space:]]*$//' | LC_ALL=C sort -u || true)
    [[ -n "$claimed" && "$claimed" == "$changed" ]] \
      || refuse "the restore trailers do not name exactly the changed files"
    what="fleet-rendered projections ($(tr '\n' ' ' <<< "$changed" | sed 's/ $//'))"
  fi

  threads=$(gh api graphql -F owner="${repo%%/*}" -F name="${repo##*/}" -F number="$pr" -f query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) { pullRequest(number: $number) {
        reviewThreads(first: 100) { pageInfo { hasNextPage } nodes { isResolved } } } } }' \
    --jq '.data.repository.pullRequest.reviewThreads | if .pageInfo.hasNextPage then 999 else ([.nodes[] | select(.isResolved | not)] | length) end') \
    || fault "the review threads could not be read"
  [[ "$threads" == 0 ]] || refuse "it has unresolved review threads"
  checks=$(gh api "repos/$repo/commits/$head_sha/check-runs?per_page=100") || fault "the check runs could not be read"
  # This job and Smart Ship's own jobs are running while they decide, so they are
  # not evidence about the change.
  jq -e '.total_count == (.check_runs | length)' <<< "$checks" > /dev/null || fault "the check run list is incomplete"
  pending=$(jq -r '[.check_runs[] | select((.name | startswith("ship /") or contains("Approve fleet PR")) | not)
      | select(.status != "completed" or ((.conclusion // "") | IN("success", "skipped", "neutral") | not)) | .name] | join(", ")' <<< "$checks")
  [[ -z "$pending" ]] || refuse "checks are not green: $pending"
  jq -e 'any(.check_runs[]; .name == "CI status" and .conclusion == "success")' <<< "$checks" > /dev/null \
    || refuse "the CI status check has not succeeded at this head"

  reviews=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/reviews?per_page=100" | jq 'add // []') \
    || fault "the reviews could not be read"
  jq -e 'all(.[]; .state != "CHANGES_REQUESTED")' <<< "$reviews" > /dev/null || refuse "a review requests changes"
  echo "#$pr ($kind) moves only $what."
  [[ "$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)" == "$head_sha" ]] \
    || refuse "the head moved while it was being checked"
  if [[ "${APPROVE_DRY_RUN:-}" == 1 ]]; then
    echo "Dry run: not approving."
    exit 0
  fi
  jq -n --arg sha "$head_sha" --arg what "$what" \
    '{commit_id: $sha, event: "APPROVE", body: "Moves only \($what); author, signature, checks and review threads verified at this head."}' |
    gh api -X POST "repos/$repo/pulls/$pr/reviews" --input - > /dev/null
  echo "Approved #$pr at $head_sha."
  exit 0
fi

classification=$(jq -r --slurpfile policy "$policy" '
  $policy[0] as $p
  | if ($policy | length) != 1
    then error("invalid projection approval path policy")
    elif type != "array" or length == 0
      or (all(.[]; type == "object" and (.filename | type) == "string"
        and (.status | type) == "string" and (.patch | type) == "string"
        and (.patch | length) > 0 and (.previous_filename // null) == null) | not)
    then error("invalid projection file evidence")
    elif all(.[]; .filename as $f | $p.other_projections | index($f) != null)
      and all(.[]; .status == "modified" or .status == "added")
    then "NOT_APPLICABLE"
    elif any(.[]; .filename as $f | $p.orchestration_pin | index($f) != null)
    then "ORCHESTRATION_PIN"
    else "UNRECOGNIZED"
    end' <<< "$files") || refuse "the projection kind could not be established"
if [[ "$classification" == NOT_APPLICABLE ]]; then
  jq -cn --arg head "$head_sha" --argjson files "$files" \
    '{schema: "harn.projection-approval.v1", status: "NOT_APPLICABLE", approved: false, head: $head, paths: [$files[].filename]}'
  exit 0
fi
[[ "$classification" == ORCHESTRATION_PIN ]] || refuse "the changed files are not a recognized projection"
problems=$(jq -r --slurpfile policy "$policy" '
  def hunk_lines: split("\n") | map(select(test("^[-+]")));
  def norm: gsub("[0-9a-f]{40}"; "@SHA@");
  if length == 0 then "no files changed" else
  .[]
  | .filename as $f
  | if ($policy[0].orchestration_pin | index($f)) == null then "\($f): not a pin projection file"
    elif .status != "modified" or (.previous_filename // null) != null then "\($f): status \(.status) is not an in-place edit"
    elif (.patch // null) == null then "\($f): no textual patch"
    else
      (.patch | hunk_lines) as $l
      | if [$l[] | select(startswith("-")) | .[1:] | norm] == [$l[] | select(startswith("+")) | .[1:] | norm]
        then empty else "\($f): changes more than commit pins" end
    end
  end' <<< "$files") || refuse "the changed files were malformed"
[[ -z "$problems" ]] || refuse "$(tr '\n' ';' <<< "$problems")"

added=$(jq -r '[.[] | .patch | split("\n")[] | select(startswith("+")) | scan("[0-9a-f]{40}")] | unique | .[]' <<< "$files")
[[ "$(wc -l <<< "$added" | tr -d ' ')" == 1 && "$added" =~ ^[0-9a-f]{40}$ ]] \
  || refuse "the added pins are not exactly one commit: $(tr '\n' ' ' <<< "$added")"
tag=""
for candidate in $(gh api "repos/burin-labs/harn/releases?per_page=20" \
  --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name'); do
  if [[ "$(gh api "repos/burin-labs/harn/commits/$candidate" --jq .sha)" == "$added" ]]; then
    tag=$candidate
    break
  fi
done
[[ -n "$tag" ]] || refuse "pin $added is not the commit of a recent published Harn release"

reviews=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/reviews?per_page=100" | jq 'add // []') \
  || fault "the reviews could not be read"
jq -e 'all(.[]; .state != "CHANGES_REQUESTED")' <<< "$reviews" > /dev/null \
  || refuse "a review requests changes"

echo "#$pr moves only the orchestration pin to $tag ($added)."
# The checks above read the files after capturing the head; a push in between
# would approve a head they never read.
[[ "$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)" == "$head_sha" ]] \
  || refuse "the head moved while it was being checked"
if [[ "${APPROVE_DRY_RUN:-}" == 1 ]]; then
  echo "Dry run: not approving."
  exit 0
fi
jq -n --arg sha "$head_sha" --arg tag "$tag" \
  '{commit_id: $sha, event: "APPROVE", body: "Moves only the orchestration pin to the published \($tag) release commit."}' |
  gh api -X POST "repos/$repo/pulls/$pr/reviews" --input - > /dev/null
echo "Approved #$pr at $head_sha."
