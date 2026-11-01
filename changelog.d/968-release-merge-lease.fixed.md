Release automation now claims one typed GitHub-backed merge lease before it
arms a Harn release candidate. Every auto-merge path re-reads that lease at the
mutation boundary, unrelated pull requests remain inert while it is active,
and a disabled or stale candidate terminates without being silently re-armed.
