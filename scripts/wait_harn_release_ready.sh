#!/usr/bin/env bash
set -euo pipefail

version="${1:-${VERSION:-}}"
if [ -z "${version}" ]; then
  echo "Usage: $0 vX.Y.Z" >&2
  exit 2
fi

if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected Harn tag like v0.8.165, got '${version}'" >&2
  exit 2
fi

version_no_v="${version#v}"
max_attempts="${HARN_RELEASE_READY_MAX_ATTEMPTS:-180}"
poll_seconds="${HARN_RELEASE_READY_POLL_SECONDS:-20}"
repo="${HARN_RELEASE_REPO:-burin-labs/harn}"

required_assets=(
  "harn-aarch64-apple-darwin.tar.gz"
  "harn-aarch64-unknown-linux-gnu.tar.gz"
  "harn-x86_64-apple-darwin.tar.gz"
  "harn-x86_64-pc-windows-msvc.zip"
  "harn-x86_64-unknown-linux-gnu.tar.gz"
  "SHA256SUMS"
  "release-assets.json"
)

asset_list_contains() {
  local needle="$1"
  local asset
  for asset in "${asset_names[@]}"; do
    if [ "${asset}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

join_by_comma() {
  local joined=""
  local item
  for item in "$@"; do
    if [ -n "${joined}" ]; then
      joined="${joined}, ${item}"
    else
      joined="${item}"
    fi
  done
  printf '%s\n' "${joined}"
}

write_output() {
  local key="$1"
  local value="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "${key}" "${value}" >> "${GITHUB_OUTPUT}"
  fi
}

for ((attempt = 1; attempt <= max_attempts; attempt += 1)); do
  crate_ready=0
  if curl -fsSL \
    -A "burin-labs/harn-bump-fleet release-readiness" \
    -H "Accept: application/json" \
    "https://crates.io/api/v1/crates/harn-cli/${version_no_v}" >/dev/null; then
    crate_ready=1
  fi

  asset_names=()
  while IFS= read -r asset_name; do
    if [ -n "${asset_name}" ]; then
      asset_names+=("${asset_name}")
    fi
  done < <(
    gh release view "${version}" --repo "${repo}" --json assets --jq '.assets[].name' 2>/dev/null \
      | sort -u || true
  )

  missing_assets=()
  for asset in "${required_assets[@]}"; do
    if ! asset_list_contains "${asset}"; then
      missing_assets+=("${asset}")
    fi
  done

  if [ "${crate_ready}" -eq 1 ] && [ "${#missing_assets[@]}" -eq 0 ]; then
    write_output "ready" "true"
    echo "harn-cli ${version_no_v} is published and required release assets are present."
    exit 0
  fi

  if [ "${crate_ready}" -eq 1 ]; then
    crate_detail="harn-cli ${version_no_v} published"
  else
    crate_detail="harn-cli ${version_no_v} not visible on crates.io"
  fi
  if [ "${#missing_assets[@]}" -eq 0 ]; then
    asset_detail="required release assets present"
  else
    asset_detail="missing release assets: $(join_by_comma "${missing_assets[@]}")"
  fi
  echo "attempt ${attempt}/${max_attempts}: ${crate_detail}; ${asset_detail}"

  if [ "${attempt}" -lt "${max_attempts}" ]; then
    sleep "${poll_seconds}"
  fi
done

write_output "ready" "false"
echo "Skipping bump: ${version} is not fully published yet."
