# Contributing

This repository holds the Harn release and fleet bump harnesses. When you
change something here, you change how every Burin Labs repository gets its Harn
runtime pinned, and how a Harn release is cut, shipped, tagged, and proven
published. A mistake does not stay local. It shows up as a stalled fleet or a
wedged release lane.

The repository is public so that its Actions coverage is free and its operations
are inspectable. The harnesses are written for Burin Labs' own release work, and
issues and pull requests come mostly from the people and agents running that
work. You are welcome to open an issue if you find a defect.

## Before you change anything

Read `AGENTS.md` first. It names which module owns which stage of a release, and
the rule that stage policy stays out of the `release_harn.harn` entrypoint. Most
review comments on this repository come from putting logic in the entrypoint or
adding a second implementation behind a helper.

Two constraints are easy to miss:

- Every handwritten source file stays under 1,500 lines.
  `check_source_length.harn` fails the build otherwise.
- Shared code belongs in `lib/*.harn` and needs focused coverage in
  `tests/*.harn`.

## Set up

Use the Harn version pinned in `.harn-version`. Do not use whatever `harn` is on
your `PATH`, because a global binary can be newer or older than the pin.

```sh
scripts/install_harn.sh
.harn/bin/harn install --locked
```

Run harnesses through `scripts/with_env.sh`, which selects the pinned runtime
and loads provider credentials without putting them on the command line.

## Verify your change

Run both of these before you push:

```sh
scripts/harn-project.sh verify
scripts/harn-project.sh test
```

`verify` runs the static check and the formatter over every tracked and
non-ignored Harn source. Use `scripts/harn-project.sh format` to fix formatting
it reports.

If you changed anything the release path touches, also exercise the mock release
that CI runs:

```sh
scripts/with_env.sh harn run --no-sandbox release_harn.harn -- --mock --agent --mode ship-pr
```

A documentation-only or workflow-only change does not need the mock release.

## Add a changelog fragment

Any change a person operating the fleet would notice adds one file under
`changelog.d/` named `<pull-request-number>.<category>.md`, where category is
`added`, `changed`, `fixed`, or `removed`. Write one sentence saying what
changed for the operator. Do not edit `CHANGELOG.md` by hand.

## Open the pull request

Title it `[Area] Sentence case description`. `AGENTS.md` lists the eight areas
and how to pick one. Keep the description to 3-5 sentences: what changed, why,
the one risk, and how you verified it. `.github/pull_request_template.md` has a
worked example.

Rebase on the current `origin/main` first, then push a branch and let the
required checks run.

## Keep the repository publishable

This repository is public. Do not commit private repository details, customer
data, secrets, local paths from private investigations, or notes that only make
sense inside a private Burin repository. Generated run artifacts under
`.harn-runs/` and `.harn/` stay ignored and never get committed.

## Write documentation to house style

Any Markdown page you add or change follows the Burin Labs
[house-style skill](https://github.com/burin-labs/.github/blob/main/skills/house-style/SKILL.md):
one Diataxis mode per page, second person, sentence-case headings, no em dashes,
and a named verification for every claim.

## Labels

`.github/labels.yml` is this repository's label taxonomy. The priority, status,
and effort categories are copied from
[`burin-labs/.github`](https://github.com/burin-labs/.github/blob/main/.github/labels.yml)
and are not edited here. The `area/*` labels use the same words as the pull
request title areas.
