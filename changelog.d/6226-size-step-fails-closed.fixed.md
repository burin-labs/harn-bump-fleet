- The pre-tag step-name check now fails **closed**. Its first cut returned "no
  names are missing" when the workflow could not be read at the policy SHA, so
  "the contract holds" and "the contract was never checked" produced the same
  verdict and the release would spend a full build on a check that never ran.
- The decision moved into a pure `pre_tag_binary_size_gate_step_contract`, which
  distinguishes *unreadable* from *missing* — the operator fixes a checkout in
  one case and a constant in the other — and makes every branch reachable from a
  test.
