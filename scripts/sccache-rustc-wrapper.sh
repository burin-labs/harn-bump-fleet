#!/usr/bin/env bash
set -euo pipefail

# sccache includes Cargo's environment in Rust cache keys. CARGO_TARGET_DIR is
# an absolute, checkout-specific output path, but rustc does not consume it.
# Remove that one Cargo-only path at the compiler boundary so identical
# dependency compilations can hit across isolated worktrees while Cargo keeps
# writing each build into its own target directory.
sccache_bin="${SCCACHE_BIN:-$(command -v sccache 2>/dev/null || true)}"
if [ -z "$sccache_bin" ] || [ ! -x "$sccache_bin" ]; then
  echo "sccache executable not found" >&2
  exit 127
fi

unset CARGO_TARGET_DIR SCCACHE_BIN
exec "$sccache_bin" "$@"
