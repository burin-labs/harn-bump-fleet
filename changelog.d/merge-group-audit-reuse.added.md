`release_harn` now acquires exact Harn CI `merge_group` evidence for the pinned
release commit, closes Harn's canonical receipt with the actual warmed CLI byte
hash, and passes only that receipt back to Harn for residual-audit planning.
Missing, ambiguous, stale, skipped-required, failed, cancelled, query-error,
schema-error, or warm-proof failures keep the complete local audit.
The superseded remote-audit offload policy and its blanket skip path are removed.
