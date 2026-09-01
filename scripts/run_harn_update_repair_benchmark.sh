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
benchmark_dir=$(mktemp -d /private/tmp/harn-update-repair-benchmark.XXXXXX)
cleanup() {
  rm -rf -- "$benchmark_dir"
}
trap cleanup EXIT

cp -R "$repo_root/testdata/harn_update_repair/." "$benchmark_dir"
git -C "$benchmark_dir" init -q
git -C "$benchmark_dir" add .
git -C "$benchmark_dir" commit -q -m fixture
benchmark_head=$(git -C "$benchmark_dir" rev-parse HEAD)

cd "$repo_root"
"$repo_root/scripts/with_env.sh" "$repo_root/.harn/bin/harn" run \
  --write-root "$benchmark_dir" \
  benchmark_harn_update_repair.harn -- \
  --repository-dir "$benchmark_dir" \
  --head-sha "$benchmark_head" \
  --route "$route"
