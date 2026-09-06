#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: restore_candidate_archive_receipt.sh <repo> <hosted-run-id> <archive-run-id> <output>" >&2
  exit 2
fi

repo=$1
hosted_run_id=$2
archive_run_id=$3
output=$4

if [[ ! "$hosted_run_id" =~ ^[1-9][0-9]*$ || ! "$archive_run_id" =~ ^[1-9][0-9]*$ ]]; then
  echo "hosted and archive run IDs must be positive integers" >&2
  exit 2
fi

scratch=$(mktemp -d "${RUNNER_TEMP:-/tmp}/candidate-archive-receipt.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

gh run download "$hosted_run_id" \
  --repo "$repo" \
  --name "release-run-$hosted_run_id" \
  --dir "$scratch"

find "$scratch" -type f -path '*/release-harn/candidate-archive/*.json' -print0 \
  > "$scratch/candidate-paths"
selected_path=""
selected_count=0
while IFS= read -r -d '' path; do
  if jq -e \
    --argjson run_id "$archive_run_id" \
    '.schema_version == "release_harn.candidate_archive.v1" and .run_id == $run_id' \
    "$path" >/dev/null; then
    selected_path=$path
    selected_count=$((selected_count + 1))
  fi
done < "$scratch/candidate-paths"

if [[ $selected_count -ne 1 ]]; then
  echo "expected one candidate archive receipt for run $archive_run_id in hosted run $hosted_run_id; found $selected_count" >&2
  exit 2
fi

mkdir -p "$(dirname "$output")"
cp "$selected_path" "$output"
