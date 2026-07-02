# Changelog

## Unreleased

### Fixed

- `release_harn` now treats a rerun as successful when the remote release tag
  already targets the intended release commit, while still refusing to move a
  remote tag that targets any other commit.
- `release_harn --watch-publish` now evaluates the newest observed run for
  each required release workflow, so a successful manual rerun clears an older
  failed publish/build attempt for the same tag.
- Live `release_harn --mode ship-pr --yes-live-release` now watches the
  tag-triggered publish/build workflows by default, so a release run does not
  finish cleanly while its crates or binary assets are red, cancelled, or
  still only partially uploaded.
- Live `release_harn` publish watches now default to a two-hour horizon and
  include observed workflow run status/URLs while waiting, so long binary
  builds are reported as in progress instead of timing out after the old
  five-minute watch window.
- `bump_fleet` now reports observed queued or in-progress downstream
  `bump-harn.yml` workflow runs as `run_in_progress` with the run URL instead
  of timing out as `run_not_found`.
- Harn release-readiness polling now checks crates.io through its HTTP API
  instead of repeatedly invoking `cargo info`, avoiding Cargo registry/cache
  lock contention during release and bump workflows.
- Remote release-audit offload now prepends standard user tool directories to
  every SSH script, so non-login shells can find `~/.cargo/bin/cargo`,
  user-installed `rg`, and Homebrew tools before deciding to fall back to the
  local audit.
- Remote release-audit offload now requires `cargo-nextest` during the
  prerequisite probe, so audit builders do not silently take Harn's slower
  plain `cargo test --workspace` fallback.
- `release_harn --watch-publish` now scopes publish/build workflow health to
  the pushed release tag, so older cancelled or failed workflow runs cannot
  falsely mark a fresh tag red.
- Live `release_harn` prepare now defaults to a stable user-cache Cargo target
  dir, so clean release worktrees reuse the warmed Harn CLI build across
  releases instead of cold-compiling it every time.

### Added

- `release_harn` remote audit offload now preflights remote scratch-disk free
  space before starting the heavy audit and supports `--require-remote-audit`
  / `HARN_RELEASE_REQUIRE_REMOTE_AUDIT=1` for fail-closed release lanes that
  must abort instead of falling back to a local Mac audit. The free-space floor
  defaults to 120 GiB and can be changed with `--offload-min-free-gb` or
  `HARN_RELEASE_OFFLOAD_MIN_FREE_GB`.
- **Live release audit offload by default.** `release_harn --mode prepare` and
  `--mode ship-pr` now auto-attempt the fail-open remote audit offload for live
  releases, using the existing local-audit fallback for every remote failure.
  `--local-audit`, `HARN_RELEASE_LOCAL_AUDIT=1`, or
  `HARN_RELEASE_OFFLOAD_AUDIT=0` keep the entire audit local.
- **Signed bot-PR rewrite helper.** `sign_bot_prs.harn` inspects selected
  in-repo bot PRs for unsigned commits, refuses risky cases by default
  (forks, queued PRs, non-bot authors, missing heads), and can rewrite the PR
  tree as one signed commit with an exact `--force-with-lease` guard. Dry-run
  is the default; `--live` performs the rewrite and re-checks auto-merge.
- **Release branch push no-verify by default.** `release_harn --mode ship-pr`
  now bypasses the target repo's pre-push hook for the canonical release-branch
  push after the full release audit, generated-content checks, and markdown lint
  have passed. This prevents duplicate local hooks from hanging a live release;
  GitHub CI, merge queue, and tag-triggered publish/build workflows remain the
  authoritative gates.
