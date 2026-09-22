The release watcher now has one canonical launcher that selects and shields the
repo-pinned Harn runtime and grants the protected `git.push` operation needed
for exact leased-ref cleanup. This prevents a healthy long-running watch from
failing only after terminal hosted proof because cleanup lacked a host approval
bridge.
