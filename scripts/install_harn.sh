#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
if [ -z "${version}" ]; then
  if [ ! -f .harn-version ]; then
    echo "Usage: $0 vX.Y.Z" >&2
    echo "or run from a repo with .harn-version" >&2
    exit 2
  fi
  version="$(tr -d '[:space:]' < .harn-version)"
fi

if [[ ! "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected Harn version like v0.8.0 or 0.8.0, got '${version}'" >&2
  exit 2
fi

version_no_v="${version#v}"
install_root="${HARN_INSTALL_ROOT:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/harn-${version_no_v}}"
target_dir="${CARGO_TARGET_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/harn-install-target-${version_no_v}}"

mkdir -p "${install_root}" "${target_dir}"

export CARGO_TARGET_DIR="${target_dir}"
cargo install harn-cli --version "${version_no_v}" --locked --root "${install_root}"

bin_dir="${install_root}/bin"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${bin_dir}" >> "${GITHUB_PATH}"
fi

"${bin_dir}/harn" --version
