#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/harn-project.sh [--tracked-only] <verify|check|lint|fmt-check|format>

By default, verification includes tracked and non-ignored untracked *.harn
sources. CI and committed-tree automation pass --tracked-only.
EOF
  exit 2
}

tracked_only=0
if [ "${1:-}" = "--tracked-only" ]; then
  tracked_only=1
  shift
fi
action="${1:-}"
[ "$#" -eq 1 ] || usage

case "$action" in
  verify|check|lint|fmt-check|format) ;;
  *) usage ;;
esac

inventory="$(mktemp "${TMPDIR:-/tmp}/harn-project-sources.XXXXXX")"
trap 'rm -f "$inventory"' EXIT

if [ "$tracked_only" -eq 1 ]; then
  git ls-files --cached -z -- '*.harn' > "$inventory"
else
  git ls-files --cached --others --exclude-standard -z -- '*.harn' > "$inventory"
fi

sources=()
while IFS= read -r -d '' source; do
  # The ./ prefix keeps a valid leading-dash filename from becoming a CLI flag.
  sources+=("./${source}")
done < "$inventory"

if [ "${#sources[@]}" -eq 0 ]; then
  echo "harn-project: no Harn sources found" >&2
  exit 0
fi

run_check() {
  harn check --strict-types "${sources[@]}"
}

run_lint() {
  harn lint --strict "${sources[@]}"
}

run_fmt_check() {
  harn fmt --check "${sources[@]}"
}

case "$action" in
  verify)
    run_check
    run_lint
    run_fmt_check
    ;;
  check) run_check ;;
  lint) run_lint ;;
  fmt-check) run_fmt_check ;;
  format) harn fmt "${sources[@]}" ;;
esac
