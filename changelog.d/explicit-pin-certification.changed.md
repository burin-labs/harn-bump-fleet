Hosted platform certification now honours an explicit `--at-sha` pin in its
post-lane `origin/<base>` re-read, instead of discarding a fully green
certification because unrelated commits merged while it ran. An operator-named
pin already parents the release branch at that commit without rebase, and each
hosted proof is bound to it by the per-dispatch `head_sha == pin_sha` check, so
a base that advanced afterwards refutes nothing the receipt asserts;
`release_cutoff_gate` drew this same line for the pre-tag drift probe, so
`--at-sha` now means one thing across the harness rather than two. An
implicitly captured pin still fails closed on movement, a base that cannot be
reread at all still fails closed, every other proof stays unconditional, and the
moved head is still recorded as `remote_sha_after`. Releases can now certify
against a continuously merging `main` without freezing the merge queue.
