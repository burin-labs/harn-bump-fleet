# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A pure Harn-language project (no Python/shell glue) holding three top-level harnesses plus a shared `lib/`:

- `bump_fleet.harn` — discovers every repo under `~/projects/{*harn*,*burin*}` that ships
  `.github/workflows/bump-harn.yml` and dispatches the bump workflow in parallel, polls runs
  to completion, then enables auto-merge on the resulting PRs. Idempotent: a no-op rerun
  is ~6s of probes with zero dispatches.
- `release_harn.harn` — Harn-native counterpart to the `~/projects/harn` `/release-harn`
  skill. Defaults to read-only audit; live mutation requires `--yes-live-release`. Owns
  release branch normalization, CHANGELOG drafting, `prepare`/`ship-pr` modes, recovery
  agent loop, and post-merge checkout cleanup. **Pin model:** every run resolves a
  concrete `cfg.pin_sha` at startup (from `--at-sha` / `HARN_RELEASE_PIN_SHA`, else
  `origin/<base>` HEAD). The release branch is parented at that SHA and never rebased
  before push, the tag is pushed pre-PR, and the harn-side `publish-release.yml` ships
  from the tag — so commits that land on `<base>` between PR-open and merge cannot leak
  into the published artifact. **Post-publish fixup mode:** if `gh release view
  v$next_version` succeeds AND a `release/v$next_version` PR is open, the harness
  auto-detects that the artifact already shipped and switches into a paperwork-only
  pass — recreates the release branch on fresh `<base>`, injects the
  originally-shipped release body verbatim via
  `changelog_inject_existing_release_section`, **preserves `## Unreleased` as-is**
  (those entries describe post-publish work that isn't in the shipped binary and
  belongs in the NEXT release), force-pushes, refreshes the PR body, and
  short-circuits the tag step (`cfg.skip_tag`). Audit + publish-dry-run are also
  force-skipped because the merge-queue CI of the open PR re-runs the same gates
  and the publish artifact is already on crates.io. **Repin mode**
  (`--repin-latest`) is the opt-in inverse for the in-flight case: when v$next
  has NOT yet shipped, advance the pin to fresh `origin/<base>` HEAD so commits
  that landed during the PR window fold into the same release. Runs the full
  audit + dry-run + bump, deletes the stale tag on origin (the TOCTTOU re-check
  immediately before branch reset confirms the remote tag has not moved since
  startup), and re-pushes at the new pin. Requires `--mode ship-pr
  --yes-live-release`; refuses if the release already shipped.
- `harness_self_review.harn` — meta-audit; intentionally not wired into CI. Reads recent
  `.harn-runs/` artifacts and gives a local model read-only tools over `~/projects` for
  cross-referencing.

`lib/*.harn` files are shared helpers — extract into a `lib/` module rather than duplicating
across the top-level harnesses. Each `lib/*.harn` has a matching `tests/*.harn`.

## Commands

The pinned Harn version lives in `.harn-version` (`vX.Y.Z`). CI installs it via
`scripts/install_harn.sh`.

```sh
# Static checks (run all three before committing — these are CI gates).
harn check $(git ls-files '*.harn')
harn fmt --check $(git ls-files '*.harn')
harn lint $(git ls-files '*.harn')

# Auto-format.
harn fmt $(git ls-files '*.harn')

# Run all tests in tests/.
harn test tests/ --verbose

# Run a single test file.
harn test tests/shared_helpers.harn --verbose

# Install/refresh dependencies (pinned in harn.lock).
harn install --locked
```

Common harness invocations are documented in `README.md`. Notable ones:

```sh
harn run bump_fleet.harn -- --dry-run                  # discover-only
harn run bump_fleet.harn -- --only burin-labs/harn-cloud
harn run release_harn.harn                             # read-only audit
harn run release_harn.harn -- --mock --agent --mode ship-pr   # fully mocked rehearsal
harn run release_harn.harn -- --mode ship-pr --agent --yes-live-release
```

## Architecture notes

**Determinism boundary.** Every GitHub interaction is a `gh` shell-out (or
`harn-github-connector` helper with `gh` fallback) — the LLM never drives a side-effect.
Models are confined to:
- `summary_agent` (read-only, end-of-run anomaly bullets) in `bump_fleet.harn`.
- `agent_preset` with a bounded `agent_host_tools` allowlist (`RELEASE_RUN_ARGV_PREFIXES`)
  in `release_harn.harn` for release readiness review and recovery loops.
- A read-only audit agent in `harness_self_review.harn`.

When adding a new model touchpoint, follow the same pattern: shape inputs deterministically,
let the agent produce text, then validate/parse before letting it influence output. If model
output fails to parse after one repair attempt, fall back to deterministic facts rather than
erasing the audit (see `bump_summary` in `lib/`).

**Audit artifacts.** Each harness writes to `.harn-runs/<harness>/<run-id>/` (gitignored).
The release harness additionally emits `crystallization-input/` — a self-contained fixture
for the Harn crystallization importer. Keep deterministic facts separate from
model-authored text in any new audit artifact.

**Idempotency model for bump_fleet.** Origin/main is the source of truth for dispatch
decisions. Local checkout drift is recorded in the audit but does not gate dispatch. A stale
open `automation/bump-harn-runtime` PR with a non-matching head pin is closed before
redispatch so old version bumps cannot sit in the merge queue.

**Standard-library preferences.** Use `std/command` command steps (with
`command_id`/`output_path` references) for long-running side effects so output can be
tailed and replayed. Use `std/git` for the post-run checkout cleanup pattern (`lib/checkout_cleanup.harn`).
Use `std/llm/handlers.with_retry` rather than the deprecated `llm_retries` option, and pass
next-turn tool changes via `next_options` rather than the deprecated
`post_turn_callback.llm_options`.

**Templates.** Markdown/PR-body templates live in `prompts/*.harn.prompt` and are referenced
through the `[asset_roots] prompts = "prompts"` alias in `harn.toml`. Render via
`render(...)`.

## Repository conventions

- This repo is public for CI/transparency. Do not commit private-repo details, customer
  data, secrets, or inside-baseball content from private Burin repos. Generated run
  artifacts are intentionally ignored under `.harn-runs/` and `.harn/`.
- `.harn-version` stores the release tag with the leading `v` (e.g. `v0.8.4`). Both
  `vX.Y.Z` and `X.Y.Z` forms are normalized when comparing pins.
- Scripts are structured to pass `harn check`/`fmt --check`/`lint`/`test` with no warnings.
  When a lint fires, fix it rather than suppressing.
- This repo's own `bump-harn.yml` workflow auto-bumps it through the same fleet flow it
  drives. Don't break that loop (the workflow expects `.harn-version` plus formatted
  `.harn` files in the bump commit).
