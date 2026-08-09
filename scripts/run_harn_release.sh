#!/usr/bin/env bash
set -euo pipefail

# Canonical live-release boundary. Harn keeps its worktree sandbox, while this
# launcher grants only the Harn checkout and toolchain state needed by release
# commands. Pass release_harn.harn arguments directly.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_RELEASE_REPO:-${HOME}/projects/harn}"

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  -- \
  "${repo_root}/release_harn.harn" \
  -- \
  "$@"
