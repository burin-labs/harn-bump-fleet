#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/harn-project.sh [--tracked-only] <verify|check|lint|fmt-check|format|test>

By default, verification includes tracked and non-ignored untracked *.harn
sources. CI and committed-tree automation pass --tracked-only. The test action
runs the canonical suite with the same repo-pinned Harn binary.
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
  verify|check|lint|fmt-check|format|test) ;;
  *) usage ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
harn_bin="${repo_root}/.harn/bin/harn"
pin_file="${repo_root}/.harn-version"
install_harn="${repo_root}/scripts/install_harn.sh"
if [ ! -f "$pin_file" ]; then
  echo "harn-project: missing ${pin_file}" >&2
  exit 2
fi
expected_version="$(tr -d '[:space:]' < "$pin_file")"
expected_version="${expected_version#v}"
installed_version=""
if [ -x "$harn_bin" ]; then
  installed_version="$("$harn_bin" --version 2>/dev/null | awk 'NR == 1 { print $2 }')"
fi
if [ "$installed_version" != "$expected_version" ]; then
  if [ ! -x "$install_harn" ]; then
    echo "harn-project: pinned harn ${expected_version} is missing; run scripts/install_harn.sh" >&2
    exit 127
  fi
  echo "harn-project: installing pinned harn ${expected_version} (found ${installed_version:-none})" >&2
  "$install_harn" "$expected_version" >&2
  installed_version="$("$harn_bin" --version 2>/dev/null | awk 'NR == 1 { print $2 }')"
  if [ "$installed_version" != "$expected_version" ]; then
    echo "harn-project: install produced ${installed_version:-no version}, expected ${expected_version}" >&2
    exit 1
  fi
fi

if [ "$action" = "test" ]; then
  cd "$repo_root"
  exec "$harn_bin" test tests/ --parallel --verbose
fi

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
  "$harn_bin" check --strict-types "${sources[@]}"
}

run_lint() {
  "$harn_bin" lint --strict "${sources[@]}"
}

run_fmt_check() {
  "$harn_bin" fmt --check "${sources[@]}"
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
  format) "$harn_bin" fmt "${sources[@]}" ;;
esac
