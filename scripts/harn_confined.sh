#!/usr/bin/env bash
set -euo pipefail

# Internal boundary for native release automations that need one sibling checkout.
# Usage: harn_confined.sh TARGET_REPO [HARN_RUN_OPTIONS...] -- SCRIPT [ARGS...]

if [ "$#" -lt 3 ]; then
  echo "usage: harn_confined.sh TARGET_REPO [HARN_RUN_OPTIONS...] -- SCRIPT [ARGS...]" >&2
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
target_repo="$1"
shift

artifact_import_egress=0
if [ "${1:-}" = "--github-artifact-import-egress" ]; then
  artifact_import_egress=1
  shift
fi

run_args=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
  run_args+=("$1")
  shift
done
if [ "$#" -eq 0 ]; then
  echo "harn_confined: missing -- before the Harn script" >&2
  exit 2
fi
shift
if [ "$#" -eq 0 ]; then
  echo "harn_confined: missing Harn script" >&2
  exit 2
fi

script_args=("$@")
repo_arg_seen=0
for ((index = 0; index < ${#script_args[@]}; index++)); do
  case "${script_args[$index]}" in
    --repo)
      if ((index + 1 >= ${#script_args[@]})); then
        echo "harn_confined: --repo requires a path" >&2
        exit 2
      fi
      target_repo="${script_args[$((index + 1))]}"
      repo_arg_seen=1
      ;;
    --repo=*)
      target_repo="${script_args[$index]#--repo=}"
      repo_arg_seen=1
      ;;
  esac
done

if [ ! -d "$target_repo" ]; then
  echo "harn_confined: target checkout does not exist: $target_repo" >&2
  exit 2
fi
target_repo="$(cd -- "$target_repo" && pwd -P)"
if [ "$repo_arg_seen" -eq 0 ]; then
  script_args+=(--repo "$target_repo")
fi

# Release worktrees live in one dedicated sibling root. Granting that root
# keeps the source checkout immutable without authorizing unrelated worktrees
# or the checkout's parent directory. This projection intentionally mirrors
# lib/release_workspace.harn; the Harn contract test guards both spellings.
git_common_dir="$(git -C "$target_repo" rev-parse --path-format=absolute --git-common-dir)"
if [ "$(basename -- "$git_common_dir")" != ".git" ]; then
  echo "harn_confined: target does not resolve to a non-bare Git checkout: $target_repo" >&2
  exit 2
fi
primary_checkout="$(dirname -- "$git_common_dir")"
release_workspace_root="$(dirname -- "$primary_checkout")/$(basename -- "$primary_checkout")-release-workspaces"
if [ -L "$release_workspace_root" ]; then
  echo "harn_confined: release workspace root must not be a symlink: $release_workspace_root" >&2
  exit 2
fi
mkdir -p -- "$release_workspace_root"
release_workspace_root="$(cd -- "$release_workspace_root" && pwd -P)"

sandbox_args=(--allow-process-network)
if [ "$artifact_import_egress" -eq 0 ]; then
  sandbox_args+=(
    --write-root "$target_repo"
    --write-root "$release_workspace_root"
  )
fi

add_harn_write_root() {
  local path="$1"
  if [ -e "$path" ]; then
    sandbox_args+=(--write-root "$path")
  fi
}

add_process_root() {
  local access="$1"
  local path="$2"
  if [ -e "$path" ]; then
    sandbox_args+=("--sandbox-${access}-root" "$path")
  fi
}

if [ "$artifact_import_egress" -eq 0 ]; then
  identity_material=()

  # Git signs through the inherited agent but reads these public configuration
  # files. Cargo and sccache need mutable caches; Harn builtins do not.
  add_process_root read "${HOME}/.gitconfig"
  add_process_root read "${HOME}/.ssh/id_ed25519.pub"
  add_process_root read "${HOME}/.ssh/codex_allowed_signers"

  # The entries above only ever reach a signing key under `$HOME`, which is the
  # operator's layout. A hosted runner keeps its key outside every checkout, so
  # nothing above grants it and the confined `git tag -s` cannot read it.
  # `release_signing_key_root.sh` owns that resolution for both layouts and fails
  # loudly rather than skipping an unreachable key -- a silent skip is what let
  # this surface only after the release commit had already merged.
  signing_key_root="$("${script_dir}/release_signing_key_root.sh")"
  if [ -n "$signing_key_root" ]; then
    identity_material+=("$signing_key_root")
  fi

  # The push that publishes the tag authenticates through a file-backed
  # credential helper whose store also lives outside every checkout on a hosted
  # runner. Same shape as the signing key, one step later: every confined git
  # call succeeds until the transport consults the helper, and the unreadable
  # store surfaces as "could not read Username" on the tag push itself.
  # `release_credential_store_root.sh` resolves whatever store git is configured
  # to use and fails loudly when it is unreachable.
  credential_store_roots="$("${script_dir}/release_credential_store_root.sh")"
  while IFS= read -r credential_store_root; do
    [ -n "$credential_store_root" ] || continue
    identity_material+=("$credential_store_root")
  done <<< "$credential_store_roots"

  # Grant the identity material as roots, collapsed to the runner's secret
  # scratch directory when that is where it lives. `release_identity_roots.sh`
  # owns that decision and explains why a file-scoped grant is the fragile form.
  while IFS= read -r identity_root; do
    [ -n "$identity_root" ] || continue
    sandbox_args+=(--sandbox-read-root "$identity_root")
  done < <("${script_dir}/release_identity_roots.sh" ${identity_material[@]+"${identity_material[@]}"})
  add_process_root read "${RUSTUP_HOME:-${HOME}/.rustup}"
  add_process_root write "${CARGO_HOME:-${HOME}/.cargo}"
  add_process_root write "${SCCACHE_DIR:-${HOME}/Library/Caches/Mozilla.sccache}"
fi
add_harn_write_root "${HARN_HOST_LEASE_ROOT:-${HARN_HOME:-${HOME}/.harn}/host-leases}"
add_harn_write_root "${HARN_CACHE_DIR:-${HOME}/Library/Caches/harn}"

cd "$repo_root"
github_config_parent="${repo_root}/.harn-runs"
github_config_root="${github_config_parent}/github-config"
if [ -L "$github_config_parent" ] || [ -L "$github_config_root" ]; then
  echo "harn_confined: private GitHub config root must not be a symlink" >&2
  exit 2
fi
mkdir -p -- "$github_config_root"
github_config_root="$(cd -- "$github_config_root" && pwd -P)"
case "$github_config_root" in
  "${repo_root}"/.harn-runs/github-config) ;;
  *)
    echo "harn_confined: private GitHub config root escaped the harness checkout" >&2
    exit 2
    ;;
esac
if [ "$artifact_import_egress" -eq 1 ]; then
  # Do not source the release environment here: this phase needs GitHub auth,
  # not provider tokens or signing identity. `with_github_auth.sh` resolves the
  # operator login before recursive process confinement starts.
  exec "${script_dir}/with_release_egress.sh" \
    --github-artifact-import \
    "${script_dir}/with_github_auth.sh" \
    --private-config-root "$github_config_root" \
    --minimal-artifact-env \
    "${script_dir}/harn_shielded.sh" \
    run \
    "${run_args[@]}" \
    "${sandbox_args[@]}" \
    "${script_args[@]}"
fi
exec "${script_dir}/with_env.sh" \
  "${script_dir}/with_release_egress.sh" \
  "${script_dir}/with_github_auth.sh" \
  --private-config-root "$github_config_root" \
  "${script_dir}/harn_shielded.sh" \
  run \
  "${run_args[@]}" \
  "${sandbox_args[@]}" \
  "${script_args[@]}"
