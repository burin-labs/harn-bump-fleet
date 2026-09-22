Release agent loops now declare `policy.workspace_roots` for the release
worktree, so tool reads and commands under `cfg.repo` are not rejected by the
top-level `agent_loop` OsHardened fallback that jails to the fleet checkout.
