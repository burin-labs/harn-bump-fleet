# harn-bump-fleet

[![Harn static checks](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml/badge.svg)](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml)

Local Harn-version bump orchestrator. `fleet.toml` is the typed owner of fleet
membership and reusable-workflow policy. The orchestrator resolves those
declared repositories under `~/projects`, rejects a missing checkout, wrong
remote, or missing dispatch adapter, and drives every `harn_bump = true`
repository to the latest published Harn release with auto-merge enabled in
parallel, idempotently, with a self-contained audit trail.

This is a Harn-native script (`bump_fleet.harn`): no Python glue, no shell
wrapper. It exists partly as a useful local tool, partly as a proof that
Harn the language is viable beyond LLM orchestration.

The companion `sync_agent_guidance.harn` workflow owns one small marked block
inside each fleet repository's `AGENTS.md` and projects `CLAUDE.md` directly to
that canonical file. It preserves every repository-specific rule outside the
markers.

```sh
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --check
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --dry-run
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --apply
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --only harn-cloud
```

## Repository scope

This repo is public for transparency and cheap GitHub Actions coverage, but
the tools are written for my own Burin Labs/Harn release operations. Keep
audits, logs, prompts, and examples suitable for a public repo: do not commit
private-repo details, customer data, secrets, or anything too inside baseball
from private Burin repositories. Generated run artifacts are intentionally
ignored under `.harn-runs/` and `.harn/`.

Harn sandboxes `harn run` by default. These local ops harnesses inspect
`~/projects`, local Git state, and authenticated GitHub connector state, so use
`scripts/with_env.sh harn run --no-sandbox` for real local release and bump
runs. The wrapper verifies the repo-pinned runtime before Harn parses the
program and loads the configured provider environment. Mock release runs can
stay sandboxed.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request. It
covers the pinned runtime setup, the two checks to run, the changelog fragment,
and the `[Area] Sentence case description` title convention. `AGENTS.md` names
which module owns which release stage.

## Usage

```sh
# Bump every dependent repo to the latest harn release.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn

# Pin to an explicit tag.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- vX.Y.Z

# Discover-only: never dispatches anything, useful before a real run.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --dry-run

# Run on one repo only.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --only burin-labs/harn-cloud

# Repair only manifest-admitted failed bump PRs in an isolated fleet root.
# The hosted workflow invokes this automatically after a terminal failure.
# By default every admitted manifest consumer is considered; use
# --max-repositories N for an explicitly narrower rehearsal. The Harn cost
# budget remains the global live-spend ceiling.
scripts/with_env.sh harn run --no-sandbox repair_fleet_convergence.harn -- \
  --fleet-root /absolute/path/to/materialized-fleet vX.Y.Z

# Check fleet-owned package CI adapters without writing them.
scripts/with_env.sh harn run --no-sandbox sync_package_ci.harn -- --check

# Check fleet-owned runtime-bump adapters without writing them.
scripts/with_env.sh harn run --no-sandbox sync_bump_workflows.harn -- --check

# Check the typed first-party connector secret registry against harn.toml.
scripts/with_env.sh harn run --no-sandbox sync_connector_secrets.harn -- --check

# Report every remote fleet-owned file or package pin that drifts from fleet.toml.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- --check

# Scope a check or repair to exact manifest-owned paths. Repeat the flag for
# several files; an unknown path fails before any pull request is changed.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- \
  --check --only burin-labs/burin-code \
  --only-path scripts/agent_shell_guard.harn \
  --only-path scripts/agent_shell_guard_policy.harn

# Propose the repair as one pull request per drifted repository. Pin-only CI
# keeps every repository-owned job and changes only the structurally selected
# package workflow and status-action references.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- --apply

# Inspect unsigned bot dependency PRs that are blocked by required signatures.
scripts/with_env.sh harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --prs 3704,3705

# Rewrite one selected in-repo bot PR head as a signed commit and re-check auto-merge.
scripts/with_env.sh harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --pr 3704 --live

# Verify a release prerequisite PR is actually merged before acting on it.
scripts/with_env.sh harn run --no-sandbox verify_prerequisite_pr.harn -- --repo burin-labs/harn --pr 4872 --expected-head <sha>

# Use a different local LLM for the summary.
HARN_BUMP_FLEET_MODEL=gpt-oss:120b \
HARN_BUMP_FLEET_PROVIDER=ollama \
  scripts/with_env.sh harn run --no-sandbox bump_fleet.harn
```

These operation harnesses inspect sibling checkouts under `~/projects`, run
local Git commands, and call the GitHub connector, so Harn's default run
sandbox must be disabled.

Before scheduled dispatch, `check_fleet_policy.harn` reads every declared
repository's default-branch workflows through the GitHub connector. It checks
the byte-exact package and runtime-bump adapters generated from `fleet.toml`,
verifies other byte-exact file projections, and verifies that each canonical
reusable-workflow pin still publishes the same bytes as the owner's current
default branch. A fleet whose consumers all agree on a stale canonical pin
therefore fails closed instead of silently treating internal consistency as
freshness. Public repositories may retain custom package validation and
runtime-bump commands as named fields. Private consumers instead own those
details in `.harn/fleet-projections.toml`, so the public manifest carries no
private path or command inventory.

The same manifest owns each first-party connector's required secret ids and
trust direction. `policy.connector_secret_schema` selects one generated
`[providers.setup].required_secrets` shape for all connector repositories.
Keep it on `legacy` while the released Harn runtime accepts string entries;
after a compatible release, one change to `direction-v1` projects the closed
`{ id, direction }` records everywhere. `sync_connector_secrets.harn` is
dry-run-first and changes no other manifest field.

`converge_fleet_projections.harn` is the repair for what that check reports. It
renders the same byte-exact projections, compares them against the same remote
default branches, and proposes the difference as one pull request per drifted
repository on an `automation/fleet-projections-<digest>` branch named for the
exact bytes it carries. Each run also retires the proposals it has moved past:
an open projection pull request on any other such branch is proposing bytes the
manifest no longer says, so it is closed with the reason rather than left to
conflict behind an auto-merge that can never fire. It repairs only
the three violations that describe bytes drifting from a projection; a typed
violation names a workflow the fleet does not render, so no correct content
exists to propose. The local `sync_*` harnesses remain the way to converge a
checkout you already have; this is how the fleet converges without one.
`--only-path` narrows that remote repair to exact target paths after `--only`
repository admission. It is repeatable and fails closed if any requested path
is not owned by the selected manifest slice, preventing task-scoped repairs
from absorbing unrelated projection drift.

