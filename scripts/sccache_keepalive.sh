#!/usr/bin/env bash
set -euo pipefail

# sccache_keepalive.sh — keep a healthy, UNCONFINED sccache server running.
#
# sccache is a single machine-wide server daemon (per user, fixed port). Every
# cargo build on the machine talks to that one daemon. Whoever triggers the
# first sccache call spawns it — and if that first caller runs inside a sandbox
# (harn's `sandbox-exec`, a sandboxed agent shell), the daemon inherits the
# seatbelt confinement *permanently*, even after it reparents to launchd. A
# confined daemon then fails every cargo build machine-wide with
# `Operation not permitted` (can't write its cache dir under ~/Library/Caches,
# can't read build inputs outside the sandbox root).
#
# This script, run by a LaunchAgent in the unconfined login context (RunAtLoad
# + StartInterval), keeps the daemon owned by an unconfined process so neither
# harn nor a sandboxed shell is ever the one to spawn (and confine) it:
#   1. If the running daemon is poisoned (non-zero cache I/O error counters),
#      stop it so we respawn clean.
#   2. Ensure a server is running (no-op when one is already up and healthy),
#      with idle-timeout disabled so it never expires and gets re-spawned by a
#      random build.
# Idempotent and side-effect-light: safe to run on a tight interval.

SCCACHE_BIN="$(command -v sccache 2>/dev/null || echo /opt/homebrew/bin/sccache)"
[ -x "$SCCACHE_BIN" ] || exit 0

# A server we start should never idle out — staying alive means a sandboxed
# build never has to spawn (and confine) a replacement.
export SCCACHE_IDLE_TIMEOUT=0

# Sum every "Cache … errors" counter. A healthy daemon reports 0; a confined
# one drives writes/reads into the hundreds. Any positive sum => poisoned.
errors="$("$SCCACHE_BIN" --show-stats 2>/dev/null \
  | awk '/Cache (write |read )?errors|Cache errors/ { s += $NF } END { print s + 0 }')"
if [ "${errors:-0}" -gt 0 ]; then
  echo "$(date '+%Y-%m-%dT%H:%M:%S') poisoned sccache daemon ($errors cache I/O errors) — restarting"
  "$SCCACHE_BIN" --stop-server >/dev/null 2>&1 || true
fi

# Ensure a healthy server is up. No-op if one is already running.
"$SCCACHE_BIN" --start-server >/dev/null 2>&1 || true
