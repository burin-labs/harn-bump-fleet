# Reserve the merge queue for a Harn release

Use a release queue reservation when unrelated pull requests are already
queued ahead of a Harn release. The release harness records the queue at exact
commit IDs, holds eligible later entries, and restores their auto-merge intent
after the release reaches a terminal state.

GitHub rebuilds a merge group when queue order changes. Frequent manual jumps
can therefore slow the whole queue. See [How GitHub merge queues
work](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue#how-merge-queues-work).

## Audit the plan

Name every pull request on the release-critical path with `--queue-critical-pr`. The
harness reads each exact head commit, the base commit, queue positions,
auto-merge method, and source checks. Audit mode writes a receipt and does not
change GitHub state.

```sh
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- \
  --mode audit \
  --queue-critical-pr 5947 \
  --queue-critical-pr 5955 \
  --queue-critical-pr 5974
```

Read the audit receipt under:

```text
.harn-runs/release-harn/queue-reservations/<reservation-key>/audit.json
```

The plan refuses all mutations when an entry is unknown, a head changed
between observations, restoration intent is missing, or another reservation
owns the queue.

## Ship with the audited critical path

Pass the same `--queue-critical-pr` values to `ship-pr`:

```sh
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- \
  --mode ship-pr \
  --agent \
  --yes-live-release \
  --queue-critical-pr 5947 \
  --queue-critical-pr 5955 \
  --queue-critical-pr 5974
```

The harness preserves critical pull requests and the queue front. It disables
auto-merge only for eligible later entries, using their exact head commits as
leases. Each mutation is checkpointed before the next one starts. The ship
phase refreshes the reservation every 30 seconds, so a later external enqueue
is held under the same typed plan instead of silently refilling the queue.

Use `--queue-live-pr N` when GitHub has more than one pull request in the live
merge group and the queue response does not identify the full group. Use
`--queue-noncritical-live-pr N` only when pull request `N` is safe to hold even
though it is live. Both flags accept repeated or comma-separated values.

## Finish or resume restoration

`release_harn.harn` restores held pull requests when ship fails before handoff.
After a successful handoff, `watch_harn_release.harn` restores them when the
release succeeds or fails. Each watcher poll also refreshes the reservation:

```sh
scripts/watch_harn_release.sh \
  --tag v0.10.52 \
  --yes-live-release
```

If the watcher stops, run the same command again. The reserve and restore
receipts make retries idempotent. A pull request whose head changed is refused
instead of restored at the wrong commit.

The connector uses GitHub's typed
[`disablePullRequestAutoMerge`](https://docs.github.com/en/graphql/reference/pulls#disablepullrequestautomerge)
and
[`enablePullRequestAutoMerge`](https://docs.github.com/en/graphql/reference/pulls#enablepullrequestautomerge)
mutations. The release harness does not issue an ad hoc GraphQL request.
