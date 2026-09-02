# Harn update repair benchmark

This benchmark repairs the tracked synthetic Rust crate under
`testdata/harn_update_repair`. Rust 1.95 Clippy rejects two deliberately old
patterns in `src/lib.rs`. The exact failing CI output is embedded in the
harness; the repair agent gets only the normal limited checkout tools, then the
fixture's real Clippy command decides success.

The runner copies the fixture to a disposable directory, commits it, grants
that exact directory as a writable process root, and removes it at exit. The
harness requires the exact clean commit. Its synthetic repository name is not
owned by the GitHub App, so the canonical publisher refuses after local
validation. This proves the agent and validator path without creating a pull
request. The fixture carries its own Rust 1.95 toolchain pin and the validator
invokes that toolchain explicitly, so a package-manager compiler earlier on
`PATH` cannot change the benchmark. The runner verifies that exact compiler
before creating the fixture or spending model tokens.

Run one route with the ordinary credential loader:

```sh
scripts/run_harn_update_repair_benchmark.sh value
```

The value route defaults to the same production-ready Cerebras GPT-OSS-120B
cell used by the hosted fleet. A strong-route trial must name an accessible
provider and model through `HARN_UPDATE_STRONG_PROVIDER` and
`HARN_UPDATE_STRONG_MODEL`; the runner refuses to relabel the shared planner
default as a strong route.

Store every JSON result outside the source checkout. Compare the validated
result, route, model, tokens, exact or lower-bound cost, elapsed time, and
changed paths. Run the strong route only after a documented value-route miss;
do not treat a single success as a reliability claim.

The expected terminal state is local repair validated and publication refused.
Record the route, model, token and cost receipt, elapsed time, changed paths,
and validation result for every trial. A single success proves the steel thread,
not route reliability.
