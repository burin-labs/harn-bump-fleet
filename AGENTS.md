# AGENTS.md

## Repo shape

This is a Harn-only operations repo. There is no Python or shell glue in the
harnesses themselves.

The entry points are:

- `bump_fleet.harn`: finds local `~/projects/{*harn*,*burin*}` repos with
  `.github/workflows/bump-harn.yml`, dispatches Harn runtime bump workflows,
  polls them, and enables auto-merge on the resulting PRs.
- `release_harn.harn`: mirrors the human `/release-harn` flow for
  `~/projects/harn`. The launcher dispatches its default read-only audit to the
  same hosted workflow as a live release. `--local-audit` is diagnosis only.
  Live prepare/ship-pr requires `--yes-live-release`.
- `watch_harn_release.harn`: resumes the post-PR handoff from the typed receipt
  written by `release_harn`. It merges the release pull request itself under the
  pull request's exact head lease once every commit that landed since
  certification is proved green on main, runs the release-only lanes on the
  merged commit, signs and pushes the merged-main tag, then monitors publication
  without repeating preparation. `--tag-stranded-main <sha>` recovers a release
  whose bump merged without a tag; `--unfold-merged-bump <sha>` opens the revert
  for a bump that merged and must not be published.
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
  whole `ci.yml`. `"pin"` owns only the canonical package job's `uses:` line.
  Use `"pin"` for a repository whose CI is a superset of that job, and whose
  other jobs are its own.
- `sync_bump_workflows.harn`: checks or applies exact runtime-bump adapters for
  every repository that delegates bump workflow ownership in `fleet.toml`.
- `sync_connector_secrets.harn`: checks or applies the manifest-owned
  `[providers.setup].required_secrets` projection for every first-party
  connector. `policy.connector_secret_schema` keeps the output compatible with
  the released Harn manifest schema until the fleet can move as one.
- `converge_fleet_projections.harn`: the remote counterpart to the `sync_*`
  harnesses. It reads every fleet-owned projection from its target's default
  branch and proposes the repair as a pull request, so drift converges without a
  machine holding all twenty-six checkouts. Pin-only package CI is derived from
  current default-branch bytes and preserves repository-owned jobs. Dry-run
  first; `--apply` writes.
  `--apply` also arms auto-merge, leased to the commit it published, so each
  repair lands once that repository's own checks pass. `--no-auto-merge` holds
  arming; it never merges anything itself.

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
- `release_ship_certify`: cutoff and exact-candidate certification gates
- `release_ship_pr`: PR publication and watch-receipt handoff
- `release_main_tag`: merged-main verification, signed-tag publication, and
  write-once receipt binding
- `release_preflight`: interactive flags, planner/fleet/sccache checks, and
  build-lock lifecycle

Do not put stage policy back in the entrypoint or add a second implementation
behind a compatibility helper. `check_source_length.harn` enforces a 1,500-line
ceiling for every maintained handwritten source file.

