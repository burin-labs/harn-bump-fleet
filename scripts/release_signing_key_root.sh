#!/usr/bin/env bash
set -euo pipefail

# Resolve the signing key a confined release must be able to read.
#
# The signed release tag is the one artifact the release confinement exists to
# produce, and the key lives in a different place depending on who is running:
# an operator keeps it under `$HOME`, while a hosted runner writes it into
# `$RUNNER_TEMP`, deliberately outside every checkout so no status check or
# stray `git add -A` can pick it up. Enumerating locations is what made those
# two paths disagree, so resolve the key git is actually configured to use.
#
# Prints the absolute key path when there is one to grant, prints nothing when
# signing is not this invocation's business, and exits 2 when a key is
# configured but unreachable. That last case is the important one: it used to be
# a silent skip, and the resulting failure surfaced only when tagging ran --
# after the release commit had already merged to the default branch.

if [ "$(git config --global gpg.format 2>/dev/null || true)" != "ssh" ]; then
  exit 0
fi

signing_key="$(git config --global user.signingkey 2>/dev/null || true)"

case "$signing_key" in
  "")
    # Nothing configured; nothing to grant.
    exit 0
    ;;
  /* | "~"/*)
    signing_key="${signing_key/#\~/${HOME}}"
    ;;
  *)
    # A literal `ssh-...` public key rather than a path.
    exit 0
    ;;
esac

if [ ! -e "$signing_key" ]; then
  echo "release signing key is configured as ${signing_key}, but no such file exists." >&2
  echo "  A confined signed tag would fail here, and on the release path that" >&2
  echo "  failure lands only after the release commit has merged." >&2
  exit 2
fi

printf '%s\n' "$signing_key"
