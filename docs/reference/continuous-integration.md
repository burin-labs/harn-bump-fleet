# Continuous integration

What this repository's own CI runs, and what each job proves.

Run `scripts/harn-project.sh verify` locally to check, lint, and format-check
tracked plus non-ignored untracked `*.harn` files. The same script handles paths
without shell word-splitting; use `scripts/harn-project.sh format` for fixes.
Use `scripts/harn-project.sh test` for the full local suite so source gates and
tests resolve the same repo-pinned binary. If that binary is absent or stale,
the wrapper installs the checksum-verified `.harn-version` release instead of
silently falling back to an ambient Harn. GitHub Actions passes `--tracked-only`
to verify the exact committed tree with the explicit public API types required
by `harn.toml`; its setup action installs the same exact release before invoking
Harn directly. Risky structured-Git contracts run separately with
`.harn/bin/harn test tests-risky/release_ref_cleanup_git_push.harn --approve-risky git.push`;
the Harn sandbox still blocks network egress. CI installs the
published `harn-cli` version pinned by `.harn-version` through Harn's
checksum-verifying setup action. `scripts/install_harn.sh` remains the local
developer bootstrap.

The unit job checks out full history and scans the pull-request title,
description, and every commit subject and body before it runs the suite.
Authenticated assistant-session links are refused by structure. The diagnostic
names the commit and policy but omits the session identifier and any URL query
values, so the refusal is safe to publish in a CI log.

This repo also ships `.github/workflows/bump-harn.yml`, so future fleet runs
can update `harn-bump-fleet` itself through the same
`automation/bump-harn-runtime` PR flow as the connector repos. This repository
stores `.harn-version` as bare semver (`X.Y.Z`), the form written by Harn's
reusable bump workflow. Both readers normalize either spelling anyway —
`scripts/install_harn.sh` strips a leading `v` before building the tag, and
`lib/bump_pins.harn` runs the pin through `strip_v` — so historical `vX.Y.Z`
pins keep comparing equal.
