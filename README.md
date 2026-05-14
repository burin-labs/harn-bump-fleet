# harn-bump-fleet

[![Harn static checks](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml/badge.svg)](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml)

Local Harn-version bump orchestrator. Auto-discovers every repo under
`~/projects/{*harn*,*burin*}` that ships a `.github/workflows/bump-harn.yml`
and drives them all to the latest published Harn release with auto-merge
enabled — in parallel, idempotently, with a self-contained audit trail.

This is a Harn-native script (`bump_fleet.harn`) — no Python glue, no shell
wrapper. It exists partly as a useful local tool, partly as a proof that
Harn the language is viable beyond LLM orchestration.

## Repository scope

This repo is public for transparency and cheap GitHub Actions coverage, but
the tools are written for my own Burin Labs/Harn release operations. Keep
audits, logs, prompts, and examples suitable for a public repo: do not commit
private-repo details, customer data, secrets, or anything too inside baseball
from private Burin repositories. Generated run artifacts are intentionally
ignored under `.harn-runs/` and `.harn/`.

## Usage

```sh
# Bump every dependent repo to the latest harn release.
harn run bump_fleet.harn

# Pin to an explicit tag.
harn run bump_fleet.harn -- v0.7.52

# Discover-only — never dispatches anything, useful before a real run.
harn run bump_fleet.harn -- --dry-run

# Run on one repo only.
harn run bump_fleet.harn -- --only burin-labs/harn-cloud

# Use a different local LLM for the summary.
HARN_BUMP_FLEET_MODEL=gpt-oss:120b \
HARN_BUMP_FLEET_PROVIDER=ollama \
  harn run bump_fleet.harn
```

### Interactive chat (postmortem + pre-release review)

Both harnesses drop into a TTY-aware chat loop after their pipeline
finishes. It auto-enables when stdin is a controlling terminal
(`/dev/tty` is openable) and auto-skips in CI / non-interactive shells.
The chat agent gets read + edit tools so it can investigate the run *and*
apply a fix to the harness or release artifacts mid-debrief if you ask.

```sh
# Disable chat even when at a TTY.
harn run release_harn.harn -- --no-chat        # or `HARN_CHAT=0`

# Skip the pipeline; open the loop over a prior run.
harn run release_harn.harn -- --chat-only                       # carousel
harn run release_harn.harn -- --chat-only --chat-run <run-id>   # direct

# Change the start-typing timeout (default 60s).
harn run bump_fleet.harn -- --chat-timeout-s 120
```

`release_harn.harn` also runs a **non-trivial classifier** before live
release side effects fire — when the CHANGELOG/PR body looks substantive
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

### AMFI-shielded launcher (macOS)

On macOS, AMFI sends SIGKILL to a running process if the executable file
on disk is replaced (a fresh `cargo install harn-cli` mid-run is enough).
Long fleet runs would otherwise need the manual
`cp ~/.cargo/bin/harn ~/.cargo/bin/harn2` workaround.

`scripts/harn_shielded.sh` resolves the source `harn` on `PATH` (or
`$HARN_BIN`), stages a copy under
`$XDG_CACHE_HOME/harn-shielded/harn` (default `~/Library/Caches/...`),
and execs that copy. Re-stages only when the source binary's size+mtime
changes, so warm runs cost ~50ms.

```sh
scripts/harn_shielded.sh run bump_fleet.harn -- --dry-run
scripts/harn_shielded.sh run release_harn.harn -- --mode ship-pr
```

Drop-in for any `harn ...` invocation. CI environments don't need it
because they don't rebuild `harn` mid-run.

## Dependencies

- `harn` v0.8.x.
- `gh` CLI, authenticated — the script never embeds tokens, just shells out.
- A local Ollama model for the end-of-run summary and the post-run chat
  loop; defaults to `qwen3.6:35b-a3b-coding-nvfp4` via Harn's built-in
  `ollama` provider. This matches `release_harn.harn` so both harnesses
  share one tool-capable model. Override per-harness with
  `HARN_BUMP_FLEET_MODEL` / `HARN_BUMP_FLEET_PROVIDER` or
  `HARN_RELEASE_MODEL` / `HARN_RELEASE_PROVIDER`.

Recommended local Ollama model:

```sh
ollama pull qwen3.6:35b-a3b-coding-nvfp4
```

Normal invocations do not need LLM environment variables when Ollama is running
on its default `http://localhost:11434` endpoint.

## CI

GitHub Actions runs `harn check`, `harn fmt --check`, and `harn lint` across
all tracked `*.harn` files, then runs `harn test tests/` when local tests are
present. CI installs the pinned published `harn-cli` crate version from
`.harn-version` through `scripts/install_harn.sh`.

