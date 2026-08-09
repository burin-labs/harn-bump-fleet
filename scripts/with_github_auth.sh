#!/usr/bin/env bash
set -euo pipefail

# Resolve the existing gh login once, before Harn installs recursive process
# confinement. The token is exported only to the child process and never
# printed or placed on a command line.

if [ -z "${GH_TOKEN:-}" ] && [ -z "${GITHUB_TOKEN:-}" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "with_github_auth: GH_TOKEN is unset and gh is unavailable" >&2
    exit 2
  fi
  github_token="$(gh auth token 2>/dev/null)"
  if [ -z "$github_token" ]; then
    echo "with_github_auth: the active gh login returned no token" >&2
    exit 2
  fi
  export GH_TOKEN="$github_token"
  unset github_token
fi

if [ "$#" -eq 0 ]; then
  echo "with_github_auth: nothing to exec" >&2
  exit 2
fi
exec "$@"
