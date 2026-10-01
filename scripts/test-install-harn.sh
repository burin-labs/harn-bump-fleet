#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "${test_root}"' EXIT

fake_bin="${test_root}/fake-bin"
install_root="${test_root}/custom-install-root"
mkdir -p "${fake_bin}"

cat > "${fake_bin}/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail

root=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--root" ]; then
    root="${2:-}"
    shift 2
  else
    shift
  fi
done

if [ -z "${root}" ]; then
  echo "fake cargo: missing --root" >&2
  exit 2
fi

mkdir -p "${root}/bin"
cat > "${root}/bin/harn" <<'HARN'
#!/usr/bin/env bash
set -euo pipefail

leaked="$({
  env | grep -E '^HARN_(INSTALL_ROOT|INSTALL_FROM_SOURCE|NO_VERIFY)=' || true
})"
if [ -n "${leaked}" ]; then
  echo "installer controls leaked into Harn:" >&2
  echo "${leaked}" >&2
  exit 97
fi
if [ "${1:-}" != "--version" ]; then
  echo "fake harn: expected --version" >&2
  exit 2
fi
echo "harn 0.10.49"
HARN
chmod 755 "${root}/bin/harn"
CARGO
chmod 755 "${fake_bin}/cargo"

output="$({
  PATH="${fake_bin}:/usr/bin:/bin" \
    HARN_INSTALL_ROOT="${install_root}" \
    HARN_INSTALL_FROM_SOURCE=1 \
    HARN_NO_VERIFY=1 \
    "${script_dir}/install_harn.sh" v0.10.49
})"

if [ ! -x "${install_root}/bin/harn" ]; then
  echo "installer did not create the executable in the custom root" >&2
  exit 1
fi

last_line="${output##*$'\n'}"
if [ "${last_line}" != "harn 0.10.49" ]; then
  echo "installed binary did not return the exact expected version" >&2
  echo "output: ${output}" >&2
  exit 1
fi

echo "install-harn control environment: ok"
