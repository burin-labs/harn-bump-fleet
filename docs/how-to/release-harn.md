# Release Harn

Drive a Harn release through the harness.

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

Useful mock runs:

```sh
# Fully mocked vX.Y.Z -> vX.Y.(Z+1) audit. No repo/GitHub writes.
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mock

# Mocked agent/tool loop using Harn's mock LLM provider.
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mock --agent

# Mock the full command sequence: prepare, commit, immutable publication, PR,
# and auto-merge. Still no repo/GitHub writes.
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mock --agent --mode ship-pr
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
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mode prepare --yes-live-release

# Same, then commit/rebase/push/open-or-reuse the PR and enable squash auto-merge.
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mode ship-pr --agent --yes-live-release

# Resume the post-PR handoff through certified-candidate tagging and publication.
# Safe to stop and rerun.
scripts/watch_harn_release.sh --tag vX.Y.Z --yes-live-release

# Import one hosted release run's receipt, then watch it through the same path.
scripts/watch_harn_release.sh --tag vX.Y.Z --hosted-run RUN_ID --yes-live-release
```

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
