# Changelog

## Unreleased

### Added

- Per-run LLM **cost ceiling** ($1.00 default) on `release_harn` and `bump_fleet`,
  enforced by Harn's native `llm_budget` preflight: any agent call whose
  projected session cost would cross the ceiling is refused before it reaches
  the provider (surfaces as `budget_exhausted`). Override with
  `HARN_RELEASE_COST_LIMIT_USD` / `HARN_BUMP_FLEET_COST_LIMIT_USD`; set to `0`
  to disable. The resolved ceiling prints in the run header
  (`cost limit : $1.00 per run`). New `lib/llm_defaults` exports
  `install_cost_budget` + `cost_budget_audit_line`.
- `lib/changelog.harn` gained towncrier-style fragment helpers
  (`parse_fragment_filename`, `assemble_fragments_section`,
  `changelog_merge_fragments_into_unreleased`) and a major-bump archive helper
  (`changelog_archive_below_version`). `release_harn.harn::apply_draft_release_notes`
  now folds any `changelog.d/<id>.<category>.md` fragments from the target repo
  into `## Unreleased` before promotion, and stages the fragment files for
  deletion in the same release commit. Falls back cleanly when `changelog.d/`
  is absent or empty.
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

- `lib/llm_defaults` now defaults the planner **unconditionally** to the
  OpenRouter `qwen/qwen3.6-35b-a3b` cloud cell for `release_harn` and
  `bump_fleet`. Local Ollama is no longer the auto-fallback (it kept
  returning HTTP 500s and was silently selected whenever
  `OPENROUTER_API_KEY` was missing from the process env); reach it now only
  by setting `HARN_PLANNER_PROVIDER=ollama` (or a per-role
  `HARN_<ROLE>_PROVIDER`). Source provider keys via `scripts/with_env.sh`.
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
