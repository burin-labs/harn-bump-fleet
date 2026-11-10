# Consumer bump runner

A consumer-owned `.harn/fleet-projections.toml` may declare `runner_label` in
its `[bump]` table. Fleet projects it as the reusable workflow's `runs-on`
input for refresh and validation. Omitting it leaves runner selection to the
pinned reusable workflow's default.

The value is one literal label: an ASCII letter or digit followed by letters,
digits, dots, underscores or hyphens. Empty values, expressions and label
arrays are refused. The label must identify runners available to the consumer.

Consumer-owned runner placement belongs in that consumer manifest. Fleet
refuses its `bump_runner_label` in public policy for a consumer-owned contract.
The workflow policy check refuses a missing, changed or undeclared runner input.
