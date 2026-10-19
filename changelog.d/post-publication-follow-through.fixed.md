The hosted release's post-publication tail now keys on the release's own
verified state — tag present and signed, finalization and prerelease flag,
expected assets attached, packages visible — instead of on the publication
prover step's conclusion. A prover that fails, times out, or goes red on a job
that never touched the publication can no longer silently skip the orchestration
anchor's only writer. A promotion that genuinely does not run now fails a
dedicated report step at the moment it is skipped, so it is distinguishable from
an anchor that is merely trailing.
