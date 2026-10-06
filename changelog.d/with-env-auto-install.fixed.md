`scripts/with_env.sh` now refreshes the repo-local Harn binary when `.harn-version` changes, preventing release and bump harnesses from silently running stale tooling after a repin.
