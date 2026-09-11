#!/usr/bin/env bash
set -euo pipefail

# Collapse the release's identity material to the roots the sandbox should
# grant, given each resolved file path on argv.
#
# A grant scoped to a single file is bound to a path its writers replace. The
# credential store is rewritten on every watch segment, and the arming action
# rewrites it too; both currently truncate in place, which preserves the inode
# and keeps a file-scoped grant working. A writer that switched to the safer
# mktemp-and-rename pattern would break that grant silently -- and it would
# break it at the tag push, after the release commit has already merged, which
# is the one moment this ecosystem has repeatedly proven it cannot afford a
# surprise.
#
# $RUNNER_TEMP is already the designated home for release secrets: the release
# workflow puts the signing key and the credential store there precisely
# because it sits outside every checkout. Collapsing to that directory widens
# the grant without widening the trust, and it stays bounded to one runner's
# ephemeral scratch.
#
# $HOME is deliberately NOT collapsed the same way. An operator's home
# directory is not a secret scratch, so operator-side material stays scoped to
# the exact files git is configured to use.
#
# Prints one root per line, in first-seen order, with duplicates removed.

seen=()

for path in "$@"; do
  [ -n "$path" ] || continue

  if [ -n "${RUNNER_TEMP:-}" ] && [ "${path#"${RUNNER_TEMP}/"}" != "$path" ]; then
    path="$RUNNER_TEMP"
  fi

  duplicate=0
  for granted in ${seen[@]+"${seen[@]}"}; do
    if [ "$granted" = "$path" ]; then
      duplicate=1
      break
    fi
  done
  [ "$duplicate" -eq 1 ] && continue

  seen+=("$path")
  printf '%s\n' "$path"
done
