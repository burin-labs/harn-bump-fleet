# How a bump run works

The order a run executes in, the guarantees that let you rerun it, and the artifacts it leaves behind.

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
