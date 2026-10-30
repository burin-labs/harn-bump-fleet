#!/usr/bin/env bash
set -euo pipefail

# Resolve the credential store a confined release must be able to read.
#
# Pushing the signed release tag is the step that publishes a release, and the
# push authenticates through `credential.helper store --file=...`. The store
# file deliberately lives outside every checkout ($RUNNER_TEMP on a hosted
# runner) so no status check or stray `git add -A` can pick it up -- which is
# exactly why no checkout-derived sandbox grant ever covers it. The helper is
# only consulted when a transport authenticates, so every earlier confined git
# call succeeds and the gap surfaces at the one moment that matters: the tag
# push, after the release commit has already merged to the default branch.
#
# Prints the absolute store path for each `store --file=` helper configured
# globally, prints nothing when no file-backed store is configured, and exits 2
# when a store is configured but unreachable. Configured-but-unreachable must
# stop the run before any release work is spent, not degrade to a push that
# fails with "could not read Username" once the tag exists.

helpers="$(git config --global --get-all credential.helper 2>/dev/null || true)"

status=0
while IFS= read -r helper; do
  case "$helper" in
    store\ *--file=*)
      store_path="${helper#*--file=}"
      # Trim anything after the path; git config hands us the raw value and
      # our writers never embed spaces in the store path.
      store_path="${store_path%% *}"
      store_path="${store_path/#\~/${HOME}}"
      case "$store_path" in
        /*) ;;
        *) continue ;;
      esac
      if [ ! -e "$store_path" ]; then
        echo "git credential store is configured as ${store_path}, but no such file exists." >&2
        echo "  A confined tag push would fail to authenticate here, and on the" >&2
        echo "  release path that failure lands only after the release commit" >&2
        echo "  has merged." >&2
        status=2
        continue
      fi
      printf '%s\n' "$store_path"
      ;;
    *)
      # A helper without a file (osxkeychain, bare `store`, cache, ...) needs
      # no read grant from us.
      ;;
  esac
done <<< "$helpers"

exit "$status"
