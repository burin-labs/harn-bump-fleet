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
# Usage: approve_projection_pr.sh <pull-request-number>
# Environment: GH_TOKEN (pull-requests: write), GITHUB_REPOSITORY,
# RELEASE_BOT_LOGIN (default harn-release-bot[bot]), APPROVE_DRY_RUN=1 to decide
# without approving.
set -euo pipefail

pr=${1:?usage: approve_projection_pr.sh <pull-request-number>}
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "pull request number must be numeric: $pr" >&2; exit 2; }
repo=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}
bot=${RELEASE_BOT_LOGIN:-harn-release-bot[bot]}

refuse() {
  echo "::error title=Projection approval refused::#$pr: $1" >&2
  echo "Not approving #$pr: $1" >&2
  exit 1
}

meta=$(gh api "repos/$repo/pulls/$pr") || refuse "the pull request could not be read"
read -r state draft base author author_type head_repo head_ref head_sha < <(
  jq -r '[.state, .draft, .base.ref, .user.login, .user.type,
          (.head.repo.full_name // "-"), .head.ref, .head.sha] | @tsv' <<< "$meta"
) || refuse "the pull request metadata was malformed"

[[ "$state" == open && "$draft" == false ]] || refuse "it is not an open, ready pull request"
[[ "$base" == main ]] || refuse "it does not target main"
[[ "$author" == "$bot" && "$author_type" == Bot ]] || refuse "its author is $author, not $bot"
[[ "$head_repo" == "$repo" ]] || refuse "its head is not in $repo"
[[ "$head_ref" =~ ^automation/fleet-projections-[0-9a-f]+$ ]] || refuse "branch $head_ref is not a projection branch"
[[ "$head_sha" =~ ^[0-9a-f]{40}$ ]] || refuse "its head SHA is malformed"

commits=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/commits?per_page=100" | jq 'add // []') \
  || refuse "the commits could not be read"
jq -e 'length > 0 and all(.[]; .commit.verification.verified == true)' <<< "$commits" > /dev/null \
  || refuse "a commit is missing or not GitHub-verified"

files=$(gh api --paginate --slurp "repos/$repo/pulls/$pr/files?per_page=100" | jq 'add // []') \
  || refuse "the changed files could not be read"
problems=$(jq -r '
  def hunk_lines: split("\n") | map(select(test("^[-+]")));
  def norm: gsub("[0-9a-f]{40}"; "@SHA@");
  if length == 0 then "no files changed" else
  .[]
  | .filename as $f
  | if ($f != "fleet.toml" and $f != ".github/workflows/bump-harn.yml") then "\($f): not a pin projection file"
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
  || refuse "the reviews could not be read"
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