- **Optional remote audit offload (tornadough), fail-open.** `--offload-audit`
  (or `HARN_RELEASE_OFFLOAD_AUDIT=1`) runs the ~548s `release_gate.sh audit` —
  the long pole that duplicates merge-queue CI — on a remote builder
  (`--offload-host`, default tornadough) and passes the existing
  `release_ship.sh --skip-audit` to the local prepare only when the remote run
  is definitively green. Every other outcome (host unreachable, ssh/transport
  failure, setup failure, or a red remote audit) falls back to the full local
  audit, which stays the correctness backstop — so the path is fail-open by
  construction: a down builder degrades to today's behavior, never an outage.
  Opt-in; the default release path is unchanged. New `lib/remote_offload` with
  `audit_offload_decision`, `remote_audit_skip_decision`, and the ssh/probe
  command builders. Remote scratch dir is `HARN_RELEASE_OFFLOAD_DIR` (default
  `harn-release-audit` under the SSH user's home).
- **Pre-tag base-drift guard.** `release_harn` ship-pr now re-probes
  `origin/<base>` HEAD immediately before the irreversible tag push and refuses
  to tag a pin that fell behind the base while the run was in flight — the
  v0.8.153 "started before the PR merged, never advanced the pin" failure mode,
  where the tag shipped a tree missing commits already on the base. Override
  with `--repin-latest` (fold the new commits in) or `--allow-base-drift` (ship
  the frozen pin on purpose); `--at-sha` and mock mode skip the probe. New pure
  `lib/release_repin::pre_tag_drift_decision`.
- **Opt-in post-tag publish watch** (`--watch-publish` /
  `HARN_RELEASE_WATCH_PUBLISH=1`). Because publishing is tag-first, the heavy
  build/publish workflows only run after the tag exists; this polls those
  tag-triggered runs and, on a confirmed red conclusion, fails loudly with a
  yank path (delete the tag, `cargo yank` immutable crates, re-run). Fail-open:
  a never-confirmed or unobservable publish is an informational note, never a
  release failure. Default flow is unchanged. New `lib/release_health` exports
  `publish_watch_decision` + `publish_failure_yank_lines`.
- `release_harn` and `bump_fleet` now run Harn's run/session view fixture gate
  before shipping or adopting a release, record the tested view schemas, require
  a release note for run/session view contract changes, and annotate downstream
  bump PRs with compatibility metadata before auto-merge.
- **sccache keepalive LaunchAgent** (`scripts/sccache_keepalive.sh` +
  `scripts/install_sccache_keepalive.sh`). Keeps a healthy, *unconfined* sccache
  server owned by the login context so neither harn's `sandbox-exec` nor a
  sandboxed agent shell is ever the first to spawn — and thereby permanently
  confine — the shared daemon. Runs at login and every 2 minutes: restarts a
  poisoned daemon and keeps one alive with idle-timeout disabled. This is the
  machine-wide complement to the in-harness sccache preflight below.
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

- **Remote release audit hygiene.** The offload path now checks release-gate
  tool prerequisites before running the remote audit and cleans stale untracked
  remote checkout state while preserving Cargo build cache.
- **Changelog fragment assembly.** Plain prose fragments are now normalized into
  top-level bullets before release assembly, preventing generated Harn release
  notes from gluing unbulleted fragment text onto the previous entry.
- **Signed bot-PR rewrite guardrails.** Live rewrites now verify the selected
  local checkout's `origin` matches `--repo`, keep queued PRs as a hard refusal,
  and re-read the pushed PR head to confirm no unsigned commits remain before
  re-checking auto-merge.
- The **post-run chat agent now sees the failing step's live logs.** Its seed
  context previously held only the run audit `.md`/`.json`, which record a step
  as `failed (command_failed)` but never embed its stderr — so the agent could
  not see *why* a step failed and guessed (e.g. reporting "LLM budget exhausted"
  when the real cause was an sccache `Operation not permitted` in the prepare
  warm-prebuild). `lib/chat_loop` now folds the error lines + bounded tail of
  every `live-logs/*.log` that contains an error signature into the seed
  context. New pure helpers `failing_step_logs_command` /
  `format_failing_logs_section`.
- `release_harn.harn` now runs an **sccache health preflight** before the
  build-heavy `prepare`/`ship-pr` steps. A shared `sccache` daemon that an
  earlier *sandboxed* build spawned inherits the `sandbox-exec` confinement
  permanently, so it fails every later cargo build machine-wide with
  `Operation not permitted` — which silently broke the v0.8.82 release's
  warm-prebuild even though the run used `--no-sandbox`. The preflight detects
  the poisoned daemon (via `sccache --show-stats` cache-error counters) and
  restarts it so the prepare build spawns a fresh, unconfined server (on-disk
  cache persists). New `lib/sccache_preflight` exports `ensure_healthy_sccache`
  + `sccache_cache_error_count`.
- Fleet dry-runs now apply the same remote-main idempotency pre-check as live
  runs, so stale local checkouts no longer report redundant dispatches when
  origin/main is already on the requested Harn version.
- `bump_fleet.harn` and `release_harn.harn` now detect when they were invoked
  without `harn run --no-sandbox` and exit with a single actionable line instead
  of a cryptic `gh: operation not permitted` from the worktree sandbox blocking
  `~/.config/gh/config.yml`.

### Added

- Interactive flag prompts on the release default path. When `--mode` / `--bump`
  aren't passed **and** stdin is an interactive terminal, `release_harn` now
  prompts for them (`audit`/`prepare`/`ship-pr`, `patch`/`minor`/`major`) with
  the current defaults pre-selected. Gated by `chat_enabled`, so CI, piped/
  redirected stdin, `--no-chat`, and `HARN_CHAT=0` keep today's silent
  defaults untouched. A non-audit mode chosen interactively reminds the
  operator that live side effects still require `--yes-live-release`. New pure
  helpers `release_flag_passed` / `coerce_flag_choice` in
  `lib/release_commands`.

### Changed

- Release-failure output is now plain-language. Instead of
  `failure : agent-review-validation (status 2)`, the run summary leads with a
  jargon-free `✗ failed : <what broke>` headline plus a `next : <what to do>`
  line, keeping the technical `(step …, status …)` as a secondary detail. New
  `lib/release_execution::release_failure_explanation` maps the known failure
  points (agent review, prepare, push, markdown lint, PR/auto-merge, commit).
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
