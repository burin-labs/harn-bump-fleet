- Before publishing a Harn tag, the release harness now runs the current
  workflow from `main` while measuring the exact immutable release candidate.
  Chat-policy tests also receive terminal and environment state explicitly, so
  they no longer depend on the developer shell that runs them.
