#!/usr/bin/env bash
set -euo pipefail

# Install the repository-owned sccache compiler boundary and point Cargo's
# user-level configuration at the stable installed projection. The config edit
# is deliberately narrow: a non-sccache custom rustc wrapper is left untouched
# and reported instead of being silently replaced.

self_dir="$(cd "$(dirname "$0")" && pwd)"
source_wrapper="$self_dir/sccache-rustc-wrapper.sh"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
installed_wrapper="$cargo_home/bin/sccache-rustc-wrapper.sh"
config_path="$cargo_home/config.toml"

configure_cargo() {
  local escaped_wrapper tmp
  escaped_wrapper="${installed_wrapper//\\/\\\\}"
  escaped_wrapper="${escaped_wrapper//\"/\\\"}"
  mkdir -p "$cargo_home"
  tmp="$(mktemp "$cargo_home/config.toml.tmp.XXXXXX")"

  if [ ! -f "$config_path" ]; then
    printf '[build]\nrustc-wrapper = "%s"\n' "$escaped_wrapper" > "$tmp"
  elif ! awk -v replacement="rustc-wrapper = \"$escaped_wrapper\"" '
    BEGIN {
      in_build = 0
      saw_build = 0
      saw_wrapper = 0
      rejected = 0
    }
    function emit_wrapper() {
      if (!saw_wrapper) {
        print replacement
        saw_wrapper = 1
      }
    }
    /^[[:space:]]*\[[^]]+\][[:space:]]*(#.*)?$/ {
      if (in_build) emit_wrapper()
      in_build = ($0 ~ /^[[:space:]]*\[build\][[:space:]]*(#.*)?$/)
      if (in_build) saw_build = 1
      print
      next
    }
    in_build && /^[[:space:]]*rustc-wrapper[[:space:]]*=/ {
      if ($0 !~ /sccache/) {
        print "refusing to replace non-sccache build.rustc-wrapper: " $0 > "/dev/stderr"
        rejected = 1
        exit 3
      }
      print replacement
      saw_wrapper = 1
      next
    }
    { print }
    END {
      if (rejected) exit 3
      if (in_build) emit_wrapper()
      if (!saw_build) {
        if (NR > 0) print ""
        print "[build]"
        print replacement
      }
    }
  ' "$config_path" > "$tmp"; then
    rm -f "$tmp"
    exit 3
  fi

  chmod 0600 "$tmp"
  mv "$tmp" "$config_path"
}

[ -f "$source_wrapper" ] || { echo "missing wrapper: $source_wrapper" >&2; exit 1; }
mkdir -p "$(dirname "$installed_wrapper")"
install -m 0755 "$source_wrapper" "$installed_wrapper"
configure_cargo

echo "Configured Cargo rustc wrapper: $installed_wrapper"
