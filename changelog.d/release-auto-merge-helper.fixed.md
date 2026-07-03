Centralized release PR auto-merge CLI fallback construction so the normal
release PR and post-merge paperwork PR paths share the same queue-safe
`gh pr merge --auto` ordering.
