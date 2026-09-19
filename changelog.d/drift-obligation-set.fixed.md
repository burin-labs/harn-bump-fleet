Stopped holding a drifted commit to obligations the branch never required. The
pull-request lane set harvested every job name from every certification
workflow carrying a `pull_request` trigger, and `ci.yml` carries one along with
twenty-nine jobs. Those jobs already reach the branch through the required
aggregate that covers them, so naming them individually added no proof and made
every path-gated job a false refusal. A workflow that ordinary commits on the
default branch already run now contributes no lanes.
