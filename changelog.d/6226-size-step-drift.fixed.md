- The pre-tag binary-size gate matched the workflow step `Check binary size
  budget` by display name. harn#6226 renamed it to `Evaluate the binary-size
  growth signal`, so the step ran, passed, and the gate still reported it as
  unexecuted — cancelling both platform lanes as `sibling_failure` 43 minutes
  into a release. The constant now names the current step.
- Before dispatching, the gate proves both step names it matches on still exist
  in `build-release-binaries.yml` **at the policy SHA it is about to dispatch**,
  and fails in seconds naming the missing step and the constant to fix. The
  GitHub API exposes steps only by display name, so this coupling cannot be made
  structural — but it can be made loud.
