# Harn update repair benchmark

This benchmark repairs the tracked synthetic Rust crate under
`testdata/harn_update_repair`. Rust 1.95 Clippy rejects two deliberately old
patterns in `src/lib.rs`. The exact failing CI output is embedded in the
harness; the repair agent gets only the normal limited checkout tools, then the
fixture's real Clippy command decides success.

Copy the fixture to a disposable directory and commit it before each trial.
The harness requires that exact clean commit. Its synthetic repository name is
not owned by the GitHub App, so the canonical publisher refuses after local
validation. This proves the agent and validator path without creating a pull
request.

Run one route with the ordinary credential loader:

```sh
benchmark_dir="$(mktemp -d)"
cp -R testdata/harn_update_repair/. "$benchmark_dir"
git -C "$benchmark_dir" init
git -C "$benchmark_dir" add .
git -C "$benchmark_dir" commit -m fixture
benchmark_head="$(git -C "$benchmark_dir" rev-parse HEAD)"
scripts/with_env.sh .harn/bin/harn run --no-sandbox benchmark_harn_update_repair.harn -- \
  --repository-dir "$benchmark_dir" --head-sha "$benchmark_head" --route value
```

Store every JSON result outside the source checkout. Compare the validated
result, route, model, tokens, exact or lower-bound cost, elapsed time, and
changed paths. Run the strong route only after a documented value-route miss;
do not treat a single success as a reliability claim.

The expected terminal state is local repair validated and publication refused.
Record the route, model, token and cost receipt, elapsed time, changed paths,
and validation result for every trial. A single success proves the steel thread,
not route reliability.
