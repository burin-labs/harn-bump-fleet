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
- `harness_self_review.harn`: a local meta-audit over recent `.harn-runs/`
  artifacts. It is not CI and should stay out of the main release/bump path.

Shared code belongs in `lib/*.harn`. Every shared module should have focused
coverage in `tests/*.harn`.

## Commands

Use the pinned Harn version from `.harn-version`.

```sh
harn install --locked
harn check $(git ls-files '*.harn')
harn fmt --check $(git ls-files '*.harn')
harn lint $(git ls-files '*.harn')
harn test tests/ --verbose
```

Use `harn fmt $(git ls-files '*.harn')` for Harn formatting fixes.

Common harness runs:

```sh
harn run bump_fleet.harn -- --dry-run
harn run bump_fleet.harn -- --only burin-labs/harn-cloud
harn run release_harn.harn
harn run release_harn.harn -- --mock --agent --mode ship-pr
harn run release_harn.harn -- --mode ship-pr --agent --yes-live-release
```

Harn does not auto-load `.env`; use `scripts/with_env.sh` when provider keys
are needed. On macOS, wrap long local runs with `scripts/harn_shielded.sh` if
another session may replace the `harn` binary while the process is running.

## Implementation rules

Keep GitHub side effects deterministic. GitHub writes go through `gh` or the
connector helper with `gh` fallback. Model output may summarize, audit, or
draft text, but deterministic code must validate or parse it before it affects
files, PRs, tags, dispatches, or merge settings.

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
`HARN_RELEASE_PIN_SHA`, or `origin/<base>`. The release branch is parented at
that SHA and is not rebased before push. The pushed `vX.Y.Z` tag is the source
for publish/build workflows, so later base-branch commits cannot leak into the
published artifact.

If release assets already exist and an open `release/vX.Y.Z` PR remains,
post-publish fixup mode is paperwork only: recreate the branch on fresh base,
preserve the shipped release body from the tag, leave post-publish
`## Unreleased` entries in place, skip retagging, and refresh the PR.

Use `--repin-latest` only before a release ships. It advances an open release
PR to fresh `origin/<base>`, reruns the full checks, deletes the stale remote
tag after the TOCTTOU guard passes, and pushes the new pin.

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
