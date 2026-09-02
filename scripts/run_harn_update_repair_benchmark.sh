#!/usr/bin/env bash
set -euo pipefail

route=${1:-value}
case "$route" in
  auto|value|strong) ;;
  *)
    echo "usage: $0 [auto|value|strong]" >&2
    exit 2
    ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
toolchain_version=$(rustup run 1.95.0 rustc --version)
case "$toolchain_version" in
  "rustc 1.95.0 "*) ;;
  *)
    echo "benchmark requires Rust 1.95.0; observed: $toolchain_version" >&2
    exit 1
    ;;
esac
clippy_version=$(rustup run 1.95.0 cargo-clippy -V)
case "$clippy_version" in
  "clippy 0.1.95 "*) ;;
  *)
    echo "benchmark requires Clippy 0.1.95; observed: $clippy_version" >&2
    exit 1
    ;;
esac

benchmark_parent=${TMPDIR:-/tmp}
if [[ ! -d "$benchmark_parent" ]]; then
  echo "benchmark temporary directory does not exist: $benchmark_parent" >&2
  exit 1
fi
benchmark_dir=$(mktemp -d "${benchmark_parent%/}/harn-update-repair-benchmark.XXXXXX")
cleanup() {
  rm -rf -- "$benchmark_dir"
}
trap cleanup EXIT

cp -R "$repo_root/testdata/harn_update_repair/." "$benchmark_dir"
git -C "$benchmark_dir" init -q
git -C "$benchmark_dir" add .
git -C "$benchmark_dir" \
  -c user.name="Harn Repair Benchmark" \
  -c user.email="harn-repair-benchmark@invalid.example" \
  commit -q -m fixture
benchmark_head=$(git -C "$benchmark_dir" rev-parse HEAD)

if rustup run 1.95.0 cargo-clippy \
  --manifest-path "$benchmark_dir/Cargo.toml" \
  --locked --all-targets -- -D warnings >/dev/null 2>&1; then
  echo "fixture unexpectedly passes before repair" >&2
  exit 1
fi

cd "$repo_root"
"$repo_root/scripts/with_env.sh" "$repo_root/.harn/bin/harn" run \
  --write-root "$benchmark_dir" \
  benchmark_harn_update_repair.harn -- \
  --repository-dir "$benchmark_dir" \
  --head-sha "$benchmark_head" \
  --route "$route"
