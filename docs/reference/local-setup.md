# Local setup

Configuration files, credential precedence, planner tuning, the macOS launcher, and the tools a run expects to find.

## Local config and API keys

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

## Planner + tool binder

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

## AMFI-shielded launcher (macOS)

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
