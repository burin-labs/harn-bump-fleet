Deleting a transient release ref now skips the target checkout's pre-push hook
too. `git_push_ref_plumbing` already covered attempt archival and the
certification branch, but deletion had to stay on a plain `git_push`: the lease
and the hook skip could not travel together, because Harn's reviewed-dispatch
check matched the argv by position and `--no-verify` shifted the lease one
token. burin-labs/harn#6199 gave that shape one structural owner, so both halves
now travel and the runtime pin moves to v0.10.55.

Deletion is the shape that most needed it. A hook can recognize a deletion
unaided — git marks it `(delete)` on the hook's stdin — but recognizing it is
not the same as being able to judge it, and the hook still failed the push over
the checkout's own branch state. That is what left twelve transient refs
stranded on origin, including four the sweep had already proven safe to remove.