Nothing in that path writes a default branch or merges anything itself. It does
arm auto-merge on each proposal, leased to the exact commit it just published,
so an appended commit fails closed instead of riding along. Every repository
still keeps its own gate: GitHub merges only once that repository's required
checks pass, and a red projection sits open exactly as before. What arming
removes is the person whose remaining job was to agree with a byte comparison
the loop had already made — and whose absence, for three days in August 2026,
left the whole fleet unable to bump. `--no-auto-merge` proposes without arming.

A repository that refuses arming — auto-merge switched off, or a gate the
fleet's App cannot satisfy — is reported as `auto_merge.state = "refused"` and
fails the run. A standing proposal older than three days is `overdue` and
fails the same way. A sweep that cannot list open proposals does too. Silence
here is the defect: a fleet that quietly stopped converging reads exactly like
a fleet with nothing to converge.

The scheduled `Converge Fleet Projections` workflow is the only place `--apply`
runs by default; the harness itself reports and exits unless asked to write.

### Signed bot PRs

`sign_bot_prs.harn` fixes a narrow merge-queue failure mode: an organization
ruleset requires signed commits, but a bot-authored dependency branch contains
unsigned commits. GitHub can show the PR as green while merge-queue admission
stays blocked by policy.

The helper is dry-run by default. It reads typed PR commit-signature and
merge-queue evidence through `harn-github-connector`, then prints whether each
selected PR can be rewritten. Live mode refuses queued PRs, missing head
branches/OIDs, and already-signed PRs.
It also refuses forks and non-bot authors unless the corresponding override is
passed. The volume of PRs this helper has to handle is set by how much
Dependabot coverage the fleet carries; see
[docs/dependabot-fleet-template.md](docs/dependabot-fleet-template.md) for the
canonical per-repo config and its grouping rules.
A live rewrite verifies the local checkout's origin matches `--repo`, uses a
fsmonitor-disabled temp worktree, and soft-resets the PR tree to `origin/main`,
leaving the index holding exactly the tree the PR proposes. That state is
published as one commit through `createCommitOnBranch`, which GitHub signs
server-side under the identity of the token already in hand. The rewrite then
waits for GitHub's pull request record to catch up to the publish, verifies the
confirmed head no longer has unsigned commits, and re-checks auto-merge. It does
not bypass CI.

Nothing here holds a signing key, and nothing here pushes: the mutation is the
write. That is what lets a workflow run this against its own blocked PR. The
branch is leased with `expected_branch_oid`, which means what
`git push --force-with-lease=<branch>:<oid>` meant before it — a branch that
moved, or that was deleted, refuses with `stale_head` and nothing is written.
The scratch worktree is always removed, and failing to remove it does not
retract a signature GitHub has already issued.

Common flags:

| Flag | Effect |
|---|---|
| `--repo owner/name` | Repository to inspect |
| `--pr N` / `--prs N,N` | Selected PR numbers |
| `--live` | Perform the rewrite; omitted means dry-run |
| `--checkout <path>` | Local checkout to use; defaults to `~/projects/<repo>` |
| `--allow-non-bot` | Permit a non-bot author |
| `--allow-fork` | Permit a cross-repository PR |
| `--no-auto-merge` | Skip the final auto-merge check |

### Interactive chat (postmortem + pre-release review)

Both harnesses drop into a TTY-aware chat loop after their pipeline
finishes. It auto-enables when stdin is a controlling terminal
(`/dev/tty` is openable) and auto-skips in CI / non-interactive shells.
The chat agent gets read + edit tools so it can investigate the run *and*
apply a fix to the harness or release artifacts mid-debrief if you ask.

```sh
# Disable chat even when at a TTY.
scripts/run_harn_release.sh --no-chat        # or `HARN_EXT_CHAT=0`

# Skip the pipeline; open the loop over a prior run.
scripts/run_harn_release.sh --chat-only                       # carousel
scripts/run_harn_release.sh --chat-only --chat-run <run-id>   # direct

# Change the start-typing timeout (default 60s).
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --chat-timeout-s 120
```

`release_harn.harn` also runs a **non-trivial classifier** before live
release side effects fire. When the CHANGELOG/PR body looks substantive
(breaking changes, new sections, >12 bullets, deterministic findings),
the pipeline pauses on a pager view and asks you to approve `[a]`,
abort `[q]`, or `[c]`hat first.

Slash commands inside the chat loop:

| Command | Description |
|---|---|
| `/help` | Print the command list |
| `/exit`, `/quit` | End the chat |
| `/cat <path>` | Print a file (resolved under the run dir or repo) |
| `/diff <path>` | `git diff` for a path, piped to the pager |
| `/runs` | List recent runs of this harness |
| `/load <run-id>` | Switch the chat to a different run (reseeds context) |
| `/save <path>` | Save the chat transcript so far |
| `/pager <path>` | Open a file in `$PAGER` (`less`) |

During the pre-release gate, the chat also accepts `/approve` and
`/abort` to resolve the decision and return to the main pipeline.

### Local config and API keys

The cloud-by-default planner/binder pair (see "Planner + tool binder" below)
needs provider API keys in env. Harn does not auto-load `.env`, so the
release launcher sources one or more local env files before starting Harn. Its
underlying `scripts/with_env.sh` seam also prepends the repo-local
`.harn/bin` directory when present, so `scripts/install_harn.sh` keeps the
harness on the version pinned in `.harn-version` instead of whatever `harn`
appears first on the ambient `PATH`:

```sh
# Sources ~/projects/burin-code/.env (override with HARN_EXT_BUMP_FLEET_ENV_FILE),
# then ./.env and ./.env.local from the repo root, then runs the harness.
scripts/install_harn.sh
scripts/run_harn_release.sh --mode ship-pr --agent --yes-live-release
scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox bump_fleet.harn -- --dry-run

# Verbose mode prints which files were sourced.
HARN_EXT_ENV_VERBOSE=1 scripts/run_harn_release.sh
```

Discovery order (later entries override earlier ones):

1. `$HARN_EXT_BUMP_FLEET_ENV_FILE` (default `~/projects/burin-code/.env`)
2. `$HARN_EXT_BUMP_FLEET_ENV_FILES` (colon-separated list)
3. `./.env` at the cwd
4. `./.env.local` at the cwd

Missing files are silently skipped. All `.env*` files are gitignored
locally; never commit secrets.

The release and watch launchers keep Harn's worktree sandbox active. They grant
only the selected Harn checkout, its dedicated sibling
`<repo>-release-workspaces` root, shared lease state, Harn/Cargo/sccache caches,
public signing configuration, process networking, and the existing `gh` login.
`--repo` changes both the harness target and the granted checkout; the two
cannot drift apart.

### Planner + tool binder

