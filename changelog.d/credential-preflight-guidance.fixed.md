Point at the credential seam before a launch burns on missing keys. `usage()`
now documents that Harn reads provider keys from the environment and does not
auto-load `.env`, with the `scripts/with_env.sh` wrapper and its discovery
order. The planner-preflight failure appends the same runnable remediation, so a
missing `--agent`/live-release credential fails with the exact command to fix it
instead of a bare no-healthy-provider error.
