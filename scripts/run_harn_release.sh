#!/usr/bin/env bash
set -euo pipefail

# Canonical release boundary. A release-readiness audit must run where the live
# release runs or it cannot certify the conditions that decide the release.
# Route canonical audits to the hosted owner on every operator platform. Keep
# only explicit --local-audit diagnosis and fully mocked runs local.
#
# A live macOS prepare/ship cannot certify source correctly either: the release
# audit intentionally exercises nested OS sandboxes, and Seatbelt rejects a
# second sandbox-exec profile under Harn's default-deny outer profile. Route
# that known-impossible shape to the hosted Linux owner before spending the
# local build.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="${HARN_EXT_RELEASE_REPO:-${HOME}/projects/harn}"

mode="audit"
live_release=0
mock_run=0
local_audit=0
at_sha=""
args=("$@")
index=0
while [ "$index" -lt "${#args[@]}" ]; do
  arg="${args[$index]}"
  case "$arg" in
    --mode)
      index=$((index + 1))
      if [ "$index" -lt "${#args[@]}" ]; then
        mode="${args[$index]}"
      fi
      ;;
    --mode=*) mode="${arg#--mode=}" ;;
    --at-sha)
      index=$((index + 1))
      if [ "$index" -lt "${#args[@]}" ]; then
        at_sha="${args[$index]}"
      fi
      ;;
    --at-sha=*) at_sha="${arg#--at-sha=}" ;;
    --yes-live-release) live_release=1 ;;
    --mock) mock_run=1 ;;
    --local-audit) local_audit=1 ;;
  esac
  index=$((index + 1))
done

# Announce every passage through this boundary, before dispatching anything.
#
# A release that nobody knew about is not a hypothetical: on 2026-08-20 a hosted
# release ran for twenty minutes while three sessions established, one by one,
# that it belonged to none of them. GitHub could not answer it either -- the
# actor and triggering_actor fields both read as the shared account, which
# identifies nobody. That is why `actor` here is CALLER-SUPPLIED and defaults to
# something locally meaningful rather than to a git or GitHub identity.
#
# Emitted before the exec so that passing through this boundary and announcing
# are the same act. An announcement that only happened on success would go
# missing in exactly the case where you most want it: a dispatch that failed
# somewhere the operator did not see.
#
# stderr is unconditional. The file sink is opt-in via
# HARN_EXT_RELEASE_ANNOUNCE_FILE
# because where a fleet keeps its board is local configuration, not something
# this repository should hardcode a path for.
announce_release_boundary() {
  local route="$1"
  local stamp
  stamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local actor="${HARN_EXT_RELEASE_ACTOR:-${USER:-unknown}@$(hostname -s 2>/dev/null || echo unknown-host)}"
  local line
  line="$(printf 'harn-release-dispatch ts=%s actor=%s mode=%s route=%s live=%s at_sha=%s repo=%s' \
    "$stamp" "$actor" "$mode" "$route" "$live_release" "${at_sha:-<unpinned>}" "$target_repo")"
  printf '%s\n' "$line" >&2
  if [ -n "${HARN_EXT_RELEASE_ANNOUNCE_FILE:-}" ]; then
    # Never let an unwritable board stop a release; report and continue.
    if ! printf '%s\n' "$line" >> "${HARN_EXT_RELEASE_ANNOUNCE_FILE}" 2>/dev/null; then
      printf 'warning: could not append release announcement to %s\n' \
        "${HARN_EXT_RELEASE_ANNOUNCE_FILE}" >&2
    fi
  fi
}

if { [ "$mode" = "audit" ] \
    && [ "$mock_run" -eq 0 ] \
    && [ "$local_audit" -eq 0 ]; } \
  || { [ "$(uname -s)" = "Darwin" ] \
    && [ "$live_release" -eq 1 ] \
    && { [ "$mode" = "prepare" ] || [ "$mode" = "ship-pr" ]; }; }; then
  canonical_repo="${HOME}/projects/harn"
  if [ "$target_repo" != "$canonical_repo" ]; then
    printf 'error: hosted release handoff cannot represent HARN_EXT_RELEASE_REPO=%s; expected canonical checkout %s\n' \
      "$target_repo" "$canonical_repo" >&2
    exit 2
  fi
  announce_release_boundary hosted
  exec "${script_dir}/dispatch_hosted_release.sh" "$@"
fi

announce_release_boundary confined

exec "${script_dir}/harn_confined.sh" \
  "$target_repo" \
  -- \
  "${repo_root}/release_harn.harn" \
  -- \
  "$@"
