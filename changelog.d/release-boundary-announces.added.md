Every dispatch through the release launcher now announces itself before it execs,
carrying timestamp, actor, mode, route, live flag, pinned SHA, and repo. The line
always goes to stderr, and is appended to a board file when
`HARN_EXT_RELEASE_ANNOUNCE_FILE` is set.
