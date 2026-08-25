#!/usr/bin/env bash
set -euo pipefail

# One supported boundary for the long-running live watcher. Terminal cleanup
# deletes only exact, observed refs under an OID lease, but that still crosses
# Harn's protected git.push boundary and therefore needs explicit operator
# authority. Keep the grant beside the live launcher so a watcher cannot run
# for hours and discover the missing authority only after hosted proof lands.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_EXT_RELEASE_REPO:-${HOME}/projects/harn}"

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  --approve-risky git.push \
  -- \
  "${repo_root}/watch_harn_release.harn" \
  -- \
  "$@"
