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

# Keep the machine-wide compilation cache bounded so it cannot crowd out active
# release targets and worktrees. This LaunchAgent is the owner of the server's
# startup configuration; operators may raise or lower the cap per host.
DEFAULT_SCCACHE_CACHE_SIZE="24G"
export SCCACHE_CACHE_SIZE="${SCCACHE_CACHE_SIZE:-$DEFAULT_SCCACHE_CACHE_SIZE}"

# A server we start should never idle out — staying alive means a sandboxed
# build never has to spawn (and confine) a replacement.
export SCCACHE_IDLE_TIMEOUT=0

size_to_bytes() {
  printf '%s\n' "$1" | awk '
    {
      value = toupper($0)
      gsub(/[[:space:]]/, "", value)
      sub(/IB$/, "", value)
      sub(/B$/, "", value)
      unit = substr(value, length(value), 1)
      multiplier = 1
      if (unit == "K") multiplier = 1024
      else if (unit == "M") multiplier = 1024 * 1024
      else if (unit == "G") multiplier = 1024 * 1024 * 1024
      else if (unit == "T") multiplier = 1024 * 1024 * 1024 * 1024
      if (unit ~ /^[KMGT]$/) value = substr(value, 1, length(value) - 1)
      if (value !~ /^[0-9]+$/) exit 2
      printf "%.0f\n", value * multiplier
    }
  '
}

desired_cache_bytes="$(size_to_bytes "$SCCACHE_CACHE_SIZE")" || {
  echo "invalid SCCACHE_CACHE_SIZE: $SCCACHE_CACHE_SIZE" >&2
  exit 2
}

# Sum every "Cache … errors" counter. A healthy daemon reports 0; a confined
# one drives writes/reads into the hundreds. Any positive sum => poisoned.
stats="$("$SCCACHE_BIN" --show-stats 2>/dev/null || true)"
errors="$(printf '%s\n' "$stats" \
  | awk '/Cache (write |read )?errors|Cache errors/ { s += $NF } END { print s + 0 }')"
observed_cache_size="$(printf '%s\n' "$stats" | awk '/^Max cache size/ { print $4, $5; exit }')"
observed_cache_bytes=""
if [ -n "$observed_cache_size" ]; then
  observed_cache_bytes="$(size_to_bytes "$observed_cache_size" || true)"
fi

if [ "${errors:-0}" -gt 0 ] || [ "$observed_cache_bytes" != "$desired_cache_bytes" ]; then
  # Never interrupt a live compiler. A later LaunchAgent tick will converge the
  # daemon once the machine is quiescent.
  if pgrep -x 'cargo|rustc|rustdoc|clang|clang\+\+|cc|c\+\+|swiftc' >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%dT%H:%M:%S') sccache restart deferred while compilers are active"
    exit 0
  fi

  echo "$(date '+%Y-%m-%dT%H:%M:%S') restarting sccache (errors=${errors:-0}, cap=${observed_cache_size:-unknown}, wanted=$SCCACHE_CACHE_SIZE)"
  "$SCCACHE_BIN" --stop-server >/dev/null 2>&1 || true
fi

"$SCCACHE_BIN" --start-server >/dev/null

# Do not report success until the persistent daemon proves it accepted the cap.
verified_stats="$("$SCCACHE_BIN" --show-stats 2>/dev/null)"
verified_cache_size="$(printf '%s\n' "$verified_stats" | awk '/^Max cache size/ { print $4, $5; exit }')"
verified_cache_bytes="$(size_to_bytes "$verified_cache_size" || true)"
if [ "$verified_cache_bytes" != "$desired_cache_bytes" ]; then
  echo "sccache cache cap verification failed: got ${verified_cache_size:-unknown}, wanted $SCCACHE_CACHE_SIZE" >&2
  exit 1
fi
