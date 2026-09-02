- The pre-tag binary-size gate is now a distribution-fuse gate. It requires the
  release build's `Check the distribution fuse` step by name rather than
  inheriting fuse coverage from a skipped growth step, and growth crossings no
  longer refuse a tag. A stale baseline costs a warning instead of a release.
- The gate reuses a workflow run that already measured the exact release source
  under the exact release policy, instead of dispatching a second ~40-minute
  Linux build for it. The v0.10.126 cut paid for that build twice.
- A size verdict that already failed for this source under this policy now
  fails the gate immediately with that run's URL. Re-dispatching cannot change
  arithmetic over unchanged bytes, and the previous behaviour spent a full
  build being told so again. A lookup that cannot answer fails closed rather
  than reading as "nothing was measured".
