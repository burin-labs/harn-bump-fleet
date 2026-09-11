#!/usr/bin/env bash
# Keep each hosted release watcher process shorter than one GitHub App token.
#
# The Harn GitHub connector resolves its gh-auth fallback when the process
# starts. Rewriting gh's credential store cannot replace that in-process
# bearer. The release receipt is durable, so a pending watcher can exit with
# status 3 and a fresh process can resume the same exact PR/tag handoff.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
refresh_script="${HARN_EXT_HOSTED_RELEASE_REFRESH_SCRIPT:-${script_dir}/refresh_hosted_release_credentials.sh}"
watch_script="${HARN_EXT_HOSTED_RELEASE_WATCH_SCRIPT:-${script_dir}/watch_harn_release.sh}"
segment_polls="${HARN_EXT_HOSTED_RELEASE_SEGMENT_POLLS:-60}"
interval_seconds="${HARN_EXT_HOSTED_RELEASE_INTERVAL_SECONDS:-30}"
max_segment_seconds=2700

# Keep the refreshed gh login under the runner's secret scratch root. The
# confined release boundary already grants that root because it contains the
# signing key and git credential store. Using gh's default ~/.config path here
# made an otherwise valid token unreadable once the watcher installed process
# confinement, so artifact recovery failed before it could read its receipt.
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  export GH_CONFIG_DIR="${GH_CONFIG_DIR:-${RUNNER_TEMP}/gh-config}"
  mkdir -p "$GH_CONFIG_DIR"
  chmod 700 "$GH_CONFIG_DIR"
fi

if [[ ! "$segment_polls" =~ ^[1-9][0-9]*$ ]]; then
  echo "HARN_EXT_HOSTED_RELEASE_SEGMENT_POLLS must be a positive integer" >&2
  exit 2
fi
if [[ ! "$interval_seconds" =~ ^[0-9]+$ ]]; then
  echo "HARN_EXT_HOSTED_RELEASE_INTERVAL_SECONDS must be a non-negative integer" >&2
  exit 2
fi
if (( segment_polls * interval_seconds > max_segment_seconds )); then
  echo "hosted release watch segment must stay within ${max_segment_seconds}s" >&2
  exit 2
fi

for arg in "$@"; do
  if [[ "$arg" == "--max-polls" || "$arg" == "--interval-seconds" ]]; then
    echo "hosted release watcher owns --max-polls and --interval-seconds" >&2
    exit 2
  fi
done

segment=0
while true; do
  segment=$((segment + 1))
  "$refresh_script"
  echo "starting hosted release watch segment ${segment} (${segment_polls} polls at ${interval_seconds}s)"

  set +e
  "$watch_script" "$@" \
    --max-polls "$segment_polls" \
    --interval-seconds "$interval_seconds"
  status=$?
  set -e

  case "$status" in
    0)
      exit 0
      ;;
    3)
      echo "hosted release remains pending; resuming from its durable receipt with a fresh credential"
      ;;
    *)
      exit "$status"
      ;;
  esac
done
