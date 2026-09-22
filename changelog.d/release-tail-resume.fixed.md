A hosted release tail can now resume past its own next-development-version bump.
Between tagging `vX.Y.Z` and merging the follow-up bump, the workspace reads
`X.Y.Z-dev` while the tag already exists, so every rerun of the tail refused
before doing any work. `--resume-tagged-release` (workflow input
`resume_tagged_release`, env `HARN_EXT_RELEASE_RESUME_TAGGED`) authorizes exactly
that window and nothing wider, and `run_harn_release.sh` /
`dispatch_hosted_release.harn` carry the flag through to the hosted run so the
recovery is a re-dispatch on the canonical path rather than a hand-driven
`gh workflow run`.
