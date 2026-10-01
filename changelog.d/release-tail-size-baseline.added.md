- The release tail now refreshes harn's binary-size baseline automatically once
  publication is proven. It reads the release build's own structured size
  report, writes the version, source SHA, byte count, observation time, and
  build identity, drops every `accepted_growth` entry, moves the distribution
  fuse only when the refreshed baseline would otherwise leave the required
  headroom band, and opens the pull request.
- The step keys on the publication proof and nothing downstream of it. Fleet
  convergence is skipped whenever an earlier tail phase fails, and a baseline
  that only refreshes after a flawless release is a baseline that goes stale
  exactly when the release process is having a bad week.
