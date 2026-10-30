#!/usr/bin/env bash
set -euo pipefail

# Ask the release's two identity questions inside the release's own sandbox.
#
# The grant this proves is `git.push`, and it is deliberately real: the probe
# runs `git push --dry-run`, which completes the full authenticated
# receive-pack handshake and sends no ref update. Nothing is created on the
# remote, and the local probe tag is deleted by the script. Approving the
# boundary here is what makes the probe exercise the same policy path the
# release push takes -- a probe that skipped it would be the unconfined probe
# problem again, one layer down.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_EXT_RELEASE_REPO:-${HOME}/projects/harn}"

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  --approve-risky git.push \
  -- \
  "${repo_root}/preflight_release_identity.harn" \
  -- \
  "$@"
