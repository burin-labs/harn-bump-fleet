# harn-bump-fleet

[![Harn static checks](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml/badge.svg)](https://github.com/burin-labs/harn-bump-fleet/actions/workflows/harn-static.yml)

Local Harn-version bump orchestrator. `fleet.toml` is the typed owner of fleet
membership and reusable-workflow policy. The orchestrator resolves those
declared repositories under `~/projects`, rejects a missing checkout, wrong
remote, or missing dispatch adapter, and drives every `harn_bump = true`
repository to the latest published Harn release with auto-merge enabled in
parallel, idempotently, with a self-contained audit trail.

This is a Harn-native script (`bump_fleet.harn`): no Python glue, no shell
wrapper. It exists partly as a useful local tool, partly as a proof that
Harn the language is viable beyond LLM orchestration.

The companion `sync_agent_guidance.harn` workflow owns one small marked block
inside each fleet repository's `AGENTS.md` and projects `CLAUDE.md` directly to
that canonical file. It preserves every repository-specific rule outside the
markers.

```sh
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --check
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --dry-run
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --apply
scripts/with_env.sh harn run --no-sandbox sync_agent_guidance.harn -- --only harn-cloud
```

## Repository scope

This repo is public for transparency and cheap GitHub Actions coverage, but
the tools are written for my own Burin Labs/Harn release operations. Keep
audits, logs, prompts, and examples suitable for a public repo: do not commit
private-repo details, customer data, secrets, or anything too inside baseball
from private Burin repositories. Generated run artifacts are intentionally
ignored under `.harn-runs/` and `.harn/`.

Harn sandboxes `harn run` by default. These local ops harnesses inspect
`~/projects`, local Git state, and authenticated GitHub connector state, so use
`scripts/with_env.sh harn run --no-sandbox` for real local release and bump
runs. The wrapper verifies the repo-pinned runtime before Harn parses the
program and loads the configured provider environment. Mock release runs can
stay sandboxed.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request. It
covers the pinned runtime setup, the two checks to run, the changelog fragment,
and the `[Area] Sentence case description` title convention. `AGENTS.md` names
which module owns which release stage.

## Documentation

Start with the job you need to do.

### Do a thing

- [Bump the fleet](docs/how-to/bump-the-fleet.md). Every orchestrator command,
  from a discover-only rehearsal to a live parallel bump.
- [Release Harn](docs/how-to/release-harn.md). Drive a release through the
  harness, locally or on hosted runners.
- [Free a wedged release](docs/how-to/free-a-wedged-release.md). Recover a
  stalled version, resume a certified candidate, apply a post-publish fixup.
- [Reserve the release queue](docs/how-to/reserve-the-release-queue.md). Take
  and hold the single release slot.
- [Resume a published release](docs/how-to/resume-a-published-release.md). Pick
  a release back up after publication.
- [Sign blocked bot pull requests](docs/how-to/sign-blocked-bot-pull-requests.md).
  Get an unsigned dependency bot head past a signature-required branch.
- [Review a run in chat](docs/how-to/review-a-run-in-chat.md). Open an
  interactive loop over a finished run.

### Look something up

- [Local setup](docs/reference/local-setup.md). Configuration files, credential
  precedence, planner tuning, the macOS launcher, and the tools a run expects
  to find.
- [Continuous integration](docs/reference/continuous-integration.md). What this
  repository's own CI runs, and what each job proves.
- [Harn updates](docs/harn-updates.md) and
  [update operations](docs/harn-update-operations.md). The update vocabulary
  and the operator surface behind it.
- [Dependabot fleet template](docs/dependabot-fleet-template.md). The projected
  dependency configuration every fleet repository receives.

### Understand the design

- [How a bump run works](docs/explanation/how-a-bump-run-works.md). The order a
  run executes in, why a rerun is safe, and what it leaves behind.
- [Candidate record](docs/explanation/candidate-record.md). How one signed
  certification identity selects the exact archives used after certification.
- [Fleet convergence](docs/fleet-convergence.md). What convergence means, and
  what it does not.
- [Update benchmark](docs/harn-update-benchmark.md). How repair performance is
  measured.
