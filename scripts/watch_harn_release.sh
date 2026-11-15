#!/usr/bin/env bash
set -euo pipefail

# Observe canonical publication with GitHub read authority and artifact egress.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_EXT_RELEASE_REPO:-${HOME}/projects/harn}"

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  --workflow-watch-egress \
  -- \
  "${repo_root}/watch_harn_release.harn" \
  -- \
  "$@"
