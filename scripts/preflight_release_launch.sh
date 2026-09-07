#!/usr/bin/env bash
set -euo pipefail

# Ask every release precondition, before the release leases anything.
#
# Five hosted release attempts were lost in one day, each at a gate first
# exercised between thirty seconds and sixty-five minutes into an attempt that
# could not be taken back. The gates were fine; the moment they were asked was
# not. This is those questions, asked first.
#
# It runs unsandboxed on purpose. Two of the preconditions are network reads --
# the installation mint and the live consumer contracts -- and a preflight that
# asked them through a different boundary than the release would be answering a
# different question. Nothing here writes a ref, opens a pull request, or takes
# a lease.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

exec "${script_dir}/with_env.sh" harn run --no-sandbox \
  "${repo_root}/preflight_release_launch.harn" -- "$@"
