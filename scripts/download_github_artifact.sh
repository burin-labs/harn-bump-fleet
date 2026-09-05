#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: download_github_artifact.sh RUN_ID ARTIFACT DESTINATION" >&2
  exit 2
fi

run_id="$1"
artifact="$2"
destination="$3"
case "$run_id" in
  ''|*[!0-9]*) echo "download_github_artifact: run ID must be numeric" >&2; exit 2 ;;
esac
if [ ! -d "$destination" ] || [ -L "$destination" ]; then
  echo "download_github_artifact: destination must be an existing directory" >&2
  exit 2
fi
destination="$(cd -- "$destination" && pwd -P)"
stdout_file="$(mktemp "${destination}/.gh-download-stdout.XXXXXX")"
stderr_file="$(mktemp "${destination}/.gh-download-stderr.XXXXXX")"
# shellcheck disable=SC2329  # invoked by the EXIT trap
cleanup() {
  rm -f -- "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

if gh run download "$run_id" --name "$artifact" --dir "$destination" \
  >"$stdout_file" 2>"$stderr_file"; then
  exit 0
else
  download_status=$?
fi

# `gh` may include its signed Azure redirect in a failure. Sanitize before the
# text crosses the Harn subprocess boundary and enters an execution receipt.
sed -E 's#(https://[^ ?]+)\?[^[:space:]]+#\1?[redacted-query]#g' "$stderr_file" >&2
sed -E 's#(https://[^ ?]+)\?[^[:space:]]+#\1?[redacted-query]#g' "$stdout_file" >&2
exit "$download_status"
