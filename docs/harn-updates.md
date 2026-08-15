# Harn updates

This is an explanation of the hosted system that moves each released Harn
version into the repositories that use it. For operator steps, see
[Run or resume an update](harn-update-operations.md). Tools can consume the
[update migration map](harn-update-contract.v1.json) directly.

An update is complete only when one receipt ties together all of these facts:

1. The automation pull request contains the requested Harn version.
2. The green check rollup belongs to that exact pull-request head.
3. GitHub reports the pull request as merged and names its merge commit.
4. The merge commit is reachable from the repository's default branch.
5. The default branch still contains that Harn version or a newer one.

A current-looking version pin without that lineage is not proof. The update
stays blocked and reports the missing fact.

Routine work is deterministic: update pins, rebuild generated files, run the
repository's validator, publish a signed branch, and arm auto-merge. A model is
used only after CI reports a source failure on the exact update head.

Each repair attempt has its own token and dollar limit. Each repository has a
larger independent limit, and the full update run has an outer limit. The
normal value route is Cerebras GPT-OSS 120B. A stronger Cerebras GLM 4.7 route
is allowed only after the same deterministic validation failure survives an
earlier attempt. Both routes must return exact per-call usage; a route that
cannot do that is stopped and recorded as `unknown`, never treated as free.
Receipts record provider, model, tokens, exact cost when known, the known-cost
lower bound otherwise, and why work stopped.

Before the controller looks up an optional latest release, resolves a provider,
starts a subprocess, or installs agent tools, it writes
`fleet-repair-startup-receipt.json`. The final repair receipt adds a compact
authority ledger: requested, granted, controller-proven used, denied, and
structurally unused scope, plus the Harn decider. It contains only secret
reference names and consumer bindings, never secret material. Detailed tool
calls remain in the signed agent transcript rather than being guessed from
availability.

The model may change tracked files through exact-text edits. It may create a
new file only when the repository manifest names that exact path; the creation
tool refuses every other path and cannot overwrite a file. Delete, directory
creation, and general writes are absent. The harness—not the model—runs
validation, stages approved paths, publishes under the observed branch-head
lease, and arms auto-merge.

The hosted job first resolves the exact Harn release and installs that exact
binary. A version or contract mismatch blocks before a model call. It then uses
the protected `release` environment, where the existing provider references
are brokered without exposing their values. GitHub App credentials last less
than a long update run, so one bounded hosted round mints fresh
least-privilege tokens for observation, repair, and proof. If proof is still
incomplete, Harn dispatches one numbered successor round, up to the typed
limit. This is a continuation of the same update, not a second repair policy.
