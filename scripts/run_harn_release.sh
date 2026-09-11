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
case "${HARN_EXT_RELEASE_LOCAL_AUDIT:-}" in
  1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Yy]) local_audit=1 ;;
esac
at_sha=""
bump="patch"
preid=""
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
    --bump)
      index=$((index + 1))
      if [ "$index" -lt "${#args[@]}" ]; then
        bump="${args[$index]}"
      fi
      ;;
    --bump=*) bump="${arg#--bump=}" ;;
    --preid)
      index=$((index + 1))
      if [ "$index" -lt "${#args[@]}" ]; then
        preid="${args[$index]}"
      fi
      ;;
    --preid=*) preid="${arg#--preid=}" ;;
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

# Refuse a mutating release before it can enter either execution substrate when
# the canonical base does not name the next development release. The release
# controller performs the same validation later, but reaching it after source
# preparation turns a one-second configuration error into an expensive failed
# cut. `origin/main` is the contract because that is the tree a release may
# fast-forward to and certify.
preflight_development_workspace() {
  if [ "$live_release" -ne 1 ] || { [ "$mode" != "prepare" ] && [ "$mode" != "ship-pr" ]; }; then
    return 0
  fi

  if [ "$mock_run" -eq 0 ]; then
    if ! git -C "$target_repo" fetch --quiet origin \
      refs/heads/main:refs/remotes/origin/main; then
      printf 'error: release preflight could not refresh origin/main in %s; nothing was dispatched\n' \
        "$target_repo" >&2
      return 2
    fi
  fi

  local manifest
  if ! manifest="$(git -C "$target_repo" show origin/main:Cargo.toml 2>/dev/null)"; then
    printf 'error: release preflight could not read origin/main:Cargo.toml in %s; nothing was dispatched\n' \
      "$target_repo" >&2
    return 2
  fi
  local version
  version="$(printf '%s\n' "$manifest" | awk '
    /^\[workspace\.package\][[:space:]]*$/ { in_workspace_package = 1; next }
    /^\[/ { in_workspace_package = 0 }
    in_workspace_package && /^[[:space:]]*version[[:space:]]*=/ {
      line = $0
      sub(/^[^=]*=[[:space:]]*"/, "", line)
      sub(/"[[:space:]]*(#.*)?$/, "", line)
      print line
      exit
    }
  ')"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-dev$ ]]; then
    printf "error: release requires origin/main's exact X.Y.Z-dev workspace version; observed '%s'; nothing was dispatched\n" \
      "${version:-<missing>}" >&2
    return 2
  fi
  printf 'release-preflight workspace_version=%s ref=origin/main status=ready\n' "$version" >&2
}

# Ask every release precondition before anything is leased, dispatched, or
# built. Five hosted attempts were lost in one day, each at a gate first
# exercised between thirty seconds and sixty-five minutes into a cut that could
# not be taken back: a token minted without `workflows`, a mint that expired
# mid-certification, a consumer contract the daily convergence had not
# re-rendered, a consumer whose own guard could not pass on that render, and a
# short `at_sha`. Every one was answerable in under two minutes.
#
# This runs in every mode, including `audit`, because the gates it asks about
# are not mode-specific -- what was mode-specific was the guess about which
# ones mattered, and that guess is what cost the 401.
preflight_release_launch() {
  local preflight="${script_dir}/preflight_release_launch.sh"
  if [ ! -x "$preflight" ]; then
    # Deliberately fatal. A missing preflight that let the release through
    # would be the failure mode the preflight exists to remove: an absent
    # answer reading as a satisfied one.
    printf 'error: release preflight %s is missing or not executable; nothing was dispatched\n' \
      "$preflight" >&2
    exit 2
  fi
  local preflight_args=(--mode "$mode" --bump "$bump" --at-sha "$at_sha")
  if [ -n "$preid" ]; then
    preflight_args+=(--preid "$preid")
  fi
  # A mocked run has no credentials and no live fleet to read; the structural
  # half is still asked, and the credentialed half reports itself unasked.
  if [ "$mock_run" -eq 1 ]; then
    preflight_args+=(--offline)
  fi
  if ! "$preflight" "${preflight_args[@]}"; then
    printf 'error: release preflight refused; nothing was dispatched\n' >&2
    exit 2
  fi
}

# Widen a short `--at-sha` to the exact commit before anything downstream sees
# it. Operators type seven characters; the dispatch receipt, the certification
# branch, and the tag all require forty, and a live cut was refused for that
# mismatch. Resolution happens once, here, and every later step keeps its
# forty-character invariant without knowing an abbreviation was ever typed.
resolve_at_sha() {
  if [ -z "$at_sha" ] || [ ${#at_sha} -eq 40 ] || [ "$mock_run" -eq 1 ]; then
    return 0
  fi
  local resolved
  if ! resolved="$("${script_dir}/preflight_release_launch.sh" --at-sha "$at_sha" --resolve-only)"; then
    printf 'error: could not resolve --at-sha %s to an exact commit; nothing was dispatched\n' \
      "$at_sha" >&2
    exit 2
  fi
  resolved="$(printf '%s' "$resolved" | tr -d '[:space:]')"
  if [ ${#resolved} -ne 40 ]; then
    # An empty or short answer here would otherwise be passed on as the pin.
    printf 'error: commit resolution returned %s, which is not a full commit; nothing was dispatched\n' \
      "${resolved:-<empty>}" >&2
    exit 2
  fi
  printf 'release-preflight at_sha=%s resolved=%s\n' "$at_sha" "$resolved" >&2
  local rewritten=()
  local i=0
  while [ "$i" -lt "${#args[@]}" ]; do
    case "${args[$i]}" in
      --at-sha)
        rewritten+=(--at-sha "$resolved")
        i=$((i + 1))
        ;;
      --at-sha=*) rewritten+=("--at-sha=${resolved}") ;;
      *) rewritten+=("${args[$i]}") ;;
    esac
    i=$((i + 1))
  done
  args=("${rewritten[@]}")
  at_sha="$resolved"
}

resolve_at_sha
# Bash 3.2 treats an empty array under `set -u` as unbound, and a bare
# `run_harn_release.sh` with no arguments is a supported invocation.
if [ "${#args[@]}" -gt 0 ]; then
  set -- "${args[@]}"
fi

preflight_release_launch

preflight_development_workspace

if { [ "$mode" = "audit" ] \
    && [ "$mock_run" -eq 0 ] \
    && [ "$local_audit" -eq 0 ]; } \
  || { [ "$(uname -s)" = "Darwin" ] \
    && [ "$live_release" -eq 1 ] \
    && [ "$mock_run" -eq 0 ] \
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
