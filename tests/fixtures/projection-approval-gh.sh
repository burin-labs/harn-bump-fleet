#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PROJECTION_APPROVAL_FIXTURE/calls"
repo=${PROJECTION_APPROVAL_REPO:-burin-labs/harn-bump-fleet}
[[ "${1:-}" == api ]] || exit 91
shift
if [[ "${1:-}" == -X ]]; then
  if [[ "$*" == "-X POST repos/$repo/issues/42/labels -f labels[]=ship" ]]; then
    printf 'ship\n' >> "$PROJECTION_APPROVAL_FIXTURE/label-posts"
    printf '[]\n'
    exit 0
  fi
  [[ "${2:-}" == POST && "${3:-}" == "repos/$repo/pulls/42/reviews" ]] || exit 92
  cat > "$PROJECTION_APPROVAL_FIXTURE/review.json"
  printf 'POST\n' >> "$PROJECTION_APPROVAL_FIXTURE/posts"
  printf '{}\n'
  exit 0
fi
case "$*" in
  "repos/$repo/pulls/42 --jq .head.sha")
    cat "$PROJECTION_APPROVAL_FIXTURE/head"
    ;;
  "repos/$repo/pulls/42")
    [[ ! -e "$PROJECTION_APPROVAL_FIXTURE/unreadable" ]] || exit 73
    cat "$PROJECTION_APPROVAL_FIXTURE/meta.json"
    ;;
  "--paginate --slurp repos/$repo/pulls/42/commits?per_page=100")
    cat "$PROJECTION_APPROVAL_FIXTURE/commits.json"
    ;;
  "--paginate --slurp repos/$repo/pulls/42/files?per_page=100")
    cat "$PROJECTION_APPROVAL_FIXTURE/files.json"
    ;;
  "--paginate --slurp repos/$repo/pulls/42/reviews?per_page=100")
    if [[ -e "$PROJECTION_APPROVAL_FIXTURE/reviews.json" ]]; then
      cat "$PROJECTION_APPROVAL_FIXTURE/reviews.json"
    else
      printf '[[]]\n'
    fi
    ;;
  "--paginate --slurp repos/$repo/issues/42/events?per_page=100")
    if [[ -e "$PROJECTION_APPROVAL_FIXTURE/events.json" ]]; then
      cat "$PROJECTION_APPROVAL_FIXTURE/events.json"
    else
      printf '[[]]\n'
    fi
    ;;
  'repos/burin-labs/harn/releases?per_page=20 --jq '*)
    printf 'v0.10.185\n'
    ;;
  'repos/burin-labs/harn/commits/v0.10.185 --jq .sha')
    cat "$PROJECTION_APPROVAL_FIXTURE/released"
    ;;
  'repos/burin-labs/harn/releases/tags/v0.10.191 --jq '*)
    cat "$PROJECTION_APPROVAL_FIXTURE/release-state"
    ;;
  graphql\ *)
    cat "$PROJECTION_APPROVAL_FIXTURE/threads"
    ;;
  "repos/$repo/commits/"*"/check-runs?per_page=100")
    cat "$PROJECTION_APPROVAL_FIXTURE/checks.json"
    ;;
  *)
    printf 'Unexpected fixture request: %s\n' "$*" >&2
    exit 93
    ;;
esac