By default the harnesses now route their planning calls through
**OpenRouter `qwen/qwen3.6-35b-a3b`** (planner) with **Cerebras
GPT-OSS-120B** as a natural-language tool binder middleware (the binder
is the empirical best cell from
[burin-labs/harn#1814](https://github.com/burin-labs/harn/pull/1814),
+18pp lift on the PEAR-style tool-call accuracy harness). The cloud
planner shares the Qwen 3.6 35B A3B family the repo previously ran
locally (`qwen3.6:35b-a3b-coding-nvfp4`) so behavior stays consistent,
and costs $0.15/$1.00 per Mtok. This cloud cell is now the
**unconditional** default — local Ollama is *never* auto-selected
(it kept returning HTTP 500s and silently became the fallback whenever
`OPENROUTER_API_KEY` was missing from the process env). Source your keys
via `scripts/with_env.sh` so the planner can authenticate; to run against
local Ollama instead, opt in explicitly with `HARN_PLANNER_PROVIDER=ollama`
(or the per-role `HARN_<ROLE>_PROVIDER`).

The binder runs as a `compose_tool_callers` middleware layer on every
tool-using agent loop in the repo (release agent, recovery loop, harness
self-review, post-run + pre-release chat). It only fires when the
planner emits an optional `_nl_intent` field on a tool call; otherwise
it short-circuits with `audit.binder.status = "skipped"` at zero
latency cost.

Knobs (all `env_str`-style, all optional):

| Env var | Default | Effect |
|---|---|---|
| `OPENROUTER_API_KEY` | (none) | Authenticates the default OpenRouter cloud planner |
| `CEREBRAS_API_KEY` | (none) | Auto-enables binder |
| `HARN_EXT_BINDER` | `auto` | `0` to force off, `1` to force on |
| `HARN_BINDER_PROVIDER` / `_MODEL` | `cerebras` / `gpt-oss-120b` | Override binder route |
| `HARN_EXT_BINDER_TIMEOUT_MS` | `5000` | Binder hop wall-clock budget |
| `HARN_EXT_BINDER_MAX_TOKENS` | `1024` | Per [#1814 finding 3](https://github.com/burin-labs/harn/pull/1814) |
| `HARN_PLANNER_PROVIDER` / `_MODEL` | (auto) | Shared planner override |
| `HARN_RELEASE_PROVIDER` / `_MODEL` etc. | (auto) | Per-harness override (highest priority) |
| `HARN_EXT_RELEASE_COST_LIMIT_USD` | `1.00` | Per-run LLM spend ceiling for `release_harn` (`0` = uncapped) |
| `HARN_EXT_RELEASE_CARGO_TARGET_DIR` | user cache dir | Cargo target cache for live `release_harn` prepare/audit |
| `HARN_EXT_BUMP_FLEET_COST_LIMIT_USD` | `1.00` | Per-run LLM spend ceiling for `bump_fleet` (`0` = uncapped) |
| `HARN_EXT_FLEET_REPAIR_COST_LIMIT_USD` | `1.00` | Per-run ceiling for bounded downstream bump repair; hosted runs set `$0.25` |

The default release Cargo target is
`$XDG_CACHE_HOME/harn-bump-fleet/release-harn-target`, or
`$HOME/.cache/harn-bump-fleet/release-harn-target` when `XDG_CACHE_HOME` is
unset. Override it only when a release lane needs an isolated cache.

`scripts/run_harn_release.sh` prints a `planner` + `binder` line
at the top of every run summarizing the resolved route.

### AMFI-shielded launcher (macOS)

On macOS, AMFI sends SIGKILL to a running process if the executable file
on disk is replaced (a fresh `cargo install harn-cli` mid-run is enough).
Long fleet runs would otherwise need the manual
`cp ~/.cargo/bin/harn ~/.cargo/bin/harn2` workaround.

`scripts/harn_shielded.sh` resolves the source `harn` from `$HARN_BIN`, then
the repo-local `.harn/bin/harn`, then `PATH`, stages a copy under
`$XDG_CACHE_HOME/harn-shielded/harn` (default `~/Library/Caches/...`),
and execs that copy. Re-stages only when the source binary's size+mtime
changes, so warm runs cost ~50ms.

```sh
scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox bump_fleet.harn -- --dry-run
scripts/run_harn_release.sh --mode ship-pr
```

Drop-in for any `harn ...` invocation. CI environments don't need it
because they don't rebuild `harn` mid-run.

## Dependencies

- The Harn version pinned in `.harn-version`.
- Authenticated GitHub connector credentials. The connector supports explicit
  tokens and GitHub App credentials; local runs opt into the existing `gh auth`
  token as a fallback. Read-only diagnostic agent commands also use `gh`.
- Cloud planner API keys from `~/projects/burin-code/.env`, sourced via
  `scripts/with_env.sh`. The default route is OpenRouter
  `qwen/qwen3.6-35b-a3b` (needs `OPENROUTER_API_KEY`); the Cerebras binder
  auto-enables when `CEREBRAS_API_KEY` is present. This is the
  unconditional default for the end-of-run summary, the post-run chat
  loop, and every agent loop. Override per harness with
  `HARN_BUMP_FLEET_MODEL` / `HARN_BUMP_FLEET_PROVIDER` or
  `HARN_RELEASE_MODEL` / `HARN_RELEASE_PROVIDER`.

To run against a local Ollama model instead (opt-in only — it is never
auto-selected), set `HARN_PLANNER_PROVIDER=ollama` and pull the model:

```sh
ollama pull qwen3.6:35b-a3b-coding-nvfp4
HARN_PLANNER_PROVIDER=ollama scripts/run_harn_release.sh
```

## CI

Run `scripts/harn-project.sh verify` locally to check, lint, and format-check
tracked plus non-ignored untracked `*.harn` files. The same script handles paths
without shell word-splitting; use `scripts/harn-project.sh format` for fixes.
Use `scripts/harn-project.sh test` for the full local suite so source gates and
tests resolve the same repo-pinned binary. If that binary is absent or stale,
the wrapper installs the checksum-verified `.harn-version` release instead of
silently falling back to an ambient Harn. GitHub Actions passes `--tracked-only`
to verify the exact committed tree with the explicit public API types required
by `harn.toml`; its setup action installs the same exact release before invoking
Harn directly. Risky structured-Git contracts run separately with
`.harn/bin/harn test tests-risky/release_ref_cleanup_git_push.harn --approve-risky git.push`;
the Harn sandbox still blocks network egress. CI installs the
published `harn-cli` version pinned by `.harn-version` through Harn's
checksum-verifying setup action. `scripts/install_harn.sh` remains the local
developer bootstrap.

This repo also ships `.github/workflows/bump-harn.yml`, so future fleet runs
can update `harn-bump-fleet` itself through the same
`automation/bump-harn-runtime` PR flow as the connector repos. This repository
stores `.harn-version` as bare semver (`X.Y.Z`), the form written by Harn's
reusable bump workflow. Both readers normalize either spelling anyway —
`scripts/install_harn.sh` strips a leading `v` before building the tag, and
`lib/bump_pins.harn` runs the pin through `strip_v` — so historical `vX.Y.Z`
pins keep comparing equal.

## What it does, in order

1. **Discover** every directory under `~/projects/*harn*` and `~/projects/*burin*`
   that owns `.github/workflows/bump-harn.yml`. Worktrees are deduped via
   `git rev-parse --git-common-dir`.
2. **Resolve** the target Harn release through the connector's typed release
   contract. An explicit `vX.Y.Z` arg
   overrides.
3. **Wait for release readiness** on live runs. Before dispatching anything,
   the fleet waits for `harn-cli@X.Y.Z` to be visible on crates.io and for all
   expected macOS, Linux, and Windows release binary assets to exist on the
   GitHub release. Dry runs skip this wait.
4. **Run the run/session view compatibility gate** on live runs. Dry runs record
   this metadata as skipped so discovery stays cheap and cannot start a local
   Cargo build.
5. **Idempotency pre-check** per repo:
   - Read origin/main directly from GitHub. Local worktrees are only used for
     discovery and as an audit signal.
   - If origin/main's `.harn-version` (or `harn-vm = "..."` in `Cargo.toml`)
     already matches the target, status is `already_current` and no workflow
     is dispatched.
   - Record both the local checkout pin and the remote main pin. A stale local
     checkout no longer gets hidden behind the remote idempotency check; the
     audit calls out local checkout drift while still treating remote main as
     the source of truth for dispatch decisions.
   - If an open PR on `automation/bump-harn-runtime` has a head pin that
     already matches the target, ensure auto-merge is on and status is
     `pr_open_for_target`.
   - If that automation PR is stale, close it before redispatching so an old
     version bump cannot accidentally sit in the merge queue.
5. **Otherwise dispatch** `bump-harn.yml` with `version=<target>`, retain and
   poll the connector-resolved exact workflow run ID to completion, locate the
   PR the workflow pushed, verify its head pin matches the target, and call
   typed auto-merge under the observed PR-head lease. A successful workflow
   with no matching PR and no matching origin/main pin is a failed fleet
   outcome.
6. **Audit**: write `audit.json` and a rendered markdown report to
   `.harn-runs/bump-fleet/<run-id>/`. Includes a SHA3-256 hash of the JSON
   payload and a UUIDv7 run id for cross-referencing with Harn's own run
   record. The JSON includes raw `trace_spans` plus a compact
   `timing_summary` for Harn Cloud ingestion and local replay inspection.
7. **Summarize**: a read-only `summary_agent` against the local model produces a
   short bullet list of anomalies for the operator. The LLM is **never**
   allowed to drive a side-effect. If the local model returns anything other
   than plain markdown bullets after one repair attempt, the harness renders
   deterministic fallback bullets from status counts, dispatched repo count,
   failures, auto-merge failures, local checkout drift, and duration outliers
   instead of erasing the summary. The audit JSON keeps deterministic summary
   facts, model attempts, and the selected summary source separate.
8. **Clean up**: after a live run, if the local `harn-bump-fleet` checkout is
   clean, use `std/git` to fetch `origin`, switch back to `main`, and
   fast-forward it. Dirty local worktrees are left untouched and the skip is
   recorded in the audit.

## Idempotency guarantees

A second invocation against an unchanged fleet is essentially a no-op:
~6s of probes, zero workflow dispatches, zero PR mutations.

## Harn features used

- `pipeline main()` as entry point with exit-code-as-return-value semantics.
- `parallel settle … with { max_concurrent: 4 }` for bounded fan-out, with
  per-repo failure isolation via `Result.Err`.
- `std/command` command steps for release command execution, retries, tails,
  and artifact references; `shell()` / `shell_at()` remain for small discovery
  probes and mocked fixtures.
- `std/timing` spans for release, bump, command, verification, and agentic
  phases. Human-readable durations are derived from those spans, and machine
  artifacts keep the same trace data.
- `render(...)` against a `.harn.prompt` template + `[asset_roots]` alias
  for audit markdown, PR bodies, recovery prompts, and fixture readmes.
- `summary_agent` through Ollama for an on-machine summary. The default
  summary model is intentionally separate from the tool-driving release model
  so this read-only audit task can use a smaller model. Deterministic summary
  facts are always recorded so local-model formatting quirks cannot remove the
  useful audit summary.
- `sha3_256` + `uuid_v7` for cryptographically tagged audit identity.
- `regex_captures`, `json_parse`/`json_stringify`, `mkdir`, `file_exists`,
  `read_file`/`write_file` from the stdlib.
- `harn check`, `harn fmt`, `harn lint`, and focused `harn test` coverage as
  pre-commit gates. The scripts are structured to pass all checks with no
  warnings.

## Output

```text
~/projects/harn-bump-fleet/.harn-runs/bump-fleet/<run-id>/
├── audit.json    # machine-readable: every per-repo outcome, with
│                 # run/PR URLs, pre-pin, duration, auto-merge status,
│                 # trace_spans, and timing_summary
└── audit.md      # human-readable rendered report including LLM summary
```

Plus Harn's own VM-managed run record under `.harn-runs/<run-id>/` from
the host harn binary.

## Release Harn harness

`release_harn.harn` is the matching Harn-native harness for the
`~/projects/harn` `/release-harn` skill workflow. It does not publish
directly. The live flow prepares and certifies one `Release vX.Y.Z` PR. After
that exact PR squash-merges, the watcher proves its commit is on `origin/main`,
signs and pushes `vX.Y.Z` at that commit, and lets the tag-triggered
`publish-release` and `build-release-binaries` workflows ship from it. The tag
therefore names the commit that actually landed on main, not an orphaned
release-attempt commit.

The watcher creates the release tag with Git's configured signing key and
verifies its signature locally before pushing. A merge-identity, ancestry,
signing, or verification failure stops publication before the tag reaches the
remote. Existing tags are never moved.

Default mode dispatches a read-only audit through the hosted release workflow:

```sh
scripts/run_harn_release.sh
```

The hosted route gives the audit the same runner, checkout, credential, and
confinement setup as a live release. Use `--local-audit` only to diagnose local
source lanes; a local result does not certify hosted release readiness.

Useful mock runs:

```sh
# Fully mocked vX.Y.Z -> vX.Y.(Z+1) audit. No repo/GitHub writes.
scripts/run_harn_release.sh --mock

# Mocked agent/tool loop using Harn's mock LLM provider.
scripts/run_harn_release.sh --mock --agent

# Mock the full command sequence: prepare, commit, immutable publication, PR,
# and auto-merge. Still no repo/GitHub writes.
scripts/run_harn_release.sh --mock --agent --mode ship-pr
```

The mock release path runs on every pull request as the required
`Release harness integration` CI job, including under a poisoned operator
environment. It exercises the orchestrator's control flow against fixed
version fixtures, so it cannot reach any invariant that depends on the target
repo's real current version, tag, or changelog shape.

Live modes require the explicit guard flag. The checkout passed through
`--repo` is only the source Git database: the harness refreshes the exact
`origin/<base>` ref, freezes its pin, and creates a detached worktree under the
dedicated sibling `<repo>-release-workspaces` root (`release` for the leased
live lane or `release-<run-id>` for an isolated audit). It verifies
that creating the worktree did not change the source checkout's branch, HEAD,
index, or working tree, then routes analysis, agent tools, release-branch
creation, preparation, tagging, and publication through the isolated path.
Dirty files and arbitrary branches in the operator checkout remain untouched.

The release worktree uses the same external `HARN_EXT_RELEASE_CARGO_TARGET_DIR`
and exact-pin `HARN_BIN` path as before, so compiled artifacts remain warm
across runs without sharing mutable source or Cargo build-script scratch with
the operator checkout. Pre-tag recovery aligns only the isolated worktree to
the immutable candidate before its exact-HEAD warm and certification checks.
With `--agent`, the model must produce a ready-to-paste changelog block, so the
draft notes can be rewritten from local evidence instead of copied from commit
titles.

```sh
# The source checkout may be on any branch or dirty; release work is isolated.
# If needed, the harness drafts CHANGELOG.md for vX.Y.Z before prepare.
scripts/run_harn_release.sh --mode prepare --yes-live-release

# Same, then commit/rebase/push/open-or-reuse the PR and enable squash auto-merge.
scripts/run_harn_release.sh --mode ship-pr --agent --yes-live-release

# Resume the post-PR handoff through merged-main tagging and publication.
# Safe to stop and rerun.
scripts/watch_harn_release.sh --tag vX.Y.Z --yes-live-release

# Import one hosted release run's receipt, then watch it through the same path.
scripts/watch_harn_release.sh --tag vX.Y.Z --hosted-run RUN_ID --yes-live-release
```

### Running the release on hosted runners

`.github/workflows/hosted-release.yml` runs the same harness on hosted Linux
capacity, normally an eight-CPU Blacksmith runner. If that provider cannot
assign a runner, set the repository variable
`HARN_CI_DISABLE_BLACKSMITH_LINUX=true` and replay the dispatch receipt. The
replacement uses `ubuntu-latest` and declares the matching Harn runner tier;
unset or set the variable to `false` after Blacksmith recovers. Both this
repository and `burin-labs/harn` are public, so GitHub-hosted fallback minutes
cost nothing. The Rust compilation that dominates a local release moves off
the operator machine. On a measured v0.10.53 run,
`prepare` and `release-cli-aot` accounted for 17 of the 24 minutes before the
certification gate; the model agent accounted for 0.3 minutes, so the LLM is
not the expensive part of a release.

The canonical launcher dispatches every non-mock audit to this workflow. On
macOS it also dispatches an authorized live `prepare` or `ship-pr` invocation
before compilation.
Candidate certification intentionally exercises nested OS sandboxes, which
Seatbelt cannot apply beneath Harn's default-deny outer sandbox. Read-only
`--local-audit` diagnosis and mocks remain local. The handoff accepts only the
workflow's typed inputs and fails before dispatch when a local-only release
flag cannot be represented. It writes an atomic
`.harn-runs/hosted-release-dispatch-<run-id>.json` receipt containing the full
non-secret input tuple and exact Actions run identity.

Dispatch it from the Actions tab or through the typed launcher:

```sh
scripts/dispatch_hosted_release.sh --bump patch --mode ship-pr \
  --at-sha <40-character-origin-main-sha> --expect-pr <number>
```

If a queued or environment-waiting run must be replaced, replay its receipt.
The replacement command does not accept release input flags: it dispatches the
recorded tuple, rechecks the old run, and records both run IDs. If the old run
started or changed identity, the command cancels the new run and refuses the
replacement.

```sh
scripts/dispatch_hosted_release.sh \
  --replace-receipt .harn-runs/hosted-release-dispatch-<run-id>.json
```

`mode: audit` is read-only. `mode: prepare` builds and certifies the candidate.
`mode: ship-pr` opens the release PR and hands its receipt to the watcher. The
watcher waits for merge, tags the exact merged-main commit, and monitors
publication, so a release needs no local step.

With `update_fleet: true`, the hosted run also follows the complete bounded
repository-update chain, not just its first Actions run. Each continuation has
the same release run ID in its display name. The first incomplete round leases
an exact-OID `harn-update-chain/<release-run-id>` branch; later rounds dispatch
only from that immutable controller, and the terminal round releases it under
the same lease. Installing the requested Harn release remains a separate,
explicit startup step. Success means every repository proves the target pin on
`main` with green checks; an independently opened PR is accepted when its
merged commit supplies that same immutable proof. The terminal artifact
`hosted-release-and-update-cost-receipt.json` combines the release and every
update round. It reports a numeric model cost only when every contributing Harn
receipt is exact and fully priced; missing or unpriced usage fails closed.

Tags are signed by a dedicated release bot key that exists only in the
workflow's `release` environment. The maintainer's personal signing key is
deliberately not reachable from any runner. Harn owns the public trust root at
`.github/release-bot-allowed-signers`, so signing and artifact publication use
one contract. From a directory containing the Harn checkout:

```sh
git -c gpg.ssh.allowedSignersFile=harn/.github/release-bot-allowed-signers \
  verify-tag v0.10.53
```

The tagger is a GitHub App bot, and an App bot cannot hold SSH signing keys on
GitHub, so the web UI marks these tags unverified even though the signature is
valid. Restoring that badge would mean signing as a machine user account rather
than the App bot.

The release commit is a different problem, and the bot key is the wrong answer
to it. `burin-labs/harn`'s `main` ruleset requires signatures, and GitHub counts
only a signature it can attribute to the committer's account — so a release
commit signed with the bot key is real, checkable, and still refused, leaving
the release PR blocked with every check green. The hosted workflow therefore
passes `--github-signed-commit`, which has the harness create that commit
through `createCommitOnBranch` under the App token it already holds. GitHub
signs it server-side, so it needs no key at all, and the gate that follows asks
GitHub for its verdict on the exact commit rather than asking whether this
machine can check a signature — the same question the ruleset asks.

The commit lands on a scratch `release-candidate/vX.Y.Z` branch first, because
the immutable attempt ref is named for the object id GitHub is about to choose.
The local branch is reset onto that commit before any gate reads it, and the
scratch branch is deleted, so every proof below — parent, size, certification,
tag — sees the exact commit that will be published.

A release run from a machine whose signing key GitHub already accepts does not
pass the flag and is unchanged. That route adds failure modes the local one does
not have: `createCommitOnBranch` cannot carry a new executable file or a file
mode change, and fails closed rather than publishing a different tree. It should
become the only route once a hosted release has shipped through it.

Both repositories are public, so the workflow assumes any secret it can read is
worth attacking, and layers the controls accordingly:

- `workflow_dispatch` is the only trigger. GitHub restricts manual dispatch to
  actors with write access, so no fork or pull request can start the run.
- The job binds to the `release` environment, whose protection rules require a
  reviewer and allow only protected branches. The job pauses before any secret
  is materialized until that reviewer approves, so even a collaborator with
  write access cannot spend the API key unattended.
- Top-level `permissions` is read-only. Write access to `burin-labs/harn` comes
  from a short-lived GitHub App token scoped to that one repository.
- Free-text inputs reach `run:` blocks through the environment rather than
  string interpolation, and `at_sha` is rejected unless it is a full 40-hex SHA.
- Every third-party action is pinned by commit SHA.

The `release` environment holds `OPENROUTER_API_KEY` and `CEREBRAS_API_KEY`.
The planner model is already well under a $2/Mtok budget — see
`lib/llm_defaults` — so a release costs cents of inference rather than dollars.

`ship-pr` returns as soon as the tag, branch, PR, auto-merge handoff, and typed
watch receipt are durable. It does not hold the operator process open while
GitHub compiles release binaries. The receipt lives at
`.harn-runs/release-harn/watches/vX.Y.Z.json` and records the pin, PR, observed
workflow run IDs, recovery dispatch state, finalized-asset state, and the exact
warm-cache run identity and outcome.
`watch_harn_release.harn` validates that receipt at the JSON boundary, rewrites
it through rename-into-place after every snapshot, and may be restarted without
repeating release preparation, tag creation, binary recovery dispatch, or an
accepted warm-cache run.

Pass `--hosted-run RUN_ID` after a hosted `ship-pr` run. The watcher downloads
that run's artifact, validates the same typed receipt, and publishes it to the
normal local path before monitoring starts. A valid local receipt always wins,
so rerunning the command cannot replace newer watch state with the older hosted
handoff.

One cancellation-safe host lease makes the full
read-transition-write loop, recovery dispatch, queue restoration, and ref
cleanup single-writer; a second local watcher fails before reading the receipt.
A normal invocation continues after release health is proven until the release
PR merges. `--warm-cache` additionally dispatches the five-target hosted warm
and continues until that matrix completes or fails. The
watcher prints semantic workflow/job transitions plus a five-minute heartbeat,
including the active job step and receipt path, so a slow platform build remains
visibly live without repeating identical state every 30 seconds. After terminal
hosted proof, it discovers version-matched content-addressed `release-attempt/`
and `release-certify/` refs, deletes each through an exact target lease, and
persists an idempotent `.ref-cleanup.json` receipt. It then sweeps historical
attempt, certification, failed-recovery, and local `release/v*` refs through
the same exact-OID policy. Signed tag identity plus a finalized hosted release,
the published crate, and the complete required asset set are required;
worktree-held, unique, moved, unpublished, and malformed refs remain with
explicit reasons in a durable
`.ref-sweep.json` receipt. The standalone `sweep_release_refs.harn` entrypoint
is dry-run-first; `--apply --yes-live-release` is required to mutate refs. A
moved current ref blocks cleanup; `--no-ref-cleanup` explicitly retains all
recovery refs. The warm dispatch runs on
`main`; its receipt stores the source SHA observed by
GitHub, which may differ from the release commit after squash merge or later
mainline changes. Hitting `--max-polls` returns a durable pending receipt;
rerunning the command resumes the exact run ID. An all-skipped warm is recorded
as suppressed and retried only after overlapping release/recovery work clears.
Post-publish warming is opt-in because it repeats the full hosted target matrix;
use it only when measured release latency justifies that incremental spend. A
release is healthy only when crates.io and all five archives plus `SHA256SUMS` and
`release-assets.json` are present; a cache is warm only after the exact five-job
release matrix completes successfully.

## Freeing a wedged release version

Because the sweep only retires refs a verified signed tag can recover, an
unclaimed pre-tag candidate stays on origin forever. Once two or more of them
exist for one version, that version can no longer be cut. `--at-sha` matches a
candidate's frozen *source pin*, so a pin that is not already one of them
selects zero attempts and fails, while a pin that is one of them selects
exactly one and then routes to `resume_pre_tag`. No route mints a fresh
candidate at current `main`, and the resumed tree cannot contain a fix that
landed after it froze — so a gate the fix was meant to satisfy keeps failing.

`abandon_release_attempts.harn` is the escape:

```sh
scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox abandon_release_attempts.harn -- --version 0.10.53
scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox abandon_release_attempts.harn -- --version 0.10.53 --attempt-oid <sha>
scripts/with_env.sh scripts/harn_shielded.sh run --no-sandbox --approve-risky git.push abandon_release_attempts.harn -- --version 0.10.53 --apply --yes-live-release
```

A tag claims only the exact OID it recovers. When a release tags one candidate
and leaves others behind, those losers are orphans: no tag will ever recover
them, so the sweep retains them forever and this harness is the only thing that
retires them. It reports them as `orphaned_by_shipped_tag`.

It renames each unclaimed attempt to `release-failed/vX.Y.Z/<oid>-abandoned`
rather than deleting it, so the commit stays on origin and the sweep still
inventories it through the normal proof path. GitHub's create-only ref claim
creates the archive only while its destination is absent; an existing archive
is adopted only when it points at the same exact OID. The source is deleted
afterward through an exact-OID Git lease. An interruption or source race can
therefore leave both refs, but never loses a commit or overwrites an archive,
and the receipt marks that recoverable partial state explicitly. An attempt
claimed by a tag, a published release, or an open PR is retained, and a live
claim blocks whole-version mode. `--attempt-oid` narrows the authority to one
exact attempt, so a stale unclaimed sibling can be retired while the attempt
behind the active release PR remains untouched. A tag-recovered attempt is
terminal and the sweep retires it, so it does not block the orphans beside it.
The checkout's `origin` fetch URL and sole push URL must both resolve to the
exact `--slug`; the harness refuses before either release lane is acquired when
those identities differ or either side cannot be read unambiguously.

Every claim above is terminal, and a release that has not tagged yet has none
of them: its in-flight candidate looks exactly like an unclaimed orphan. So
both modes take the `release-owner` host lease for the whole run and refuse
outright while a live release holds it. The dry run serializes too — its plan is
what an operator acts on, and a plan sampled mid-cut is what makes archiving a
live candidate look safe. The residual blind spot is a release driven from
another machine or from CI, where there is no local lease to observe.

Afterwards, delete the local `release/vX.Y.Z` branch and any worktree holding
it. Release preflight compares that branch against `origin/main` only, so an
archived candidate still reads as un-pushed work and blocks the fresh cut.

Before either live mode mutates its isolated worktree, it refreshes
`origin/<base>` and proves the latest remote release tag has been folded back:
both the workspace version and the top versioned CHANGELOG section must match
the tag. A mismatch fails closed and names the matching release PR or immutable
attempt ref when one is available. Recover by recreating the fold content from
the published tag on fresh `origin/<base>`, merging that PR, and rerunning the
release; do not start the next version from an orphaned fold.

After the development-version cutover, the workspace instead names the exact
next patch as `X.Y.Z-dev`. Release analysis accepts that state only when
`vX.Y.(Z-1)` is the latest tag, and the patch release strips `-dev`; a stale
development target or a request to reinterpret it as another bump fails closed.

Every non-mock run first freezes the release parent (`--at-sha` /
`HARN_EXT_RELEASE_PIN_SHA` / `origin/<base>` HEAD) and materializes that exact commit
in a detached managed worktree. Audit, version, changelog, diff, generated
artifact, and agent-review inputs all use that one root; the receipt records the
requested ref, resolved commit, source checkout, and analyzed root. One typed
`release-workspace` host lease owns the reusable checkout for its complete
lifecycle. An audit takes it only when free and retains the checkout only after
proving it clean; a contending audit uses a per-run checkout and removes that
checkout on every terminal path. A live release waits for an earlier audit and
then inherits the warm checkout instead of silently recompiling, while new
audits yield as soon as `release-owner` records the live claimant. None of these
paths changes the caller's branch, index, or files. Canonical `ship-pr` uses the
same materialization boundary to produce and sign the versioned candidate,
proves that the frozen parent is its sole parent, and publishes the write-once
`release-attempt/...` ref. Because GitHub `workflow_dispatch` cannot target a
bare SHA, certification publishes a second write-once
`release-certify/<candidate-oid>` branch at that exact prepared commit.

The controller dispatches `windows-nightly.yml` and `macos-nightly.yml` against
that branch through the typed GitHub Actions connector and retains the exact
run IDs returned by GitHub. Those hosted runs execute concurrently with Harn's
contract-owned local source lanes, the exact-candidate Linux release-size
workflow, and the full five-target `candidate_only` archive matrix on
`build-release-binaries.yml`. Nightly test binaries are not release archives;
only the archive lane's signed/notarized receipts may be promoted. No
workflow-run listing or timestamp correlation is used. Dispatching on a moving
base branch is deliberately avoided: a busy `main` would otherwise race the
identity check between source capture and run creation. Standalone `prepare`
mode retains the composed prepare audit because it does not continue into
immutable publication and tag gates.

Each hosted proof must preserve the expected workflow path, event, source SHA,
run attempt, run URL, complete jobs page, and one successful required job.
Missing, duplicate, stale, malformed, queued, cancelled, or failed evidence
rejects the release. A failed lane requests cancellation of both exact hosted
runs. The harness then rereads the certification branch. If that write-once ref
moved — which means it was force-updated, not that `main` advanced — all
evidence is discarded and a fresh certification attempt is required, whether or
not the operator passed `--at-sha`. A certification branch that cannot be
reread at all also fails closed. The write-once dispatch ref is what lets a
release certify against a `main` that is merging continuously, without freezing
the queue; `--at-sha` still skips the base fast-forward and the pre-tag drift
probe when the release must target a specific commit.

The closed hosted/local receipt is immutable at
`.harn-runs/release-harn/<run-id>/platform-certification-receipt.json`. It
records both hosted proofs, the local source lanes, wall-clock timings and
critical path, and the SHA-256 of the exact-candidate Harn CLI. The joined
candidate receipt also preserves the independent Linux size-run identity,
the candidate-archive run identity, and their verdicts. The release PR remains
impossible until the hosted/local lane, Linux size lane, archive lane, and
residual audit are all green. After merge, the tag-derived workflows build the
merged-main source directly; the pre-merge candidate archive is certification
evidence, not a publishable substitute. `force_rebuild` remains audited
recovery only. `--local-audit` remains useful for read-only diagnosis but
cannot bypass hosted certification for live preparation.

Options:

- `--repo PATH` points at a different Harn checkout; default is
  `~/projects/harn`.
- `--base BRANCH` changes the release PR base; default is `main`.
- `--bump patch|minor|major` controls the expected next version; default is
  `patch`.
- `--at-sha SHA` overrides the auto-resolved pin (`origin/<base>` HEAD
  at run start). The local release branch is parented at this commit, an
  OID-qualified immutable `release-attempt/...` ref is published from the
  prepared head, and `latest_tag..<pin>` bounds every changelog/audit walk.
  The eventual tag still selects the PR's merged-main commit; this option pins
  preparation evidence, not a divergent publish commit. Honors
  `HARN_EXT_RELEASE_PIN_SHA` env var as a fallback.
- `--agent` gives the configured planner a bounded read/search/run tool
  surface for release readiness review. Defaults come from
  `HARN_RELEASE_*`, then shared planner env, then the OpenRouter cloud cell in
  `lib/llm_defaults`. Agent runs persist the raw result, trace, and Harn
  `llm_transcript.jsonl` sidecar under the run directory.
- `--provider PROVIDER` can pin the LLM provider for `--agent`; otherwise the
  same default cascade is used.

In `ship-pr`, the harness first scans only open PRs for an existing matching
release/version-bump PR with auto-merge already enabled. If it finds one, it
checks/shepherds that PR instead of repeating the release work; closed PRs are
ignored so empirical test PRs can be closed safely. Otherwise, the PR body is
generated from a fresh post-prepare snapshot instead of the initial audit text.
If the PR already exists on the release branch, the harness refreshes its
title/body before enabling auto-merge.

Before any live prepare or ship side effect, the harness also audits the most
recent published GitHub release description against the release notes recovered
from the immutable tag's pin-time changelog. Exact matches and a previously
applied deterministic correction are no-ops. Drift is repaired with one
connector-owned body-only edit guarded by the observed release id, tag object,
and peeled tag target; tags, assets, and package contents remain immutable.
Audit mode reports the plan without editing. Every run records the closed state
and before/after SHA-256 digests in `release-body-integrity.json`; body-only
drift never creates a source commit or PR, while independent changelog drift
continues through the paperwork-PR path below.

### Certified-candidate resume

If `ship-pr` stops after publishing its immutable `release-attempt/...` ref but
before creating the PR, rerun the same foreground command. The harness fetches
the unique attempt for that version, restores its original certified pin, and
re-verifies the remote ref, signed commit, sole parent, cutoff ancestry, and
exact-SHA Linux size gate. A previous successful gate run is reused only when
its workflow, event, branch, head SHA, target job, and required size step all
match. The harness then creates the PR without rebuilding or re-signing the
candidate; the watcher tags only its later merged-main commit.

If an explicit pin makes that checkpoint ineligible for direct resume, the
harness supersedes it with a newly certified candidate on fresh base. That
candidate includes the fresh-base source, so its note scope does too: the
harness folds current `## Unreleased` content and every parseable
`changelog.d` fragment into the versioned section and removes the consumed
fragments. This differs from the already-tagged paperwork path below, where the
artifact is frozen and later notes must remain unreleased.

Run recovery directly in a terminal or through a supervisor configured for one
attempt. Do not use `launchctl submit` as a one-shot wrapper: submitted jobs can
be respawned after exit. The release owner guard rejects concurrent attempts,
but a respawning launcher still wastes API quota and obscures the first failure.

### Post-publish fixup mode

If a live `--mode ship-pr` run starts and the harness detects:

- the required GitHub release assets for `v<next_version>`, and
- an open `release/v<next_version>` PR on `<base>`,

it switches into **post-publish fixup mode** automatically. This is recovery
for a historical or interrupted release whose immutable artifact already
shipped while its source PR remains open. The open PR is paperwork that lands
the Cargo.toml/CHANGELOG bump on `<base>`. In fixup mode the harness:

- Skips the audit and the publish dry-run (the merge-queue CI of the PR
  re-runs the same gates).
- Force-recreates the release branch on top of fresh `origin/<base>` so any
  conflicts caused by other PRs landing after the original publish are
  dropped. The branch ends up with the version bump as its single new
  commit on top of current `<base>`.
- Runs Harn's canonical metadata preparation on fresh `<base>` before
  cherry-picking the original release branch's prepare commit(s)
  (`git cherry-pick --no-commit --strategy-option=ours <shas>`). This makes
  newly-added workspace crates and sibling dependencies participate in the
  recovered version bump; the old immutable attempt cannot know about them.
  CHANGELOG.md is reset to fresh-`<base>` and overwritten by the deterministic
  smart-subtract writer so cherry-pick conflict resolution stays moot.
- Reads the originally-shipped `## v<next_version>` section from
  `git show v<next_version>:CHANGELOG.md` and **injects it verbatim**
  above the next-older version heading via
  `changelog_inject_existing_release_section`. **`## Unreleased` is
  preserved as-is.** Entries that landed in `## Unreleased` after the
  original publish describe behavior that isn't in the shipped binary
  and belong in the NEXT release. Folding them into v<next_version>
  would mislabel the changelog. The harness leaves them where they
  are. (If a particular entry actually belongs in the shipped version,
  the operator must manually move it from Unreleased to v<next_version>
  before merge; `--agent` flags candidates.)
- **Skips the tag step entirely.** Re-pushing `v<next_version>` would
  either re-fire `publish-release.yml` against an already-shipped version
  (queueing behind itself) or, if the harness were to advance the tag,
  diverge crates.io from the git artifact. The shipped tag is left
  untouched.
- Refreshes the open PR body with a clearly-labeled
  "Post-publish fixup PR" callout that explains the artifact is already
  shipped and the tag will not move.
- With `--agent`, runs a fixup-specific audit prompt instead of the
  standard release prompt. The model is told the artifact has already
  shipped and asked to verify the inject (flag any `## Unreleased`
  entries that should actually be in the shipped version, or anything
  in v<next_version> that doesn't match the tag), not to author
  release notes. No `BEGIN_DRAFT_CHANGELOG` block is expected or
  accepted.

Deleting the GitHub tag, closing the release PR, or removing an immutable
attempt ref never authorizes re-cutting a version that crates.io already
accepted. The harness probes the registry independently; if `harn-vm` (and a
cross-check crate) already expose that version, it refuses a fresh or
superseded candidate and requires recovery of the packaged source OID from
`.cargo_vcs_info.json`. Post-publish paperwork can still proceed from that
immutable source when GitHub assets or refs were lost. Only a version that
never reached the registry may be prepared again after those GitHub signals
are cleared.

Changed prepared content publishes a fresh immutable attempt ref and opens a
new PR; the prior attempt stays inspectable and is never force-updated.
Side-effecting failures are preserved in the run report; with `--agent`, the failed command, stdout/stderr,
classification, and execution transcript are fed back through a recovery
`agent_loop` sidecar with its own JSONL transcript under `recovery/`. After the
full release audit and generated-content checks pass, the canonical release
branch push runs with hooks enabled. GitHub CI, the merge queue, and the
tag-triggered publish/build workflows remain the authoritative gates. A push
that fails only because the pre-push hook exceeded its wall-clock budget after
tests were already green is classified as such, and the recovery advice is
`git push --no-verify`: the hook has nothing left to prove and the harness
already recorded the evidence.

After a successful live `ship-pr`, the harness removes the isolated worktree
only after proving it is clean. Failed runs, standalone `prepare`, and any
unexpectedly dirty workspace preserve the exact path in events and the audit
receipt for inspection or recovery. Cleanup never switches, resets, stashes,
or fast-forwards the source checkout.

The local LLM summary path uses `std/llm/handlers.with_retry` rather than the
deprecated `llm_retries` option. The release audit handoff likewise avoids the
deprecated `post_turn_callback.llm_options` patch and carries next-turn tool
changes through `next_options`.

Reports are written to:

```text
.harn-runs/release-harn/<run-id>/
├── run-events.jsonl
├── release-audit.json
├── release-audit.md
└── crystallization-input/
    ├── manifest.json
    ├── release-run.json
    ├── deterministic-events.jsonl
    ├── agent-events.jsonl
    ├── tool-observations.jsonl
    └── README.md
```

`release-audit.json` carries the same `trace_spans` and `timing_summary`
fields as bump-fleet audits, so release command, verification, and agent spans
can be inspected without scraping terminal output.

The `crystallization-input/` directory is a self-contained fixture for the
Harn crystallization importer tracked in
[burin-labs/harn#1146](https://github.com/burin-labs/harn/issues/1146). It
keeps deterministic release facts separate from model-authored audit/recovery
text, and preserves command observations with stdout/stderr so failed pushes or
hooks can be replayed offline without reading sibling run artifacts.

For live runs, `run-events.jsonl` is append-only and safe to tail while the
harness is still running. Long command output is captured by `std/command`; the
step records include `command_id` / `output_path` references that can be read
with the command artifact readers or the release artifact tools during recovery.

The script intentionally keeps the agent advisory. Deterministic checks and
the repo's own `scripts/release_ship.sh` / `scripts/release_gate.sh` own the
release mechanics.
