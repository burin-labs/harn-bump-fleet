Corrected the record on the v0.10.129 drift refusal and covered the arm that
actually produced it. `Deploy docs` is not one of the contexts burin-labs/harn
requires; it reached the evidence as a lane, because the pull-request lane set
harvests every job name from every certification workflow carrying a
`pull_request` trigger and `ci.yml` contributes twenty-nine of them. The skip
rule already covered both arms, so behavior is unchanged; the lane arm now has
its own falsifier and its own controls.
