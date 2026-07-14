Add a repo-local static gate, `check_unbound_symbols.harn`, that flags a
screaming-snake-case module constant referenced but never defined or imported in
its file. `harn check` catches undefined call targets but not bare value
references, so a moved or deleted top-level `const` type-checks clean and only
fails at runtime. The sweep and a new mock end-to-end `release_harn` CI job (the
runtime complement) both run in `harn-static.yml`, closing the gap that dropped
`RELEASE_RUN_ARGV_PREFIXES` until the upstream resolver fix (harn#4708) lands.
