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
HARN_BUMP_FLEET_MODEL=local:qwen3.6:35b-a3b-coding-nvfp4 \
  harn run bump_fleet.harn
```

## Dependencies

- `harn` v0.7.x.
- `gh` CLI, authenticated — the script never embeds tokens, just shells out.
- A local Ollama or llama.cpp model for the end-of-run summary; defaults to
  `local:gemma4:26b`. Override via `HARN_BUMP_FLEET_MODEL`.

## CI

GitHub Actions runs `harn check`, `harn fmt --check`, and `harn lint` across
all tracked `*.harn` files. CI installs the pinned prebuilt Harn binary from
`.harn-version` to avoid compiling Harn from source on every run.

## What it does, in order

1. **Discover** every directory under `~/projects/*harn*` and `~/projects/*burin*`
   that owns `.github/workflows/bump-harn.yml`. Worktrees are deduped via
   `git rev-parse --git-common-dir`.
2. **Resolve** the target Harn release. Defaults to
   `gh api repos/burin-labs/harn/releases/latest`; an explicit `vX.Y.Z` arg
   overrides.
3. **Idempotency pre-check** per repo (no side effects):
   - If origin/main's `.harn-version` (or `harn-vm = "..."` in `Cargo.toml`)
     already matches the target, status is `already_current` and no workflow
     is dispatched.
   - If an open PR on `automation/bump-harn-runtime` already targets the
     target version, ensure auto-merge is on and status is `pr_already_set`.
4. **Otherwise dispatch** `bump-harn.yml` with `-F version=<target>`, poll
   the resulting workflow run to completion, locate the PR the workflow
   pushed, and idempotently call `gh pr merge --auto --squash` on it.
5. **Audit**: write `audit.json` and a rendered markdown report to
   `.harn-runs/bump-fleet/<run-id>/`. Includes a SHA3-256 hash of the JSON
   payload and a UUIDv7 run id for cross-referencing with Harn's own run
   record.
6. **Summarize**: a single read-only `llm_call` against the local model
   produces a short bullet list of anomalies for the operator. The LLM is
   **never** allowed to drive a side-effect — the audit is finalized first.

## Idempotency guarantees

A second invocation against an unchanged fleet is essentially a no-op:
~6s of probes, zero workflow dispatches, zero PR mutations.

## Harn features used

- `pipeline main()` as entry point with exit-code-as-return-value semantics.
- `parallel settle … with { max_concurrent: 4 }` for bounded fan-out, with
  per-repo failure isolation via `Result.Err`.
- `shell()` / `shell_at()` for every external interaction (no embedded
  HTTP).
- `render(...)` against a `.harn.prompt` template + `[asset_roots]` alias
  for the audit markdown.
- `llm_call` with `model: "local:..."` routing through Ollama for an
  on-machine, deterministic summary.
- `sha3_256` + `uuid_v7` for cryptographically tagged audit identity.
- `regex_captures`, `json_parse`/`json_stringify`, `mkdir`, `file_exists`,
  `read_file`/`write_file` from the stdlib.
- `harn check`, `harn fmt`, and `harn lint` as pre-commit gates — the
  script is structured to pass all three with no warnings.

## Output

```
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
enable auto-merge, then let the `publish-release` and
`build-release-binaries` workflows ship after the PR lands.

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
- `--agent` gives a local model a bounded read/search/run tool surface for
  release readiness review. It defaults to `HARN_RELEASE_MODEL` or
  `local:gemma4:26b`. Agent runs persist the raw result, trace, and Harn
  `llm_transcript.jsonl` sidecar under the run directory.
- `--provider PROVIDER` can pin the LLM provider for `--agent`; default is
  `HARN_RELEASE_PROVIDER` or `auto`.
- `--skip-audit` and `--skip-dry-run` pass through to
  `scripts/release_ship.sh --prepare`.

In `ship-pr`, the PR body is generated from a fresh post-prepare snapshot
instead of the initial audit text. If the PR already exists, the harness
refreshes its title/body before enabling auto-merge. Side-effecting failures are
preserved in the run report; with `--agent`, the failed command, stdout/stderr,
classification, and execution transcript are fed back through a recovery
`agent_loop` sidecar with its own JSONL transcript under `recovery/`. The only
automatic bypass is the documented pre-push case where the hook output reports
green tests and a wall-clock budget timeout; that retry uses
`git push --no-verify` and records both attempts.

Reports are written to:

```text
.harn-runs/release-harn/<run-id>/
├── release-audit.json
└── release-audit.md
```

The script intentionally keeps the agent advisory. Deterministic checks and
the repo's own `scripts/release_ship.sh` / `scripts/release_gate.sh` own the
release mechanics.
