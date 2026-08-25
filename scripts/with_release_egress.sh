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

# GitHub's API owns workflow/release state, while its Git transport owns the
# immutable refs the watcher verifies and cleans up. crates.io owns publication
# visibility and static.crates.io owns registry identity archives.
export HARN_EGRESS_ALLOW="api.github.com:443,github.com:443,crates.io:443,static.crates.io:443"
export HARN_EGRESS_DEFAULT="deny"
export HARN_EGRESS_BLOCK_PRIVATE="private"
export HARN_EGRESS_ALLOW_LOOPBACK="0"

exec "$@"
