#!/usr/bin/env bash
# Remint the GitHub App installation token and rewrite every push/API path.
#
# App installation tokens expire after one hour. Hosted ship-pr regularly runs
# longer (candidate certification alone is ~40m), so a token minted at job
# start is dead by the tag push. This script refreshes:
#   1. $RUNNER_TEMP/git-credentials — credential.helper store used by git push
#   2. `gh auth` login — what the github connector reads when GH_TOKEN is unset
#      (allow_gh_auth_fallback -> `gh auth token`)
set -euo pipefail

if [[ -z "${RUNNER_TEMP:-}" ]]; then
  echo "RUNNER_TEMP is required" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
token="$(
  node "${script_dir}/mint_github_app_installation_token.mjs"
)"

if [[ -z "$token" ]]; then
  echo "minted installation token was empty" >&2
  exit 1
fi

host="${GIT_CREDENTIAL_HOST:-github.com}"
username="${GIT_CREDENTIAL_USERNAME:-x-access-token}"
store_path="${GIT_CREDENTIAL_STORE:-${RUNNER_TEMP}/git-credentials}"

umask 077
touch "$store_path"
chmod 600 "$store_path"

entry="https://${username}:${token}@${host}"
remaining="$(grep -v "@${host}\$" "$store_path" || true)"
printf '%s\n' "$remaining" | sed '/^$/d' >"$store_path"
printf '%s\n' "$entry" >>"$store_path"

git config --global credential.helper "store --file=${store_path}"

# Re-login so `gh auth token` (connector gh-auth fallback) returns the remint.
# stdin is the token; never echo it. Clear GH_TOKEN/GITHUB_TOKEN: `gh auth login`
# refuses to store credentials while either is set in the environment.
env -u GH_TOKEN -u GITHUB_TOKEN \
  printf '%s\n' "$token" \
  | env -u GH_TOKEN -u GITHUB_TOKEN \
    gh auth login --with-token --hostname "$host" >/dev/null

# Prove the credential resolves without echoing the secret.
if ! printf 'protocol=https\nhost=%s\n\n' "$host" \
  | GIT_TERMINAL_PROMPT=0 git \
    -c credential.helper= \
    -c credential.helper="store --file=${store_path}" \
    credential fill 2>/dev/null \
  | grep -q '^password='; then
  echo "refreshed credential did not resolve via git credential fill" >&2
  exit 1
fi

if ! env -u GH_TOKEN -u GITHUB_TOKEN gh auth token --hostname "$host" >/dev/null; then
  echo "refreshed credential did not resolve via gh auth token" >&2
  exit 1
fi

echo "refreshed GitHub App installation token for ${host}"
