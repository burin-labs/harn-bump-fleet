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
DEFAULT_SCCACHE_CACHE_SIZE="30G"
export SCCACHE_CACHE_SIZE="${SCCACHE_CACHE_SIZE:-$DEFAULT_SCCACHE_CACHE_SIZE}"
SCCACHE_COMPILE_PROBE_TIMEOUT_SECONDS="${SCCACHE_COMPILE_PROBE_TIMEOUT_SECONDS:-15}"

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

compilers_active() {
  pgrep -x rustc >/dev/null 2>&1 \
    || pgrep -x cargo >/dev/null 2>&1 \
    || pgrep -x rustdoc >/dev/null 2>&1 \
    || pgrep -x clang >/dev/null 2>&1 \
    || pgrep -x cc >/dev/null 2>&1 \
    || pgrep -x c++ >/dev/null 2>&1 \
    || pgrep -x swiftc >/dev/null 2>&1
}

compile_path_healthy() {
  local rustc_bin probe_root source_path output_dir output_path probe_status
  rustc_bin="${RUSTC_BIN:-$(command -v rustc 2>/dev/null || true)}"
  if [ -z "$rustc_bin" ] || [ ! -x "$rustc_bin" ]; then
    echo "sccache compile probe cannot find rustc" >&2
    return 1
  fi

  probe_root="${TMPDIR:-/tmp}/harn-bump-fleet-sccache-health-${UID}"
  source_path="$probe_root/probe.rs"
  output_dir="$probe_root/out"
  output_path="$output_dir/libharn_bump_fleet_sccache_health.rmeta"
  mkdir -p "$output_dir"
  printf 'pub fn sccache_compile_path_health() -> u8 { 1 }\n' > "$source_path"
  rm -f "$output_path"

  set +e
  /usr/bin/perl -e 'alarm shift @ARGV; exec @ARGV or exit 127' \
    "$SCCACHE_COMPILE_PROBE_TIMEOUT_SECONDS" \
    "$SCCACHE_BIN" "$rustc_bin" \
      --crate-name harn_bump_fleet_sccache_health \
      --crate-type lib \
      --emit=metadata \
      --out-dir "$output_dir" \
      "$source_path" \
      >/dev/null 2>&1
  probe_status=$?
  set -e

  if [ "$probe_status" -eq 142 ]; then
    echo "sccache compile probe timed out after ${SCCACHE_COMPILE_PROBE_TIMEOUT_SECONDS}s" >&2
    return 1
  fi
  if [ "$probe_status" -ne 0 ] || [ ! -s "$output_path" ]; then
    echo "sccache compile probe failed" >&2
    return 1
  fi
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

restart_reason=""
if [ "${errors:-0}" -gt 0 ]; then
  restart_reason="cache_errors=${errors:-0}"
elif [ "$observed_cache_bytes" != "$desired_cache_bytes" ]; then
  restart_reason="cap=${observed_cache_size:-unknown}"
elif ! compile_path_healthy; then
  restart_reason="compile_path_unhealthy"
fi

if [ -n "$restart_reason" ]; then
  # Never interrupt a live compiler. A later LaunchAgent tick will converge the
  # daemon once the machine is quiescent.
  if compilers_active; then
    echo "$(date '+%Y-%m-%dT%H:%M:%S') sccache restart deferred while compilers are active"
    exit 0
  fi

  echo "$(date '+%Y-%m-%dT%H:%M:%S') restarting sccache (reason=$restart_reason, wanted=$SCCACHE_CACHE_SIZE)"
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

if [ -n "$restart_reason" ] && ! compile_path_healthy; then
  echo "sccache compile-path verification failed after restart" >&2
  exit 1
fi
