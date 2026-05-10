#!/usr/bin/env bash
set -euo pipefail

# Install a pinned harn-cli release. Prefers the prebuilt binary tarball
# from `gh release download` (~seconds) and falls back to
# `cargo install --locked` (~5-10 min on a cold runner) only when the
# asset doesn't exist for this OS/arch — alpha builds, brand-new
# targets, or a release whose `build-release-binaries.yml` cascade is
# still in flight. Set HARN_INSTALL_FROM_SOURCE=1 to skip the prebuilt
# path entirely (debugging / reproducing source builds).

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
tag="v${version_no_v}"
install_root="${HARN_INSTALL_ROOT:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/harn-${version_no_v}}"
bin_dir="${install_root}/bin"
mkdir -p "${bin_dir}"

# Detect the rust target triple matching `harn-<target>.tar.gz` assets
# that build-release-binaries.yml uploads to each GitHub release.
target=""
case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
  darwin)
    case "$(uname -m)" in
      arm64|aarch64) target="aarch64-apple-darwin" ;;
      x86_64) target="x86_64-apple-darwin" ;;
    esac
    ;;
  linux)
    case "$(uname -m)" in
      x86_64) target="x86_64-unknown-linux-gnu" ;;
      aarch64) target="aarch64-unknown-linux-gnu" ;;
    esac
    ;;
esac

installed_from_asset=0
if [ -n "${target}" ] && [ "${HARN_INSTALL_FROM_SOURCE:-0}" != "1" ]; then
  asset_url="https://github.com/burin-labs/harn/releases/download/${tag}/harn-${target}.tar.gz"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  echo "Fetching prebuilt binary: ${asset_url}"
  if curl -fsSL "${asset_url}" -o "${tmpdir}/harn.tar.gz"; then
    tar -xzf "${tmpdir}/harn.tar.gz" -C "${tmpdir}"
    install -m 755 "${tmpdir}/harn" "${bin_dir}/harn"
    if [ -f "${tmpdir}/harn-dap" ]; then
      install -m 755 "${tmpdir}/harn-dap" "${bin_dir}/harn-dap"
    fi
    installed_from_asset=1
    echo "Installed harn ${tag} from prebuilt ${target} tarball."
  else
    echo "Prebuilt binary unavailable for ${target} at ${tag}; falling back to cargo install."
  fi
fi

if [ "${installed_from_asset}" -eq 0 ]; then
  target_dir="${CARGO_TARGET_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/harn-install-target-${version_no_v}}"
  mkdir -p "${target_dir}"
  export CARGO_TARGET_DIR="${target_dir}"
  cargo install harn-cli --version "${version_no_v}" --locked --root "${install_root}"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${bin_dir}" >> "${GITHUB_PATH}"
fi

"${bin_dir}/harn" --version
