Titled every pull request the release harness opens the way `burin-labs/harn`'s
required title gate demands. The post-tag development bump was opened as
`Start 0.10.129-dev development` and had to be retitled by hand before it could
merge; the binary-size baseline refresh and the post-merge changelog paperwork
carried the same defect and would have failed the same gate. Titles now have one
owner in `lib/pr_title_convention.harn`, and `check_pr_title_convention.harn`
refuses a title the target's gate would reject as well as a pull-request call
site that module does not name.

A consumer repository that runs its own title gate declares `pr_title_gate` and
the one `pr_title_area` the fleet's pull requests belong under, and the manifest
refuses either one declared without the other. Projection convergence and bump
recovery read that row, so `burin-labs/burin-code` now receives `[Harn] Bump
Harn runtime` rather than a title its own gate would refuse.