This repo also ships `.github/workflows/bump-harn.yml`, so future fleet runs
can update `harn-bump-fleet` itself through the same
`automation/bump-harn-runtime` PR flow as the connector repos. This repository
stores `.harn-version` as the release tag (`vX.Y.Z`) while the installer and
fleet auditor normalize both `vX.Y.Z` and `X.Y.Z` pins when comparing targets.

## What it does, in order

1. **Discover** every directory under `~/projects/*harn*` and `~/projects/*burin*`
   that owns `.github/workflows/bump-harn.yml`. Worktrees are deduped via
   `git rev-parse --git-common-dir`.
2. **Resolve** the target Harn release. Defaults to
   `gh api repos/burin-labs/harn/releases/latest`; an explicit `vX.Y.Z` arg
   overrides.
3. **Wait for release readiness** on live runs. Before dispatching anything,
   the fleet waits for `harn-cli@X.Y.Z` to be visible on crates.io and for the
   Linux release binary asset to exist on the GitHub release. Dry runs skip
   this wait.
4. **Idempotency pre-check** per repo:
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
5. **Otherwise dispatch** `bump-harn.yml` with `-F version=<target>`, poll
   the resulting workflow run to completion, locate the PR the workflow
   pushed, verify its head pin matches the target, and idempotently call
   `gh pr merge --auto --squash` on it. A successful workflow with no matching
   PR and no matching origin/main pin is a failed fleet outcome.
6. **Audit**: write `audit.json` and a rendered markdown report to
   `.harn-runs/bump-fleet/<run-id>/`. Includes a SHA3-256 hash of the JSON
   payload and a UUIDv7 run id for cross-referencing with Harn's own run
   record.
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
  pre-commit gates — the scripts are structured to pass all checks with no
  warnings.

## Output

```text
~/projects/harn-bump-fleet/.harn-runs/bump-fleet/<run-id>/
├── audit.json    # machine-readable: every per-repo outcome, with
│                 # run/PR URLs, pre-pin, duration, auto-merge status
└── audit.md      # human-readable rendered report including LLM summary
```

Plus Harn's own VM-managed run record under `.harn-runs/<run-id>/` from
the host harn binary.

## Release Harn Harness

`release_harn.harn` is the matching Harn-native harness for the
`~/projects/harn` `/release-harn` skill workflow. It does not publish
directly. The live flow mirrors the skill: prepare one `Release vX.Y.Z` PR,
push `vX.Y.Z` at the pinned commit, enable auto-merge, then let the
`publish-release` and `build-release-binaries` workflows ship from the
tag. **Pin model:** the release branch is parented at `origin/<base>`
HEAD captured at run start (or whatever `--at-sha` resolves to), and is
NOT rebased before push. The pushed tag is the source of truth for what
ships, so any commits that land on `<base>` between PR-open and merge
cannot leak into the published artifact.

Default mode is read-only audit:

```sh
harn run release_harn.harn
```

Useful rehearsals:

```sh
# Fully mocked v0.7.52 -> v0.7.53 audit. No repo/GitHub writes.
harn run release_harn.harn -- --mock

# Mocked agent/tool loop using Harn's mock LLM provider.
harn run release_harn.harn -- --mock --agent

# Mock the full command sequence: prepare, commit, rebase, push, PR,
# and auto-merge. Still no repo/GitHub writes.
harn run release_harn.harn -- --mock --agent --mode ship-pr
```

Live modes require the explicit guard flag. The harness now normalizes the
release branch before running the target repo's release script: if it starts
from `main` or another branch, it stashes dirty tracked/untracked files when
needed, fetches/syncs the base branch, switches or creates `release/vX.Y.Z`,
restores the stashed release content there, and inserts a draft `## vX.Y.Z`
CHANGELOG section from the post-tag delta before handing off to
`scripts/release_ship.sh`. With `--agent`, the model must produce a
ready-to-paste changelog block, so the draft notes can be rewritten from local
evidence instead of copied from commit titles.

```sh
# Starts from main, an existing release branch, or another branch.
# If needed, the harness drafts CHANGELOG.md for vX.Y.Z before prepare.
harn run release_harn.harn -- --mode prepare --yes-live-release

# Same, then commit/rebase/push/open-or-reuse the PR and enable squash auto-merge.
harn run release_harn.harn -- --mode ship-pr --agent --yes-live-release
```

Options:

- `--repo PATH` points at a different Harn checkout; default is
  `~/projects/harn`.
- `--base BRANCH` changes the release PR base; default is `main`.
- `--bump patch|minor|major` controls the expected next version; default is
  `patch`.
- `--at-sha SHA` overrides the auto-resolved pin (`origin/<base>` HEAD
  at run start). The release branch is parented at this commit, the
  tag is pushed pointing here, and `latest_tag..<pin>` bounds every
  changelog/audit walk. Use to ship an older known-good commit while
  newer commits sit on the base. Honors `HARN_RELEASE_PIN_SHA` env var
  as a fallback.
