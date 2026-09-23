#!/usr/bin/env bash
set -euo pipefail

# One deterministic destination policy for native network reads made by the
# release harness. This wrapper runs after with_env.sh so ambient or local .env
# HARN_EGRESS_* values cannot widen, deny, or otherwise replace the policy.
unset HARN_EGRESS_ALLOW
unset HARN_EGRESS_DENY
unset HARN_EGRESS_DEFAULT
unset HARN_EGRESS_BLOCK_PRIVATE
unset HARN_EGRESS_ALLOW_LOOPBACK

# Artifact downloads are a short-lived phase selected explicitly by the
# canonical watcher launcher. GitHub authorizes the archive through its API,
# then redirects to a signed Azure Blob URL. Keep that wider suffix out of the
# long-lived release process, which carries signing and provider credentials.
profile="release"
if [ "${1:-}" = "--github-artifact-import" ]; then
  profile="github-artifact-import"
  shift
fi

if [ "$profile" = "github-artifact-import" ]; then
  export HARN_EGRESS_ALLOW="api.github.com:443,*.blob.core.windows.net:443"
else
  # GitHub's API owns workflow/release state, while its Git transport owns the
  # immutable refs the watcher verifies and cleans up. crates.io owns publication
  # visibility and static.crates.io owns registry identity archives.
  export HARN_EGRESS_ALLOW="api.github.com:443,github.com:443,crates.io:443,static.crates.io:443"
fi
export HARN_EGRESS_DEFAULT="deny"
export HARN_EGRESS_BLOCK_PRIVATE="private"
export HARN_EGRESS_ALLOW_LOOPBACK="0"

if [ "$#" -eq 0 ]; then
  echo "with_release_egress: nothing to exec" >&2
  exit 2
fi
exec "$@"
