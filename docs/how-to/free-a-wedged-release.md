# Free a wedged release

Recover a release version that stalled, resume a certified candidate, and apply a post-publish fixup.

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
the candidate-archive run identity, and their verdicts. Once every candidate
lane is green, that archive receipt is also embedded unchanged in a signed,
write-once tag at
`harn-candidate-archive-certification/<candidate-oid>`. This durable tag is the
primary archive-run receipt after the certifying run's receipt artifact expires.
The archive gate authenticates it before selection, refuses a conflicting
operator receipt, and still requires the named archive artifact itself to be
unexpired. A missing record permits the initial archive build; an invalid or
unsigned record stops the gate. The release PR remains
impossible until the hosted/local lane, Linux size lane, archive lane, residual
audit, and durable binding are all green. The version-tag workflows build the
certified candidate source directly. A signed-selected candidate archive is
promotable only after the archive gate revalidates the exact source-qualified,
unexpired artifact and matching archive-policy content. `force_rebuild` remains
audited recovery only. `--local-audit` remains useful for read-only diagnosis but
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
  The tag selects the prepared and certified commit parented at this pin;
  subsequent main commits cannot change the published version. Honors
  `HARN_EXT_RELEASE_PIN_SHA` env var as a fallback.
- `--candidate-archive-receipt PATH` supplies the certification's
  `release_harn.candidate_archive.v1` receipt when this workspace did not write
  one, which is every hosted resume. The certifying release harness run
  publishes it with its artifacts under
  `release-harn/candidate-archive/<source commit>.json`. It is the only record
  that says which archive run the certification used, and it is needed because
  two archives of one candidate are not interchangeable: two runs of the same
  commit under byte-identical archive policy still produce different binaries.
  A receipt that binds another commit, repository or workflow is refused rather
  than read.
- `--candidate-archive-run-id N` asserts which archive run ships. It is checked
  against the receipt, never believed on its own: a pin that disagrees with the
  certified run is refused, and so is a pin with no receipt to check it
  against. The named run must also still be an unexpired archive of this exact
  candidate built under matching policy. Neither flag is needed on the ordinary
  path, where a candidate has one archive and the receipt names it.
- Hosted recovery requires `--candidate-archive-run-id N` together with
  `--candidate-archive-receipt-run-id M`, where `M` names the earlier hosted
  release run whose `release-run-M` artifact contains the typed receipt. The
  workflow restores the receipt, verifies that it names archive run `N`, and
  supplies its local path to `--candidate-archive-receipt`.
- `--consumer-proof-runs-json '{"owner/repository":123}'` resumes a consumer
  pre-tag gate from operator-selected exact GitHub Actions run IDs. The run
  must name the declared workflow, candidate version and SHA, workflow-dispatch
  event, and its own 40-character consumer source revision; current consumer
  `main` is not substituted and no newest-run guess is made. This flag is an
  override, not the ordinary path: a consumer proof run that fails only on jobs
  the consumer's own `main` already fails is attributed and excluded by the
  harness itself, with the derived attestation retained in the receipt. That
  derivation needs a completed failing `main` push of the same workflow to
  measure against, requires at least one candidate job to have succeeded, and
  excludes nothing when the consumer's history cannot be read. A repository
  value may instead be an attestation object with `run_id`, `proof_job_id`,
  `proof_step`, `excluded_job_ids`, `excluded_checks`, `baseline_run_id`,
  `baseline_job_id`, and `baseline_workflow_path`. That form accepts a failed
  candidate run only when the named proof job and step succeeded, every other
  non-success job is explicitly listed, and the exact baseline job is a failure
  from the named workflow's completed `main` push. All identities are retained
  in the release receipt.
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

## Certified-candidate resume

If `ship-pr` stops after publishing its immutable `release-attempt/...` ref but
before creating the PR, rerun the same foreground command. The harness fetches
the unique attempt for that version, restores its original certified pin, and
re-verifies the remote ref, signed commit, sole parent, cutoff ancestry, and
exact-SHA Linux size gate. A previous successful gate run is reused only when
its workflow, event, branch, head SHA, target job, and required size step all
match. The harness then creates the PR without rebuilding or re-signing the
candidate; the watcher tags that exact certified commit.

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

## Post-publish fixup mode

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
