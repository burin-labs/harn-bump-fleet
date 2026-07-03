#!/usr/bin/env bash
set -euo pipefail

# with_env.sh — source one or more local .env files, then exec the rest of
# the command line. Lets every harness in this repo pick up
# CEREBRAS_API_KEY / OPENROUTER_API_KEY / TOGETHER_AI_API_KEY / etc.
# without committing secrets to the repo or expanding them in the harn
# scripts themselves.
#
# Discovery order (later entries override earlier ones):
#   1. $HARN_BUMP_FLEET_ENV_FILE (single absolute path; default
#      ~/projects/burin-code/.env if that file exists)
#   2. $HARN_BUMP_FLEET_ENV_FILES (colon-separated list of paths)
#   3. ./.env at the repo root (current working directory)
#   4. ./.env.local at the repo root
#
# Missing files are silently skipped — set HARN_ENV_VERBOSE=1 to print
# which files were sourced.
#
# Usage:
#   scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mode ship-pr
#   scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox bump_fleet.harn -- --dry-run

verbose="${HARN_ENV_VERBOSE:-0}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

note() {
  if [ "$verbose" = "1" ]; then
    printf '[with_env] %s\n' "$1" >&2
  fi
}

source_if_present() {
  local file="$1"
  if [ -z "$file" ]; then
    return 0
  fi
  if [ ! -f "$file" ]; then
    note "skip (missing): $file"
    return 0
  fi
  if [ ! -r "$file" ]; then
    note "skip (unreadable): $file"
    return 0
  fi
  note "source: $file"
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
}

default_env="${HARN_BUMP_FLEET_ENV_FILE:-${HOME}/projects/burin-code/.env}"
source_if_present "$default_env"

extra="${HARN_BUMP_FLEET_ENV_FILES:-}"
if [ -n "$extra" ]; then
  IFS=':'
  for f in $extra; do
    source_if_present "$f"
  done
  unset IFS
fi

source_if_present "$(pwd)/.env"
source_if_present "$(pwd)/.env.local"

repo_harn_bin="${repo_root}/.harn/bin"
if [ -x "${repo_harn_bin}/harn" ]; then
  export PATH="${repo_harn_bin}:${PATH}"
  if [ -z "${HARN_BIN:-}" ]; then
    export HARN_BIN="${repo_harn_bin}/harn"
  fi
  note "prepend harn bin: ${repo_harn_bin}"
fi

if [ "$#" -eq 0 ]; then
  echo "with_env.sh: nothing to exec (pass a command after the script path)" >&2
  exit 2
fi

exec "$@"