- `--repin-latest` advances an existing open `release/v$next` PR's pin
  to current `origin/<base>` HEAD so commits that landed during the PR
  window fold into the same release rather than splitting into a future
  `v$next+1`. Requires `--mode ship-pr --yes-live-release`; refuses if
  the `v$next` release already shipped (crates.io is immutable). Runs
  the full audit + dry-run + bump, deletes the stale tag on origin, and
  re-pushes at the new pin. TOCTTOU re-checks the release/tag state one
  final time immediately before resetting the release branch.
- `--agent` gives a local model a bounded read/search/run tool surface for
  release readiness review. It defaults to `HARN_RELEASE_MODEL` or
  `qwen3.6:35b-a3b-coding-nvfp4` via Harn's built-in `ollama` provider. Agent
  runs persist the raw result, trace, and Harn `llm_transcript.jsonl` sidecar
  under the run directory.
- `--provider PROVIDER` can pin the LLM provider for `--agent`; default is
  `HARN_RELEASE_PROVIDER` or `ollama`.

In `ship-pr`, the harness first scans only open PRs for an existing matching
release/version-bump PR with auto-merge already enabled. If it finds one, it
checks/shepherds that PR instead of repeating the release work; closed PRs are
ignored so empirical test PRs can be closed safely. Otherwise, the PR body is
generated from a fresh post-prepare snapshot instead of the initial audit text.
If the PR already exists on the release branch, the harness refreshes its
title/body before enabling auto-merge.

### Post-publish fixup mode

If a live `--mode ship-pr` run starts and the harness detects:

- a published GitHub release for `v<next_version>` (i.e.
  `gh release view v<next_version>` returns the tag name), and
- an open `release/v<next_version>` PR on `<base>`,

it switches into **post-publish fixup mode** automatically. The release
artifact has already shipped from the originally-pushed tag — the open PR is
paperwork that exists to land the Cargo.toml/CHANGELOG bump on `<base>`. In
fixup mode the harness:

- Skips the audit and the publish dry-run (the merge-queue CI of the PR
  re-runs the same gates).
- Force-recreates the release branch on top of fresh `origin/<base>` so any
  conflicts caused by other PRs landing after the original publish are
  dropped — the branch ends up with the version bump as its single new
  commit on top of current `<base>`.
- Cherry-picks the original release branch's prepare commit(s) onto fresh
  `<base>` (`git cherry-pick --no-commit --strategy-option=ours <shas>`)
  instead of re-running `./scripts/release_ship.sh --prepare`. The
  prepare-script rerun is byte-identical to the cherry-picked Cargo.toml
  workspace bumps modulo CHANGELOG, but costs ~110s of generator reruns
  and pre-commit `cargo check`; cherry-pick is ~seconds. CHANGELOG.md is
  reset to fresh-`<base>` and overwritten by the deterministic
  smart-subtract writer so cherry-pick conflict resolution stays moot.
- Reads the originally-shipped `## v<next_version>` section from
  `git show v<next_version>:CHANGELOG.md` and **injects it verbatim**
  above the next-older version heading via
  `changelog_inject_existing_release_section`. **`## Unreleased` is
  preserved as-is.** Entries that landed in `## Unreleased` after the
  original publish describe behavior that isn't in the shipped binary
  and belong in the NEXT release — folding them into v<next_version>
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
  standard release prompt — the model is told the artifact has already
  shipped and asked to verify the inject (flag any `## Unreleased`
  entries that should actually be in the shipped version, or anything
  in v<next_version> that doesn't match the tag), not to author
  release notes. No `BEGIN_DRAFT_CHANGELOG` block is expected or
  accepted.

To bypass auto-detection (e.g. to advance the pin and re-tag because the
original publish failed before the GitHub release was created), close the
open release PR or delete the tag manually before rerunning. Detection
requires both signals (release artifact + open PR) so it cannot misfire
on a tag that exists without a corresponding shipped artifact.

To advance the pin on an open release PR that has NOT yet shipped (so the
release artifact does not yet exist on crates.io), use `--repin-latest`
instead — it is the opt-in inverse of fixup mode that folds post-pin
commits into the same `v$next` rather than splitting them into a future
release. See the flag description above. Side-effecting failures are preserved in
the run report; with `--agent`, the failed command, stdout/stderr,
classification, and execution transcript are fed back through a recovery
`agent_loop` sidecar with its own JSONL transcript under `recovery/`. The only
automatic bypass is the documented pre-push case where the hook output reports
green tests and a wall-clock budget timeout; that retry uses
`git push --no-verify` and records both attempts.

After a successful live `ship-pr`, the harness performs the same conservative
`std/git` checkout cleanup in the target Harn repo: if the release checkout is
clean, it fetches `origin`, switches to the base branch, and fast-forwards it.
Dirty worktrees are left in place and recorded as skipped cleanup, so failed or
manual recovery runs still preserve local evidence.

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
