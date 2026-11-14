# Automation runners

Each repository row in `fleet.toml` may set `automation_runner` to `hosted`
or `owned`. Omission selects hosted runners. Owned placement requires an
explicit `visibility = "private"`; public or undeclared visibility is refused.

The typed owned-pool registry in `lib/fleet_manifest.harn` maps each workload
to its capability and workflow input:

| Workload | Pool | Projected input |
| --- | --- | --- |
| `smart_ship` | Light Linux | JSON array of the self-hosted, Linux, X64 and harn-ci-light labels |
| `bump_validation` | Rust-capable Linux | Literal harn-ci-big label |

Unknown workloads are refused. Smart Ship and runtime updates share the same
repository choice. Consumers do not declare a separate bump runner. The bump
workflow drift check refuses missing, changed, malformed or undeclared runner
inputs. Hosted bump adapters omit the input and use their pinned workflow's
default.
