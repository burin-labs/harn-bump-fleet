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
  `origin/<base>` HEAD). Before resolving the pin in live mode (no `--at-sha`,
  not audit, `--yes-live-release` set, and not already on a `release/v*` branch),
  `pre_release_sync_local_base` stashes any dirty tracked/untracked changes under
  `release_harn-auto-stash-<run-id>`, switches to `<base>` if needed, and
  fast-forwards from origin — so the pin SHA we freeze reflects current
  `origin/<base>` and the local checkout matches what we just pinned. The shared
  primitive is `lib/checkout_cleanup::sync_base_branch`; release-branch checkouts
  defer to `normalize_release_analysis_checkout` (which knows fresh-prepare from
  stale-prepare). The release branch is parented at that SHA and never rebased
  before push, the tag is pushed pre-PR, and the harn-side `publish-release.yml` ships
  from the tag — so commits that land on `<base>` between PR-open and merge cannot leak
  into the published artifact. **Post-publish fixup mode:** if the required release
  assets exist for `v$next_version` AND a `release/v$next_version` PR is open, the harness
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
  **Post-merge drift mode** (third auto-mode after repin and fixup):
  fires when a previous release cycle fully merged (PR closed, binary on
  crates.io with all GitHub release assets) but main's `## v$current`
  body diverges from pin-time `## Unreleased`. This happens when
  GitHub's 3-way merge absorbs post-pin bullets that landed on
  `## Unreleased` during the release PR window — `release-pr-drift-check`
  warns about this, but if it isn't a required gate, auto-merge fires
  anyway and only the CHANGELOG ends up wrong (binary is correct). The
  next `release_harn ship-pr --yes-live-release` rerun auto-detects this
  state via `detect_post_merge_drift` and opens a paperwork-only PR on
  `paperwork/v$current-changelog-fix`: restores `## v$current` to
  pin-time content (via `changelog_repair_post_merge_drift`) and moves
  the absorbed drift back to `## Unreleased`. The commit carries an
  `Allow-Retroactive-Changelog:` trailer so the harn-repo's
  retroactive-edit guard accepts the post-publish fix-up. Idempotent
  (returns early when a paperwork PR is already open).
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
- `run_chat_loop` from `lib/chat_loop.harn` (post-run + pre-release-gate
  interactive agent). Built on `std/agent/chat::agent_chat_loop`,
  `std/io::is_tty`/`read_line`, `std/tui::page`/`select_from`, and
  `agent_session_seed_from_jsonl` so the post-run session restarts from
  the prior recovery transcript without re-priming the prefix cache.
  Auto-enabled when `is_tty(0)` reports true; CI never enters chat
  because stdin is captured. `--no-chat` / `HARN_CHAT=0` are hard
  kill-switches. The chat agent gets the same read+edit tool surface as
  the recovery loop (`release_repair_tools` / `bump_chat_tools`), so it
  can apply meta-fixes when the operator asks.

When adding a new model touchpoint, follow the same pattern: shape inputs deterministically,
let the agent produce text, then validate/parse before letting it influence output. If model
output fails to parse after one repair attempt, fall back to deterministic facts rather than
erasing the audit (see `bump_summary` in `lib/`).

**Planner + binder defaults.** All agent calls source their default
provider/model from `lib/llm_defaults`:

- `planner_defaults("HARN_<ROLE>")` — per-role env knob (e.g.
  `HARN_RELEASE_MODEL`) > shared `HARN_PLANNER_*` > cloud cell
  (OpenRouter DeepSeek V3.2 if `OPENROUTER_API_KEY` is in env) > local
  Ollama (`qwen3.6:35b-a3b-coding-nvfp4`). Never bake `provider:
  "ollama"` or `model: "qwen3.6:..."` into a new agent call site — route
  through `planner_defaults` so the cloud/local switch stays in one
  place.
- `install_binder(tools)` — returns `{tools, tool_caller, audit}`. The
  binder is the natural-language tool middleware from PR
  burin-labs/harn#1814 (+18pp lift); it injects an optional `_nl_intent`
  field on every tool schema and uses Cerebras GPT-OSS-120B by default
  to canonicalize tool args. Off automatically when `CEREBRAS_API_KEY`
  isn't set; force on/off with `HARN_BINDER=1`/`0`. Spread
  `binder.tools` and `binder.tool_caller` into `agent_preset(...)`
  options at every tool-using agent loop. When you add a NEW tool-using
  agent call site, wire it through `install_binder` — the layer is
  a passthrough when disabled, so the call is uniform.
- `binder_audit_line(audit)` / `planner_audit_line(planner)` — one-line
  console banners; release_harn prints both at the top of every run.

**Env / `.env` loading.** Harn does not auto-load `.env`. Use
`scripts/with_env.sh` to source `~/projects/burin-code/.env` (override
with `HARN_BUMP_FLEET_ENV_FILE`) + `./.env` + `./.env.local` before
exec'ing the rest of the command. Compose with the AMFI shield as
needed:

```sh
scripts/with_env.sh scripts/harn_shielded.sh run release_harn.harn -- --mode ship-pr --agent --yes-live-release
```

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

Route boilerplate-prone patterns through the stdlib helpers:
- `std/cli::parse_args` for argv parsing (spec-driven; reserved `_extras`/`_errors`/`_help` keys).
- `std/poll::poll_until` / `wait_for_status` / `retry_with_result` for any "probe until
  truthy / terminal status / exponential-backoff" loop. Zero-arg closures must use
  `fn() { return ... }` — the bare `{ -> ... }` form is stripped by `harn fmt` and
  becomes ambiguous with a dict literal.
- `std/settled::partition` / `map_settled` / `summary` for any `parallel settle`
  follow-up that hand-walks the Result list.
- `std/jsonl::read_jsonl` / `write_jsonl` for transcript/event files (lenient by default).
- `std/config::env_str` / `env_bool` / `model_from_env` / `parse_model_id` for
  env-derived configuration. Closures cannot mutate enclosing `var` bindings, so
  manual `while now_ms() < deadline { ... attempt = attempt + 1 ... }` loops are
  still the right shape for poll loops that need per-attempt progress prints.
- `std/io::is_tty` / `read_line` and `std/tui::page` / `select_from` for
  TTY-aware prompts, paged artifact display, and fzf-aware pickers — the
  chat loop and pre-release gate use both.
- `std/agent/chat::agent_chat_loop` (+ `agent_chat_route_input`) for
  multi-turn operator chat with shared slash routing — wraps
  `agent_session_open` / `agent_session_close` / `agent_loop` so callers
  pass `on_user_input` / `on_model_turn` callbacks rather than driving
  the loop by hand.
- `agent_session_seed_from_jsonl(path, opts)` to lift an earlier run's
  `llm_transcript.jsonl` sidecar into a fresh session so the prefix
  cache stays warm across the recovery→chat handoff.
- `std/signal::on_interrupt` / `with_interrupt` for cooperative SIGINT
  cleanup on long-running operator-driven loops.

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
