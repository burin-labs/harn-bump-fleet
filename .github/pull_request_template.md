<!--
Title: [Area] Sentence case description, for example
"[Projections] Close superseded convergence proposals before arming".
Area is one of: Release, Fleet, Bump, Projections, CI, Scripts, Docs, Tests.
See the pull request title convention in AGENTS.md.

Body: 3-5 sentences total. What changed, why, the one risk, and how you
verified it, at the claim level. Do not list test commands; the Files and
Checks tabs already show those. Replace the example below with your own.
-->

Closes superseded fleet projection proposals instead of leaving them open,
because a proposal branch named for bytes the manifest no longer renders can
never satisfy auto-merge and blocks the next proposal behind a conflict. Before
this, one stale proposal stalled convergence for that repository until someone
closed it by hand. The risk is that a proposal closed as superseded was in fact
the current one, which would show up as a repository that reports drift on the
next scheduled check rather than as a bad merge. Verified by running
`converge_fleet_projections.harn --check` against a fleet root holding both a
current and a superseded proposal and confirming only the superseded one closed.

Closes #123 items: 1, 2 | Single-ask: #123
