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

hosted_run=0
import_args=()
skip_import_value=0
for arg in "$@"; do
  if [ "$skip_import_value" -eq 1 ]; then
    skip_import_value=0
    continue
  fi
  case "$arg" in
    --hosted-run|--hosted-run=*) hosted_run=1 ;;
    # The import process can only read and persist one hosted receipt. Do not
    # give it recovery modes or acknowledgements used by the later mutation
    # process. A separate-value recovery option owns its following commit.
    --tag-stranded-main|--unfold-merged-bump)
      skip_import_value=1
      continue
      ;;
    --tag-stranded-main=*|--unfold-merged-bump=*|--yes-live-release|--github-app-signer|--json)
      continue
      ;;
  esac
  import_args+=("$arg")
done

# Import the exact hosted artifact in a short-lived process. Its temporary
# Azure redirect authority must not survive into the long-running watcher.
if [ "$hosted_run" -eq 1 ]; then
  "${script_dir}/harn_confined.sh" \
    "$target_repo" \
    --github-artifact-import-egress \
    -- \
    "${repo_root}/watch_harn_release.harn" \
    -- \
    --import-hosted-receipt-only \
    "${import_args[@]}"
fi

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  --approve-risky git.push \
  -- \
  "${repo_root}/watch_harn_release.harn" \
  -- \
  "$@"
