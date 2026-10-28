A fleet dispatch made between a Harn tag and its release binaries no longer burns
a round and dispatches nothing. The fleet bootstraps the runtime it is rolling
out, so the job used to die inside the setup action before any fleet code ran,
which made the release-readiness wait unreachable in exactly the case it exists
for. The pinned runtime is installed first, the readiness wait names the missing
assets and waits for them, and the exact target runtime is installed after that.
