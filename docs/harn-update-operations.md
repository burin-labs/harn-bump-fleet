# Run or resume a Harn update

## Start one repository

Open **Actions → Update repositories for a Harn release → Run workflow**. Enter
the exact release tag and `owner/repository`. Leave repair enabled when you
want CI failures repaired automatically. Leave the round fields at their
defaults for a new update.

## Read the result

Download the `harn-update-receipts-<run-id>-<run-attempt>` artifact. Start with the startup receipt:
it proves preparation was durable before any provider or subprocess work. Then
read the proof JSON receipt.
Every repository must have state `proven`, with a pull-request number, checked
head SHA, merge commit SHA, and default-branch proof. When proof is incomplete,
the continuation receipt either names the next hosted round or says why no
further automatic round is allowed.

Repair receipts list each attempt's route, model, token count, cost status, and
known cost. `lower_bound` means at least one provider call lacked exact pricing;
`unknown` means the run cannot make a reliable spend claim.
They also include a non-secret authority ledger. “Used” is limited to effects
the controller can prove; the transcript remains the source for individual
tool calls.

## Resume safely

The workflow automatically starts a fresh hosted round when it has remaining
rounds and repair is enabled. To resume after the bound is exhausted, start a
new update deliberately with the same tag and repository; it reconstructs
state from GitHub and exact branch heads, so completed work is reused and stale
leases are refused. Do not create a second automation branch or merge by hand
to make the receipt green; fix the reported missing fact instead.
