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
- `sweep_release_refs.harn`: inventories historical local and remote release
  refs. It is dry-run-first and applies only exact, tag-backed deletions.
- `abandon_release_attempts.harn`: frees a version wedged by leftover
  `release-attempt/vX.Y.Z/` refs by renaming each unclaimed attempt into
  `release-failed/vX.Y.Z/<oid>-abandoned`. Dry-run-first, and it refuses when a
  tag, a published release, or an open PR still claims an attempt. Both modes
  hold the `release-owner` lease and refuse while a live release owns it.
- `harness_self_review.harn`: a local meta-audit over recent `.harn-runs/`
  artifacts. It is not CI and should stay out of the main release/bump path.
- `sync_agent_guidance.harn`: checks or applies the manifest-owned shared
  agent contract and `CLAUDE.md` projection without replacing local rules.
- `sync_package_ci.harn`: checks or applies package CI for repositories that
  delegate ownership in `fleet.toml`. `package_ci_ownership = "fleet"` owns the
  whole `ci.yml`; `"pin"` owns only the canonical package job's `uses:` line, for
  repositories whose CI is a superset of it and whose other jobs are their own.
- `sync_bump_workflows.harn`: checks or applies exact runtime-bump adapters for
  every repository that delegates bump workflow ownership in `fleet.toml`.

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
- `release_note_fold` / `release_notes`: candidate-tree folding, release notes,
  and fixup/drift state
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
scripts/install_harn.sh
.harn/bin/harn install --locked
scripts/harn-project.sh verify
scripts/harn-project.sh test
.harn/bin/harn test tests-risky/release_ref_cleanup_git_push.harn --approve-risky git.push --verbose
```

`scripts/harn-project.sh verify` includes tracked and non-ignored untracked Harn
sources with filename-safe argument handling. Use `scripts/harn-project.sh
format` for formatting fixes. CI passes `--tracked-only` to verify the exact
committed tree.

Common harness runs:

```sh
harn run --no-sandbox bump_fleet.harn -- --dry-run
harn run --no-sandbox bump_fleet.harn -- --only burin-labs/harn-cloud
harn run --no-sandbox release_harn.harn
harn run --no-sandbox release_harn.harn -- --mock --agent --mode ship-pr
harn run --no-sandbox release_harn.harn -- --mode ship-pr --agent --yes-live-release
harn run --no-sandbox watch_harn_release.harn -- --tag vX.Y.Z --yes-live-release
harn run --no-sandbox sync_agent_guidance.harn -- --check
harn run --no-sandbox sync_package_ci.harn -- --check
harn run --no-sandbox sync_bump_workflows.harn -- --check
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

An out-of-band harness that rewrites shared release refs must serialize on the
`release-owner` host lease, the same lane `release_harn` takes. Terminal
evidence — a tag, a published release, an open PR — cannot substitute for it:
a release that has not tagged yet has none of those, so its in-flight candidate
is indistinguishable from abandoned state. `abandon_release_attempts.harn`
holds the lane in both modes for exactly this reason.
`sweep_release_refs.harn` does not need it because every deletion it applies is
gated on positive proof that a published tag recovers the exact OID, which an
in-flight candidate can never satisfy. Adding a new mutation path means
deciding which of those two shapes it has, and saying so.

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
`HARN_EXT_RELEASE_PIN_SHA`, or `origin/<base>`. The local `release/vX.Y.Z` branch is
parented at that pin and is never published. Canonical ship mode materializes
and signs the versioned candidate, publishes one OID-qualified immutable
`release-attempt/...` ref, then certifies that prepared OID rather than the
pre-bump parent. Hosted Windows/macOS and local source proof runs concurrently
with the Linux release-size gate; residual generated-content proof follows the
join. A write-once `release-certify/<candidate-oid>` branch lets GitHub dispatch
the exact commit while `main` keeps merging. Any missing, stale, moved, or red
lane blocks the signed tag. An explicit startup pin remains load-bearing for
parent ancestry, base fast-forward suppression, and the pre-tag drift probe.
The pushed `vX.Y.Z` tag is the source for publish/build workflows, so later
base-branch commits cannot leak into the published artifact.

A pre-tag checkpoint supersede is a new candidate, not paperwork. If recovery
rebuilds that candidate on fresh base, the fresh base is part of the artifact:
fold its current `## Unreleased` body and every parseable fragment into the
candidate release section before certification. Only an already-tagged fixup
may preserve newer notes for the following release.

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

<!-- BEGIN HARN SHARED AGENT CONTRACT: managed by harn-bump-fleet -->

## Ecosystem working agreement

- Pursue the ambitious product outcome; make the seams boring with small typed
  interfaces, explicit invariants, and deterministic projections.
- Give each behavior one semantic owner. Generate or parity-test other surfaces
  instead of maintaining competing implementations.
- Work autonomously inside approved scope. Pause for destructive, production,
  high-spend, ambiguous, or authority-expanding actions—not routine reversible work.
- Treat stop, wait, stand down, and pivot as control events for long-lived work.
- Match evidence to the claim: exercise the canonical user path, state the
  falsifier, verify liveness and recovery, and record residual blind spots.
- "Ship" means landed on main with required deploy and post-merge checks complete.

<!-- END HARN SHARED AGENT CONTRACT -->
