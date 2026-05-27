# Changelog

## Unreleased

### Added

- Release and self-review agent loops now use Harn's transcript projection and
  compaction policy APIs, preserving projection/compaction metadata in run
  artifacts.
- Harness self-review runs now emit Harn context-eval manifest and report
  artifacts for raw, summary-projected, and clean-tool-repair context variants.

### Fixed

- Fleet dry-runs now apply the same remote-main idempotency pre-check as live
  runs, so stale local checkouts no longer report redundant dispatches when
  origin/main is already on the requested Harn version.
- `bump_fleet.harn` and `release_harn.harn` now detect when they were invoked
  without `harn run --no-sandbox` and exit with a single actionable line instead
  of a cryptic `gh: operation not permitted` from the worktree sandbox blocking
  `~/.config/gh/config.yml`.

### Changed

- Release and bump harness timings now use Harn `std/timing` spans and write
  `trace_spans` plus a compact `timing_summary` into run artifacts.
- Bumped the pinned Harn runtime to `v0.8.35` for first-class timing spans.

### Security

- `scripts/install_harn.sh` now verifies the downloaded harn release tarball
  against the release-published `SHA256SUMS` sidecar before extract. Refuses
  to install when the sidecar is missing or the hash mismatches. Set
  `HARN_NO_VERIFY=1` to opt out (loud stderr warning; do not use in CI).
- `harn.toml` pins `harn-github-connector` to commit
  `b662ea2b280164fddf93a7bba4feab00af02af46` instead of `branch = "main"`. A
  compromised commit to `main` can no longer propagate fleet-wide on the next
  bump-harn cron tick. Bump the rev deliberately when a new connector release
  ships and the diff has been reviewed.
- `.github/workflows/bump-harn.yml` now runs `harn install --locked` first to
  honor the committed lockfile byte-for-byte. Only falls back to an
  unlocked install when `--locked` fails because the Harn version bump itself
  rewrote `generator_version` / `protocol_artifact_version` in the lockfile.
- Added `.github/SECURITY.md` documenting the disclosure channel.
