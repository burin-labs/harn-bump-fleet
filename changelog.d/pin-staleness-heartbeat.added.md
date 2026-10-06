Add a scheduled heartbeat, in a different workflow from the pin-staleness
alarm, that fails and files one issue when that alarm has not completed
successfully within two days — so a dead cron, a lost `issues: write` grant,
or a broken `harn install` cannot look like a healthy fleet.