Every pull request this repository opens gets its title from
`lib/pr_title_convention.harn`, never from a literal at the call site.
`burin-labs/harn` runs a required title gate that refuses a subject without a
leading `[Area]` from its own area list, and a bot pull request is not exempt.
`check_pr_title_convention.harn` refuses a registered title that gate would
reject, and refuses a pull-request call site the module does not name, so a new
opener cannot ship an unowned title.

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
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --dry-run
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --only burin-labs/harn-cloud
scripts/run_harn_release.sh
scripts/run_harn_release.sh --mock --agent --mode ship-pr
scripts/run_harn_release.sh --mode ship-pr --agent --yes-live-release
scripts/watch_harn_release.sh --tag vX.Y.Z --yes-live-release
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --check
scripts/with_env.sh harn run --no-sandbox sync_package_ci.harn -- --check
scripts/with_env.sh harn run --no-sandbox sync_bump_workflows.harn -- --check
scripts/with_env.sh harn run --no-sandbox sync_connector_secrets.harn -- --check
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- --check
```

Harn does not auto-load `.env`; use `scripts/with_env.sh` when provider keys
are needed. On macOS, wrap long local runs with `scripts/harn_shielded.sh` if
another session may replace the `harn` binary while the process is running.
Release and watch runs use `scripts/run_harn_release.sh` and
`scripts/watch_harn_release.sh`. Those launchers retain Harn's worktree sandbox
and grant the selected Harn checkout, its dedicated sibling release-workspace
root, shared leases, toolchain caches, network, and the existing `gh` login at
one audited boundary. Other fleet operations
still need `--no-sandbox` until they have an equivalent typed root inventory.

Run `scripts/install_harn.sh` after a `.harn-version` repin. By default it
installs the pinned CLI into this repo's ignored `.harn/bin`.
`scripts/with_env.sh` and `scripts/harn_shielded.sh` prefer that binary over a
stale global `harn` on `PATH`.

Use the release/watch launchers for their entrypoints and
`scripts/with_env.sh harn ...` for other documented harness invocations. They
install and select the repo-pinned runtime before Harn parses the program and
load the provider environment without putting secrets on the command line.
Direct ambient `harn` invocations are not a supported release path. Hosted and
local releases are alternative owners of the same lane, not parallel fallbacks:
do not start one while the other is active. Run only one live release watcher;
the watcher host lease refuses a second local receipt writer. Always start that
watcher through `scripts/watch_harn_release.sh`; it selects and shields the
repo-pinned runtime and supplies the exact `git.push` operator grant required by
terminal leased-ref cleanup.

## Implementation rules

Keep GitHub side effects deterministic. Production GitHub reads and writes go
through typed connector contracts, and every head-sensitive mutation carries
the observed PR-head lease. `gh` is limited to read-only diagnostic agent
allowlists and explicit manual-recovery instructions. Model output may
summarize, audit, or draft text. Deterministic code must validate or parse that
output before it affects files, PRs, tags, dispatches, or merge settings.

An out-of-band harness that rewrites shared release refs must serialize on the
`release-owner` host lease, the same lane `release_harn` takes. Terminal
evidence — a tag, a published release, an open PR — cannot substitute for it.
A release that has not tagged yet has none of those. Its in-flight candidate is
therefore indistinguishable from abandoned state.
`abandon_release_attempts.harn` holds the lane in both modes for exactly this
reason.

`sweep_release_refs.harn` does not need the lease. Every deletion it applies is
gated on positive proof that a published tag recovers the exact OID, and an
in-flight candidate can never satisfy that. Adding a new mutation path means
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
- `std/agent/loop::agent_loop` for each model turn. Fleet's
  `lib/interactive_agent_chat.harn` owns TTY input, slash commands, and
  presentation; do not rebuild an orchestration plane around it.

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
lane blocks the release PR. An explicit startup pin remains load-bearing for
parent ancestry, base fast-forward suppression, and the pre-merge drift probe.
The release pull request opens unarmed, and the merge is the release's own act
rather than GitHub's. The shipped tree is the certified tree plus commits that
passed main's own required checks, verified at merge time and recorded in the
receipt. The watcher reads the branch's required contexts from its rulesets,
resolves every commit that landed since certification against them, and merges
under the pull request's exact head lease. Before tagging, the watcher also
verifies that the squash commit's first parent is the exact main commit the gate
observed, so a later commit to an already-recorded path cannot cross the lease
through path containment. A drifted commit carrying a red or
unreported required check stops the release with nothing merged, so main keeps
its development version and a fresh cut stays admissible. Green drift merges
whatever it touched: the lanes only a release runs take about thirty-four
minutes against a branch that moves every nineteen, so gating the merge on them
is the same freeze by a slower route.

Those lanes run once on the merged main commit instead, before the tag, because
the tag is the publication act and an unpublished bump is a revertible commit.
The lane set is computed from workflow triggers rather than a maintained list: a
workflow the branch already runs on push, pull request, or merge group proves
nothing extra. A merged tree that is already the certified one skips them by a
named verdict rather than by falling through. If a lane fails, the watcher opens
the revert pull request itself, restoring the development version and the folded
changelog fragments, and reports a deferral naming the drifted commits and the
check that stopped it. After the exact PR squash-merges and those lanes pass,
the watcher verifies the merge commit on `origin/main`, signs and pushes
`vX.Y.Z` at that commit, and binds the receipt to it once. The tag gate accepts
a merged tree that differs from the certified one only where the recorded drift
accounts for it, and refuses anything else. Publish/build workflows derive from the immutable
tag; no candidate archive is promoted as the release artifact.

A release whose bump merged without a tag is recovered by
`recover-release-publication.yml` in `tag-stranded-main` mode, not by a fresh
cut the release preflight refuses. That mode tags the stranded merge commit
only when its tree is the certified one, or differs from it only in paths
certification does not depend on, and refuses otherwise.

The opposite recovery is `unfold-merged-bump`, for a bump that merged and must
not be published. It opens the revert that returns main to its development
version and restores the folded changelog fragments, and refuses once the tag is
public, because reverting a commit a tag names does not unpublish the tag. The
release opens that revert itself when the post-merge lanes fail; the mode exists
for a watch that died between the merge and the verdict.

A pre-tag checkpoint supersede is a new candidate, not paperwork. If recovery
rebuilds that candidate on fresh base, the fresh base is part of the artifact.
Fold its current `## Unreleased` body and every parseable fragment into the
candidate release section before certification. Only an already-tagged fixup
may preserve newer notes for the following release.

