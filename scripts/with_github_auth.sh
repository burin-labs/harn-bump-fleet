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

private_config_root=""
minimal_artifact_env=0
if [ "${1:-}" = "--private-config-root" ]; then
  if [ "$#" -lt 3 ]; then
    echo "with_github_auth: --private-config-root requires a root and command" >&2
    exit 2
  fi
  private_config_root="$2"
  shift 2
fi
if [ "${1:-}" = "--minimal-artifact-env" ]; then
  minimal_artifact_env=1
  shift
fi

if [ "$#" -eq 0 ]; then
  echo "with_github_auth: nothing to exec" >&2
  exit 2
fi

if [ -n "$private_config_root" ]; then
  case "$private_config_root" in
    /*) ;;
    *)
      echo "with_github_auth: private config root must be absolute" >&2
      exit 2
      ;;
  esac
  if [ -L "$private_config_root" ]; then
    echo "with_github_auth: private config root must not be a symlink" >&2
    exit 2
  fi
  mkdir -p -- "$private_config_root"
  private_config_root="$(cd -- "$private_config_root" && pwd -P)"
  private_config="$(mktemp -d "${private_config_root}/session.XXXXXX")"
  # shellcheck disable=SC2329  # invoked by the EXIT trap
  cleanup_private_config() {
    case "$private_config" in
      "${private_config_root}"/session.*) rm -rf -- "$private_config" ;;
      *) echo "with_github_auth: refusing unsafe private config cleanup" >&2 ;;
    esac
  }
  trap cleanup_private_config EXIT
  export GH_CONFIG_DIR="$private_config"
  if [ "$minimal_artifact_env" -eq 1 ]; then
    # Keep only runtime coordinates and the GitHub credential resolved above.
    # In particular, provider and signing credentials from the caller cannot
    # reach the short-lived artifact importer.
    while IFS= read -r name; do
      case "$name" in
        HOME|PATH|TMPDIR|TMP|TEMP|USER|LOGNAME|SHELL|LANG|LC_*|TERM|COLORTERM|NO_COLOR) ;;
        GH_TOKEN|GITHUB_TOKEN|GH_CONFIG_DIR) ;;
        HARN_BIN|HARN_HOME|HARN_HOST_LEASE_ROOT|HARN_CACHE_DIR|XDG_CACHE_HOME|HARN_EXT_SHIELDED_DIR) ;;
        HARN_EGRESS_ALLOW|HARN_EGRESS_DENY|HARN_EGRESS_DEFAULT|HARN_EGRESS_BLOCK_PRIVATE|HARN_EGRESS_ALLOW_LOOPBACK) ;;
        *) unset "$name" || true ;;
      esac
    done < <(compgen -e)
  fi
  "$@"
  exit $?
fi
exec "$@"
