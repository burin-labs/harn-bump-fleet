# Resume a published release

Use this procedure when a signed Harn release is published but its baseline,
workflow promotion, or repository updates remain incomplete. Keep the exact tag,
original hosted run ID, watch receipt, and release-chain journal together.

From the `harn-bump-fleet` checkout, resume the selected release:

```sh
scripts/with_env.sh harn run --no-sandbox release_chain.harn -- \
  --resume-published --tag v0.10.125 \
  --receipt .harn-runs/release-harn/watches/v0.10.125.json \
  --state-root .harn-runs --chain-id 123456789 \
  --repo ../harn --yes-live-release
```

Replace the example tag and run ID with the receipt's release and original
hosted run. The checkout's development version doesn't select the target.
This command can't prepare, certify, tag, or publish another release.

To update selected repositories, add `--repositories-json` with a nonempty JSON
list of managed repository slugs. For example,
`--repositories-json '["burin-labs/harn-cloud","burin-labs/homebrew-burin"]'`
updates those repositories without updating other consumers. This also limits
consumer workflow projections, repair, successor rounds, and convergence proof.
The release baseline and the controller's own workflow policy remain release-wide.

To omit separately managed consumers, use `--skip-consumers-json` instead.
It accepts a nonempty JSON list of managed repository slugs and resolves it to
the exact remaining selection. Hosted releases expose this input as `skip_consumers`.
Don't combine inclusion and exclusion inputs. Skipping every consumer fails.

Use the same selection when resuming. An existing full-fleet journal can't become
a selected-repository journal. Empty, duplicate, and unknown selections fail;
omitting the option retains full-fleet behavior. Hosted releases accept the same
JSON through `repositories_json`. This option doesn't narrow pre-tag certification:
every declared consumer must still pass before publication.

For a hosted handoff, download `release-run-<run ID>` from that exact run.
Use its extracted directory as `--state-root` and its
`release-harn/watches/<tag>.json` as `--receipt`. Don't discard the
`release-chain/` directory when moving the handoff between machines.

The command validates the signed remote tag against the watch receipt, checks
publication, and refuses a target older than any observed consumer pin.
Proposal writes retain their existing exact-head leases. A baseline failure
doesn't skip independent repository updates, but remains failed in the journal.

If interrupted, run the same command with the same journal. Recorded proposal
intent triggers read-only reconciliation. A pending proposal is created only
when its owner proves the earlier effect absent. A recorded failure never retries.
An uncertain fleet dispatch is adopted
by exact chain identity; it isn't dispatched again. A red workflow isn't rerun.
If acceptance remains unknown, the command returns pending rather than guessing.

Read `.receipt.status` in the JSON result. Only `complete` proves every stage.
`active` reports pending or failed evidence; `stopped` records a control event.
The default command waits up to three hours for the accepted fleet chain.

The hosted release uses `--no-wait` to hand off a pending journal to its cheaper
fleet job. That job uses `--reconcile-only` with read-only credentials to record
terminal proof through the same owner. A successful handoff isn't completion.

For repository-update receipts and failure diagnosis, see
[Run or resume an update](../harn-update-operations.md).
