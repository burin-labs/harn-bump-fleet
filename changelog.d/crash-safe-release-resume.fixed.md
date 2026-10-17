A crashed live release that left a dirty `release/vX.Y.Z` branch no longer needs
hand-driven recovery. When the owner guard reclaims a provably dead owner for the
exact target version, preflight may discard that crashed run's dirty release
branch and recreate it at the pin — but only when there is also no open PR and
no unique un-pushed commits on it. The discard emits a forensic receipt (branch,
head sha, dirty file count) to the run event log. Any missing gate preserves the
existing fail-loud behavior, so a dirty tree without the reclaim signal still
stops the run.
