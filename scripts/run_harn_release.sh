#!/usr/bin/env bash
set -euo pipefail

# Canonical release boundary. Read-only, mock, rehearsal, and non-macOS runs
# keep Harn's worktree sandbox. A live macOS prepare/ship cannot certify that
# source correctly: the release audit intentionally exercises nested OS
# sandboxes, and Seatbelt rejects a second sandbox-exec profile under Harn's
# default-deny outer profile. Route that known-impossible shape to the hosted
# Linux owner before spending the local build.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_RELEASE_REPO:-${HOME}/projects/harn}"

mode="audit"
live_release=0
local_only=0
args=("$@")
index=0
while [ "$index" -lt "${#args[@]}" ]; do
  arg="${args[$index]}"
  case "$arg" in
    --mode)
      index=$((index + 1))
      if [ "$index" -lt "${#args[@]}" ]; then
        mode="${args[$index]}"
      fi
      ;;
    --mode=*) mode="${arg#--mode=}" ;;
    --yes-live-release) live_release=1 ;;
    --mock|--rehearsal) local_only=1 ;;
  esac
  index=$((index + 1))
done

if [ "$(uname -s)" = "Darwin" ] \
  && [ "$live_release" -eq 1 ] \
  && [ "$local_only" -eq 0 ] \
  && { [ "$mode" = "prepare" ] || [ "$mode" = "ship-pr" ]; }; then
  canonical_repo="${HOME}/projects/harn"
  if [ "$target_repo" != "$canonical_repo" ]; then
    printf 'error: macOS hosted release handoff cannot represent HARN_RELEASE_REPO=%s; expected canonical checkout %s\n' \
      "$target_repo" "$canonical_repo" >&2
    exit 2
  fi
  exec "${script_dir}/dispatch_hosted_release.sh" "$@"
fi

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  -- \
  "${repo_root}/release_harn.harn" \
  -- \
  "$@"
