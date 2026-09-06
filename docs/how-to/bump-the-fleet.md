# Bump the fleet

Every command the bump orchestrator accepts, and when to reach for it.

```sh
# Bump every dependent repo to the latest harn release.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn

# Pin to an explicit tag.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- vX.Y.Z

# Discover-only: never dispatches anything, useful before a real run.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --dry-run

# Run on one repo only.
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --only burin-labs/harn-cloud

# Repair only manifest-admitted failed bump PRs in an isolated fleet root.
# The hosted workflow invokes this automatically after a terminal failure.
# By default every admitted manifest consumer is considered; use
# --max-repositories N for an explicitly narrower rehearsal. The Harn cost
# budget remains the global live-spend ceiling.
scripts/with_env.sh harn run --no-sandbox repair_fleet_convergence.harn -- \
  --fleet-root /absolute/path/to/materialized-fleet vX.Y.Z

# Check fleet-owned package CI adapters without writing them.
scripts/with_env.sh harn run --no-sandbox sync_package_ci.harn -- --check

# Check fleet-owned runtime-bump adapters without writing them.
scripts/with_env.sh harn run --no-sandbox sync_bump_workflows.harn -- --check

# Check the typed first-party connector secret registry against harn.toml.
scripts/with_env.sh harn run --no-sandbox sync_connector_secrets.harn -- --check

# Report every remote fleet-owned file or package pin that drifts from fleet.toml.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- --check

# Scope a check or repair to exact manifest-owned paths. Repeat the flag for
# several files; an unknown path fails before any pull request is changed.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- \
  --check --only burin-labs/burin-code \
  --only-path scripts/agent_shell_guard.harn \
  --only-path scripts/agent_shell_guard_policy.harn

# Propose the repair as one pull request per drifted repository. Pin-only CI
# keeps every repository-owned job and changes only the structurally selected
# package workflow and status-action references.
scripts/with_env.sh harn run --no-sandbox converge_fleet_projections.harn -- --apply

# Inspect unsigned bot dependency PRs that are blocked by required signatures.
scripts/with_env.sh harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --prs 3704,3705

# Rewrite one selected in-repo bot PR head as a signed commit and re-check auto-merge.
scripts/with_env.sh harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --pr 3704 --live

# Verify a release prerequisite PR is actually merged before acting on it.
scripts/with_env.sh harn run --no-sandbox verify_prerequisite_pr.harn -- --repo burin-labs/harn --pr 4872 --expected-head <sha>

# Use a different local LLM for the summary.
HARN_BUMP_FLEET_MODEL=gpt-oss:120b \
HARN_BUMP_FLEET_PROVIDER=ollama \
  scripts/with_env.sh harn run --no-sandbox bump_fleet.harn
```

These operation harnesses inspect sibling checkouts under `~/projects`, run
local Git commands, and call the GitHub connector, so Harn's default run
sandbox must be disabled.

Before scheduled dispatch, `check_fleet_policy.harn` reads every declared
repository's default-branch workflows through the GitHub connector. It checks
the byte-exact package and runtime-bump adapters generated from `fleet.toml`,
verifies other byte-exact file projections, and verifies that each canonical
reusable-workflow pin still publishes the same bytes as the owner's current
default branch. A fleet whose consumers all agree on a stale canonical pin
therefore fails closed instead of silently treating internal consistency as
freshness. Public repositories may retain custom package validation and
runtime-bump commands as named fields. Private consumers instead own those
details in `.harn/fleet-projections.toml`, so the public manifest carries no
private path or command inventory.

A consumer pre-tag contract may name the exact workflow job and step that
prove the candidate:

```toml
[pretag]
gate_workflow = "candidate-gate.yml"
inputs = { target = "{version}", source_revision = "{revision}" }
proof_job = { name = "Candidate product proof", step = "Exercise the candidate" }
```

When `proof_job` is present, that one job and step must complete successfully.
The gate retains every sibling job's status and conclusion as advisory evidence,
but a red or still-running sibling does not block the tag. Missing, duplicate,
skipped, failed, or incomplete proof evidence still fails closed. Consumers
that omit `proof_job` retain the stricter whole-workflow verdict.

The same manifest owns each first-party connector's required secret ids and
trust direction. `policy.connector_secret_schema` selects one generated
`[providers.setup].required_secrets` shape for all connector repositories.
Keep it on `legacy` while the released Harn runtime accepts string entries;
after a compatible release, one change to `direction-v1` projects the closed
`{ id, direction }` records everywhere. `sync_connector_secrets.harn` is
dry-run-first and changes no other manifest field.

`converge_fleet_projections.harn` is the repair for what that check reports. It
renders the same byte-exact projections, compares them against the same remote
default branches, and proposes the difference as one pull request per drifted
repository on an `automation/fleet-projections-<digest>` branch named for the
exact bytes it carries. Each run also retires the proposals it has moved past:
an open projection pull request on any other such branch is proposing bytes the
manifest no longer says, so it is closed with the reason rather than left to
conflict behind an auto-merge that can never fire. It repairs only
the three violations that describe bytes drifting from a projection; a typed
violation names a workflow the fleet does not render, so no correct content
exists to propose. The local `sync_*` harnesses remain the way to converge a
checkout you already have; this is how the fleet converges without one.
`--only-path` narrows that remote repair to exact target paths after `--only`
repository admission. It is repeatable and fails closed if any requested path
is not owned by the selected manifest slice, preventing task-scoped repairs
from absorbing unrelated projection drift.

Nothing in that path writes a default branch or merges anything itself. It does
arm auto-merge on each proposal, leased to the exact commit it just published,
so an appended commit fails closed instead of riding along. Every repository
still keeps its own gate: GitHub merges only once that repository's required
checks pass, and a red projection sits open exactly as before. What arming
removes is the person whose remaining job was to agree with a byte comparison
the loop had already made — and whose absence, for three days in August 2026,
left the whole fleet unable to bump. `--no-auto-merge` proposes without arming.

A repository that refuses arming — auto-merge switched off, or a gate the
fleet's App cannot satisfy — is reported as `auto_merge.state = "refused"` and
fails the run. A standing proposal older than three days is `overdue` and
fails the same way. A sweep that cannot list open proposals does too. Silence
here is the defect: a fleet that quietly stopped converging reads exactly like
a fleet with nothing to converge.

The scheduled `Converge Fleet Projections` workflow is the only place `--apply`
runs by default; the harness itself reports and exits unless asked to write.
