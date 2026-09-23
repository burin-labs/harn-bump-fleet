Live `release_harn --mode ship-pr` now re-checks base drift before the prepare
step mutates or pushes a release branch, so stale pins fail in seconds with
repin guidance while the final pre-tag guard remains the publication gate.
