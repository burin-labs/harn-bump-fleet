# Release Harn

Use this procedure only when a consumer needs a new Harn release. Keep one live
release owner. Preserve any older immutable attempt before starting another cut.

## Open the workflow-owned release

Use the repository-pinned runtime and the existing GitHub login:

```sh
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mode ship-pr --yes-live-release
```

The harness delegates to Harn's no-input `bump-release.yml` on `main`. Harn owns
version selection, preparation, the signed release commit, the release PR, and
its merge queue. The harness writes the accepted opener identity to
`.harn-runs/release-harn/workflow-handoffs/<opener-run-id>.json` and returns
pending. An accepted dispatch does not mean a release was produced.

Open the recorded run in GitHub. Record its canonical `Release vX.Y.Z` PR and
the `build-release-binaries.yml` run that certifies the actual merged source.
Use the run selected by Harn's promoter, not a run with a matching version name.
Do not select the prepared PR head or the promoter workflow's own head as the
archive source.

## Observe the certified files

Pass those explicit identities to the supported read-only launcher:

```sh
scripts/watch_harn_release.sh --receipt PATH --release-pr NUMBER --producer-run RUN_ID
```

The watcher retains the first PR and producer attempt under the existing
receipt-writer lease. It checks that the release merged on main, the selected
producer succeeded for that exact source, and its manifest identifies the same
run and attempt. It then compares the public tag target and downloaded bytes for
all five archives, `SHA256SUMS`, and `release-assets.json` against that manifest.
Missing or failed certification cannot produce a verified publication.

Stop and resume with the same receipt:

```sh
scripts/watch_harn_release.sh --receipt PATH --max-polls 1 --json
```

Exit 3 means pending; exit 2 means failed. JSON output carries named pending and
failing checks. Crate publication, the versioned container, the development bump,
and downstream convergence remain separate obligations. Complete their owning
publication and consumer checks before declaring the release finished.

The live watcher receives GitHub authentication and the permitted artifact/file
destinations. It receives no provider environment, signing roots, checkout write
roots, or git.push grant. It never dispatches recovery, creates a tag, arms a PR,
or chooses a replacement release. You do not need a local Harn source checkout
to observe the handoff. Live local preparation, hosted legacy imports,
tag recovery, and cache warming refuse instead of falling back to the old flow.

## Diagnose a failure

Keep the receipt, selected run attempt, failing names, and immutable source refs.
Repair the failed owning Harn workflow through its normal review and queue. Use
the [Harn release runbook](https://github.com/burin-labs/harn/blob/main/docs/src/maintainer-release.md)
for workflow-owned recovery. Do not manually tag the old prepared candidate or
restore the retired candidate-only dispatch inputs.

For an offline rehearsal of the historical control flow, use:

```sh
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mock --agent --mode ship-pr
```

The mock flow proves its fixture behavior. It supplies no current release,
signing, certification, publication, or downstream evidence.
