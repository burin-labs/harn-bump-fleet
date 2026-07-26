# AGENTS.md

## Repo shape

This is a Harn-only operations repo. There is no Python or shell glue in the
harnesses themselves.

The entry points are:

- `bump_fleet.harn`: finds local `~/projects/{*harn*,*burin*}` repos with
  `.github/workflows/bump-harn.yml`, dispatches Harn runtime bump workflows,
  polls them, and enables auto-merge on the resulting PRs.
- `release_harn.harn`: mirrors the human `/release-harn` flow for
  `~/projects/harn`. Default mode is read-only audit. Live prepare/ship-pr
  requires `--yes-live-release`.
- `watch_harn_release.harn`: resumes post-tag publish monitoring from the typed
  receipt written by `release_harn`. It never repeats preparation or tagging.
- `harness_self_review.harn`: a local meta-audit over recent `.harn-runs/`
  artifacts. It is not CI and should stay out of the main release/bump path.

Shared code belongs in `lib/*.harn`. Every shared module should have focused
coverage in `tests/*.harn`.

`release_harn.harn` is the thin orchestration entrypoint and public facade.
Release implementation changes belong in the stage that owns the behavior:

- `release_runtime`: CLI/config, harness paths, typed git/GitHub adapters,
  mock commands, run events, and timing
- `release_analysis`: release facts, commit/PR evidence, and deterministic
  analysis prompts
- `release_agent_tools` / `release_agent`: agent tool boundaries, review,
  validation, artifacts, and recovery
- `release_prepare` / `release_checkout`: prepare-audit reuse, cutoff/tag
  reconciliation, branch setup, and checkout state
- `release_notes`: fragments, release notes, and fixup/drift state
- `release_reporting`: PR rendering and execution summaries
- `release_crystallization`: deterministic, agent, and tool fixture streams
  plus their manifest and artifact writer
- `release_modes`: prepare execution, thin ship-phase composition, and cleanup
- `release_ship_prepare`: prepared commit and immutable attempt publication
- `release_ship_tag`: cutoff, binary, and signed-tag gates
- `release_ship_pr`: PR publication and watch-receipt handoff
- `release_preflight`: interactive flags, planner/fleet/sccache checks, and
  build-lock lifecycle

Do not put stage policy back in the entrypoint or add a second implementation
behind a compatibility helper. `check_source_length.harn` enforces a 1,500-line
ceiling for every maintained handwritten source file.

## Commands

Use the pinned Harn version from `.harn-version`.

```sh
harn install --locked
harn check --strict-types $(git ls-files '*.harn')
harn fmt --check $(git ls-files '*.harn')
harn lint --strict $(git ls-files '*.harn')
harn test tests/ --parallel --verbose
```

Use `harn fmt $(git ls-files '*.harn')` for Harn formatting fixes.

Common harness runs:

```sh
harn run --no-sandbox bump_fleet.harn -- --dry-run
harn run --no-sandbox bump_fleet.harn -- --only burin-labs/harn-cloud
harn run --no-sandbox release_harn.harn
harn run --no-sandbox release_harn.harn -- --mock --agent --mode ship-pr
harn run --no-sandbox release_harn.harn -- --mode ship-pr --agent --yes-live-release
harn run --no-sandbox watch_harn_release.harn -- --tag vX.Y.Z --yes-live-release
```

Harn does not auto-load `.env`; use `scripts/with_env.sh` when provider keys
are needed. On macOS, wrap long local runs with `scripts/harn_shielded.sh` if
another session may replace the `harn` binary while the process is running.
The operation harnesses need `--no-sandbox` because they inspect sibling
checkouts, run local Git commands, and let read-only diagnostic agents inspect
authenticated GitHub state.

Run `scripts/install_harn.sh` after a `.harn-version` repin. By default it
installs the pinned CLI into this repo's ignored `.harn/bin`, and
`scripts/with_env.sh` / `scripts/harn_shielded.sh` prefer that binary over a
stale global `harn` on `PATH`.

## Implementation rules

Keep GitHub side effects deterministic. Production GitHub reads and writes go
through typed connector contracts, and every head-sensitive mutation carries
the observed PR-head lease. `gh` is limited to read-only diagnostic agent
allowlists and explicit manual-recovery instructions. Model output may
summarize, audit, or draft text, but deterministic code must validate or parse
it before it affects files, PRs, tags, dispatches, or merge settings.

Route model defaults through `lib/llm_defaults`:

- Use `planner_defaults("HARN_<ROLE>")` for new planner calls.
- Use `install_binder(tools)` for every tool-using agent loop. It is a no-op
  when disabled.
- Print `planner_audit_line` and `binder_audit_line` where a harness already
  reports model routing.

Prefer the Harn stdlib over local helpers:

- `std/cli::parse_args` for argv parsing.
- `std/command` for long-running side effects and reusable output artifacts.
- `std/git` for checkout cleanup and base-branch sync.
- `std/poll`, `std/settled`, `std/jsonl`, and `std/config` for polling,
  settled-result handling, JSONL, and env parsing.
- `std/agent/chat::agent_chat_loop` plus `std/tui` and `std/io` for TTY-aware
  operator chat.

When adding a prompt or run artifact, keep deterministic facts separate from
model-authored text. Generated artifacts under `.harn-runs/` and `.harn/` stay
ignored and must not be committed.

## Release policy

`release_harn.harn` pins each live release at startup from `--at-sha`,
`HARN_RELEASE_PIN_SHA`, or `origin/<base>`. Hosted platform certification
publishes a write-once OID-qualified `release-certify/<pin>` branch at that
SHA and dispatches Windows/macOS nightlies against it, so a busy base cannot
race the exact-identity check and an implicit pin can certify while `main`
keeps merging. An explicit pin remains load-bearing for the rest of the
pipeline: it skips the base fast-forward and short-circuits the pre-tag drift
probe. Use it whenever the queue is active and the release must target a
specific commit rather than whatever `origin/<base>` becomes. The local
`release/vX.Y.Z` branch is parented at the pin and is never published; the
harness publishes a single OID-qualified immutable `release-attempt/...` ref
before creating the tag and PR. The pushed `vX.Y.Z` tag is the source for
publish/build workflows, so later base-branch commits cannot leak into the
published artifact.

If release assets already exist and an open `release/vX.Y.Z` PR remains,
post-publish fixup mode is paperwork only: recreate the branch on fresh base,
preserve the shipped release body from the tag, leave post-publish
`## Unreleased` entries in place, skip retagging, and refresh the PR.

Changed prepared content creates a new immutable attempt ref and PR; a retry
only resumes when the recorded ref still resolves to the exact prepared OID.

## Repo hygiene

This repo is public. Do not commit private repo details, customer data, secrets,
local paths from private investigations, or inside-baseball notes from private
Burin repositories.

Keep agent-facing docs short. Put durable reference material in `README.md` or
code comments near the relevant logic. Avoid time-sensitive comments that
compare against older implementations; explain the current invariant and why it
exists.

Documentation should read plainly: no emoji, no title-case section headings, no
marketing phrasing, no vague claims, and no filler endings. Use bullets only
where they make scanning easier.

Before opening a PR, rebase on the latest `origin/main`, run the checks above,
review your own diff for stale comments and duplicated abstractions, then push a
branch and enable auto-merge when CI is green.
