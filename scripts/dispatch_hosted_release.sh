#!/usr/bin/env bash
set -euo pipefail

# The Harn entrypoint owns validation, the typed GitHub connector mutation,
# exact run identity, durable receipts, and receipt-bound replacement. Keep the
# shell surface as a process/environment adapter only.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

exec "${script_dir}/with_env.sh" \
  harn run --no-sandbox "${repo_root}/dispatch_hosted_release.harn" -- "$@"
