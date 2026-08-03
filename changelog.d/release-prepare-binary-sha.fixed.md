Release preparation no longer aborts the exact-candidate certification lane when
hashing the warmed `harn` binary. `sha256` is a global builtin, not a `Harness`
capability, so `harness.crypto.sha256(...)` raised a runtime type error and
failed every non-mock release at `candidate-certification-lane`. The mock path
returned a constant and never reached the call, which is why the defect only
appeared in live releases.
