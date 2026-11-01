`converge_fleet_projections.harn --apply` now arms auto-merge on each repair it
proposes, leased to the exact commit it just published. The loop still never
merges: GitHub merges each proposal only once that repository's own required
checks pass, and a commit appended to the branch after publication fails the
lease closed rather than riding in on the fleet's authority. This closes the
other half of the convergence loop — a repair nobody merges is the state that
left the fleet unable to bump for three days, and a human agreeing with a
byte comparison the loop already made was never the gate.

`--no-auto-merge` proposes without arming. A repository that refuses arming is
reported as `auto_merge.state = "refused"`, named in the receipt's
`auto_merge_refused_by`, and left for a human; it does not fail the run,
because an unarmed proposal is still a correct repair.

A standing proposal is re-armed on later runs without republishing its commit,
so a single transient refusal cannot park one repository forever. A proposal
someone closed is not reopened — the drift is still reported, but a cron job
must not overrule that decision.

Known gap: `burin-labs/harn-cloud` is the one fleet repository with a merge
queue, and the connector always sends an explicit merge method, which `gh`
refuses to do for a queue-governed branch. Whether GitHub's API rejects it too
is unverified — every open pull request there was green, so there was no way to
probe arming without really merging something. If it is rejected, that
repository reports `refused` with GitHub's own message, which is the evidence
needed to fix `harn-github-connector` rather than guess at it.
