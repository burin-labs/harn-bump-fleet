# Harn update repair benchmark

This benchmark replays a real downstream release failure: Burin Code pull
request #6238 after its Harn v0.10.95 bump. Rust 1.95 Clippy rejected three
new patterns in `dependency_roots.rs`. The exact failing CI output is embedded
in the harness; the repair agent gets only the normal limited checkout tools,
then the repository's real `burin-tui-engine` Clippy command decides success.

The benchmark checkout is detached at commit
`00798259baa91911f72db336c04ab99c61ef6ef1`. Its synthetic repository name is
not owned by the GitHub App, so the canonical publisher refuses after local
validation. This proves the agent and validator path without creating a pull
request.

Run one route with the ordinary credential loader:

```sh
scripts/with_env.sh .harn/bin/harn run --no-sandbox benchmark_harn_update_repair.harn -- \
  --repository-dir /private/tmp/burin-6238-repair-benchmark \
  --head-sha 00798259baa91911f72db336c04ab99c61ef6ef1 --route value
```

Store every JSON result outside the source checkout. Compare the validated
result, route, model, tokens, exact or lower-bound cost, elapsed time, and
changed paths. Run the strong route only after a documented value-route miss;
do not treat a single success as a reliability claim.

## Recorded steel thread

On 2026-08-15, the strong route used Cerebras `zai-glm-4.7` against a fresh
copy of that exact commit. It made one narrow edit to
`crates/burin-tui/engine/src/dependency_roots.rs`, passed the real Clippy
validator, and the publisher then refused the deliberately nonexistent branch.
That is the expected benchmark terminal state: local repair validated, no PR
was published. The receipt recorded 119,729 tokens and an exact $0.27048275.
The agent used only `repair_read`, `repair_git`, `repair_inspect`, and
`repair_edit`; its tool lease did not expose delete, directory creation, or a
general write tool.

Earlier value-route replay attempts completed the same historical repair for a
combined exact $0.05750765 across three attempts. This is evidence that this
one bounded task can be cheap, not a promise that every migration costs less
than a dollar. OpenRouter Kimi and Fireworks Kimi routes were also exercised;
both returned usage that could not support an exact cost receipt. The controller
stopped them after one turn with `cost_status: "unknown"` rather than calling
the spend zero. Those failed-safe results are as important as the successful
repair: they determine which hosted routes are admissible.
