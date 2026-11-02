#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PROJECTION_APPROVAL_FIXTURE/calls"
[[ "${1:-}" == api ]] || exit 91
shift
if [[ "${1:-}" == -X ]]; then
  [[ "${2:-}" == POST && "${3:-}" == repos/burin-labs/harn-bump-fleet/pulls/42/reviews ]] || exit 92
  cat > "$PROJECTION_APPROVAL_FIXTURE/review.json"
  printf 'POST\n' >> "$PROJECTION_APPROVAL_FIXTURE/posts"
  printf '{}\n'
  exit 0
fi
case "$*" in
  'repos/burin-labs/harn-bump-fleet/pulls/42 --jq .head.sha')
    cat "$PROJECTION_APPROVAL_FIXTURE/head"
    ;;
  'repos/burin-labs/harn-bump-fleet/pulls/42')
    [[ ! -e "$PROJECTION_APPROVAL_FIXTURE/unreadable" ]] || exit 73
    cat "$PROJECTION_APPROVAL_FIXTURE/meta.json"
    ;;
  '--paginate --slurp repos/burin-labs/harn-bump-fleet/pulls/42/commits?per_page=100')
    cat "$PROJECTION_APPROVAL_FIXTURE/commits.json"
    ;;
  '--paginate --slurp repos/burin-labs/harn-bump-fleet/pulls/42/files?per_page=100')
    cat "$PROJECTION_APPROVAL_FIXTURE/files.json"
    ;;
  '--paginate --slurp repos/burin-labs/harn-bump-fleet/pulls/42/reviews?per_page=100')
    printf '[[]]\n'
    ;;
  'repos/burin-labs/harn/releases?per_page=20 --jq '*)
    printf 'v0.10.185\n'
    ;;
  'repos/burin-labs/harn/commits/v0.10.185 --jq .sha')
    cat "$PROJECTION_APPROVAL_FIXTURE/released"
    ;;
  *)
    printf 'Unexpected fixture request: %s\n' "$*" >&2
    exit 93
    ;;
esac