If release assets already exist and an open `release/vX.Y.Z` PR remains,
post-publish fixup mode is paperwork only. It does the following:

- recreates the branch on fresh base;
- preserves the shipped release body from the tag;
- leaves post-publish `## Unreleased` entries in place;
- skips retagging, and refreshes the PR.

Changed prepared content creates a new immutable attempt ref and PR. A retry
resumes only when the recorded ref still resolves to the exact prepared OID.

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

Before opening a PR, rebase on the latest `origin/main` and run the checks
above. Review your own diff for stale comments and duplicated abstractions.
Then push a branch, and enable auto-merge when CI is green.

## Pull requests

Title every pull request `[Area] Sentence case description`. Capitalize the
first word of the description and proper nouns only, and leave the trailing
period off.

`Area` is one of these, chosen from this repository's directory map:

| Area | Covers |
| --- | --- |
| `Release` | `release_*.harn`, `release_harn.harn`, the watchers, and publication proof |
| `Fleet` | `fleet.toml` membership and policy, dispatch, and repair |
| `Bump` | Runtime bump orchestration, `.harn-version` pins, and bump adapters |
| `Projections` | Fleet-owned file projections, drift checks, and convergence |
| `CI` | This repository's own workflows and required checks |
| `Scripts` | Launchers and wrappers under `scripts/` |
| `Docs` | `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, and `docs/` |
| `Tests` | `tests/` and `tests-risky/` coverage |

Pick the area that owns the behavior you changed, not the file you touched most.
A change to `lib/release_ship_pr.harn` is `[Release]` even though it lives under
`lib/`. If two areas fit, the pull request is probably two pull requests.

Keep the description to 3-5 sentences: what changed, why, the one risk, and how
you verified it. Do not list test commands. `.github/pull_request_template.md`
carries a worked example.

The same words are the `area/*` labels in `.github/labels.yml`, so a title and a
label agree.

Use `Closes #N` only when the pull request lands every enumerated sub-ask in
that issue. A partial resolution uses `Partial: #N items: 1, 3` or `Refs #N`;
adding an item suffix after `Closes #N` does not stop GitHub from closing the
whole issue. Use `Single-ask: #N` only when the issue has no enumerated
sub-asks and the pull request resolves it completely.

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
