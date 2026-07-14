The live-release owner guard now records its own process id, so a crashed run
leaves a probeable owner. A stalled owner record on this host is reclaimed
automatically with a logged receipt when its process is gone: a recorded pid is
probed directly, and a record written without a pid falls back to a host scan
that still refuses to reclaim while any live release_harn process remains. This
removes the manual HARN_RELEASE_OWNER_TAKEOVER=1 step for the common crashed-run
case without ever letting two live lanes share a release branch or tag.
