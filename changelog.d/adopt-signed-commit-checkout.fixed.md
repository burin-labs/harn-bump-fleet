Adopting a GitHub-signed release commit no longer uses `git reset --hard`,
which Harn's catastrophic command floor hard-denies. The local
`release/vX.Y.Z` branch is force-checked out onto the signed oid instead.
