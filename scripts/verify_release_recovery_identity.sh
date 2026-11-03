#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_EXT_RELEASE_REPO:-${HOME}/projects/harn}"

for ((index = 1; index <= $#; index++)); do
  if [ "${!index}" = "--repo" ]; then
    next=$((index + 1))
    target_repo="${!next:-}"
    break
  fi
done

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  -- \
  "${repo_root}/verify_release_recovery_identity.harn" \
  -- \
  "$@"
