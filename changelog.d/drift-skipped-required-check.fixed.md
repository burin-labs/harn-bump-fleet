Stopped deferring a release because a path-gated required check skipped. The
v0.10.129 cut refused with "commit 2937eb1d929a5dd9736fb94371f6e97aa37b9119
landed on main without passing Deploy docs"; that check had concluded `SKIPPED`,
not failed. Nine of the twelve main commits before the refusal carried the same
skip, so the rule deferred a cut on almost any drift rather than a rare one.
Whether a check passed now has one owner, `admission_state_is_passing`, which
admits `SUCCESS`, `NEUTRAL`, and `SKIPPED` the way the pull-request admission
path already did. A settled failure and a context that never reported still
block and still name themselves.
