# Release Harn

Drive a Harn release through the harness, locally or on hosted runners.

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

# Resume the post-PR handoff through certified-candidate tagging and publication.
# Safe to stop and rerun.
scripts/watch_harn_release.sh --tag vX.Y.Z --yes-live-release

# Import one hosted release run's receipt, then watch it through the same path.
scripts/watch_harn_release.sh --tag vX.Y.Z --hosted-run RUN_ID --yes-live-release
```

## Running the release on hosted runners

If publication succeeded but the remaining work stopped, see
[Resume a published release](resume-a-published-release.md).
That path selects an exact tag and retains the original release-chain journal.

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
watcher tags the immutable certified candidate, arms the release PR, and monitors
publication, so a release needs no local step.

With `update_fleet: true`, the hosted run also follows the complete bounded
repository-update chain, not just its first Actions run. Each continuation has
the same release run ID in its display name. The first incomplete round leases
an exact-OID `harn-update-chain/<release-run-id>` branch; later rounds dispatch
only from that immutable controller, and the terminal round releases it under
the same lease. Installing the requested Harn release remains a separate,
explicit startup step. A round that dies before it can run that release leaves
the lease held; the scheduled `Reap held convergence chain leases` workflow runs
`reap_chain_refs.harn` and clears only the leases whose every owning run reached
a terminal conclusion more than an hour ago. A chain with a live run, an
unreadable run list, or no resolvable run is reported and left held, and the
receipt distinguishes reading zero leases from failing to read the remote.
Success means every repository proves the target pin on
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
