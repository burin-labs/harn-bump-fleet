Stopped re-certifying a release attempt that is already proved. When a run
adopts an existing `release-attempt` branch, it now reads the certification
recorded against that exact commit and skips the two-hour re-run when every
required lane is green. A settled failure refuses rather than quietly
re-certifying, and absent or unfinished evidence certifies rather than reading
silence as proof.
