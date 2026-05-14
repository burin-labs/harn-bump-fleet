#!/usr/bin/env bash
set -euo pipefail

# harn_shielded.sh — launch `harn` via a stable scratch copy of the binary so
# macOS AMFI can't kill the process mid-flight when another build replaces
# the source binary on PATH. Replicates the manual
# `cp ~/.cargo/bin/harn ~/.cargo/bin/harn2 && harn2 ...` trick automatically.
#
# Behavior:
#   1. Resolve the "source" harn binary: first $HARN_BIN, else the first `harn`
#      on PATH that is NOT this launcher.
#   2. Stage a copy at $XDG_CACHE_HOME/harn-shielded/harn (default
#      ~/Library/Caches/harn-shielded/harn on macOS, ~/.cache/harn-shielded/harn
#      elsewhere). The launcher only re-stages when the source binary's
#      mtime+size differs from the staged copy, so warm runs cost an
#      `stat` and an `exec`.
#   3. exec the staged copy with the original argv. Process image is detached
#      from the source path, so rebuilds / `cargo install` overwriting the
#      original cannot AMFI-kill an in-flight run.
#
# Usage:
#   scripts/harn_shielded.sh run bump_fleet.harn -- --dry-run
#   scripts/harn_shielded.sh run release_harn.harn -- --mode ship-pr
#   scripts/harn_shielded.sh --version

self="$(/usr/bin/env -i PATH=/usr/bin:/bin readlink -f "$0" 2>/dev/null || python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$0")"

find_source_harn() {
  if [ -n "${HARN_BIN:-}" ]; then
    if [ -x "${HARN_BIN}" ]; then
      printf '%s\n' "${HARN_BIN}"
      return 0
    fi
    echo "harn_shielded: HARN_BIN=${HARN_BIN} is not executable" >&2
    return 1
  fi
  local IFS=:
  for dir in $PATH; do
    [ -n "$dir" ] || continue
    local candidate="${dir}/harn"
    [ -x "$candidate" ] || continue
    local resolved
    resolved="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$candidate")"
    if [ "$resolved" = "$self" ]; then
      continue
    fi
    printf '%s\n' "$candidate"
    return 0
  done
  echo "harn_shielded: no \`harn\` on PATH (and \$HARN_BIN unset)" >&2
  return 1
}

source_bin="$(find_source_harn)"

cache_root="${HARN_SHIELDED_DIR:-${XDG_CACHE_HOME:-${HOME}/Library/Caches}/harn-shielded}"
mkdir -p "$cache_root"
staged="$cache_root/harn"
fingerprint_file="$cache_root/harn.fingerprint"

# Fingerprint = size:mtime of the source binary. Cheaper than hashing and
# detects every rebuild because `cargo install` rewrites the file.
size_mtime() {
  python3 - "$1" <<'PY'
import os, sys
try:
    st = os.stat(sys.argv[1])
    print(f"{st.st_size}:{int(st.st_mtime)}")
except OSError as exc:
    sys.stderr.write(f"stat failed: {exc}\n")
    sys.exit(1)
PY
}

src_fp="$(size_mtime "$source_bin")"
need_restage=1
if [ -x "$staged" ] && [ -f "$fingerprint_file" ]; then
  if [ "$(cat "$fingerprint_file")" = "$src_fp" ]; then
    need_restage=0
  fi
fi

if [ "$need_restage" -eq 1 ]; then
  tmp="$(mktemp "${staged}.XXXXXX")"
  cp "$source_bin" "$tmp"
  chmod 755 "$tmp"
  mv -f "$tmp" "$staged"
  printf '%s' "$src_fp" > "$fingerprint_file"
fi

exec "$staged" "$@"
