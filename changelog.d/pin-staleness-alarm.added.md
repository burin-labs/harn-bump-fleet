Add a scheduled pin-staleness check that compares every `harn_bump` consumer's
pinned Harn version against the newest published release, and files one
self-closing tracking issue per repository that has fallen too far behind.
Every previous signal reported on a run that happened; nothing fired when the
bump pipeline simply stopped landing.
