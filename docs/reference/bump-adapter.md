# Runtime bump adapter

`BumpAdapterContract` in [fleet_manifest.harn](../../lib/fleet_manifest.harn)
owns the inputs in each generated runtime bump workflow. The
[renderer](../../lib/bump_workflow_projection.harn) writes those inputs, and the
[policy check](../../lib/fleet_policy.harn) refuses missing or changed values.

## Pull request title

`pr-title` is the complete title: `[Area] Bump Harn runtime`.
The area comes from the repository's `pr_title_area` in `fleet.toml`.
An omitted area uses `CI`. Custom areas such as `core` and `Harn` keep their case.
The shared title helper owns the format; the adapter does not infer it from a title gate.

## Test inventory

`test-inventory-mode` is always present. Its default is `package`.
This runs package test discovery, which reports missing or empty tests as failures.

The contract selects `repository-validation` only when `harn_package = false`
and the repository declares a nonempty validator. Consumer-owned commands come
from `.harn/fleet-projections.toml`; they remain in that repository.
Before those commands are read, the public fleet row retains strict package discovery.
An explicit inventory override cannot waive either requirement.

The released workflow also checks the real root. Repository validation requires
an existing directory and a positively measured absent `harn.toml`.
An unreadable root or manifest refuses this mode.

Its inventory receipt has schema `harn_bump.repository_validation.v1` and status
`not_applicable`. It has no package success flag or test counts.
The declared validator runs after refresh and must pass before publication.
This does not enroll nonpackages in the candidate package compatibility scan.

## Delivery

The adapter delegates to the released Harn workflow pinned in `fleet.toml`.
Fleet convergence opens protected consumer pull requests when its inputs change.
Landing an adapter starts that consumer's normal runtime bump workflow.
See [bump the fleet](../how-to/bump-the-fleet.md) for operator commands and
[consumer refresh finalization](consumer-refresh-finalization.md) for the optional finalizer.
