#!/usr/bin/env bash
set -euo pipefail

# Translate the canonical local release vocabulary into the closed input
# contract owned by hosted-release.yml. Unknown flags fail closed rather than
# silently changing the release plan.

die() {
  printf 'error: %s\n' "$1" >&2
  exit 2
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  [ -n "$value" ] || die "${flag} requires a value"
}

mode="audit"
bump="patch"
preid=""
at_sha=""
base="main"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode|--bump|--preid|--at-sha|--base)
      flag="$1"
      require_value "$flag" "${2:-}"
      value="$2"
      shift 2
      case "$flag" in
        --mode) mode="$value" ;;
        --bump) bump="$value" ;;
        --preid) preid="$value" ;;
        --at-sha) at_sha="$value" ;;
        --base) base="$value" ;;
      esac
      ;;
    --mode=*) mode="${1#--mode=}"; shift ;;
    --bump=*) bump="${1#--bump=}"; shift ;;
    --preid=*) preid="${1#--preid=}"; shift ;;
    --at-sha=*) at_sha="${1#--at-sha=}"; shift ;;
    --base=*) base="${1#--base=}"; shift ;;
    --agent|--yes-live-release|--no-chat) shift ;;
    *) die "hosted release handoff cannot represent ${1}; dispatch manually or use a supported typed workflow input" ;;
  esac
done

case "$mode" in
  prepare|ship-pr) ;;
  *) die "hosted release handoff requires mode prepare or ship-pr, got ${mode}" ;;
esac

case "$bump" in
  patch|minor|major|premajor|preminor|prepatch|prerelease) ;;
  *) die "unsupported semantic version bump: ${bump}" ;;
esac

[ "$base" = "main" ] || die "hosted release workflow owns base main; got ${base}"
if [ -n "$at_sha" ] && ! [[ "$at_sha" =~ ^[0-9a-f]{40}$ ]]; then
  die "--at-sha must be a full 40-character lowercase commit SHA"
fi
case "$bump" in
  premajor|preminor|prepatch|prerelease)
    [ -n "$preid" ] || die "${bump} requires --preid"
    ;;
  *)
    [ -z "$preid" ] || die "--preid is only valid for prerelease bumps"
    ;;
esac

printf 'macOS live release: dispatching canonical hosted owner (mode=%s, bump=%s, at_sha=%s)\n' \
  "$mode" "$bump" "${at_sha:-origin/main at runner start}"

exec gh workflow run hosted-release.yml \
  --repo burin-labs/harn-bump-fleet \
  --ref main \
  -f "mode=${mode}" \
  -f "bump=${bump}" \
  -f "prerelease_identifier=${preid}" \
  -f "at_sha=${at_sha}"
