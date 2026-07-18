# Fleet dependabot template

Canonical `.github/dependabot.yml` shape for every Burin Labs repo. GitHub has
no cross-repo dependabot config inheritance: each repo must carry its own file.
"DRY" here means one documented template, copied verbatim, with the per-repo
variation confined to *which ecosystem blocks are present* — never to schedule,
cooldown, PR limit, or grouping.

This repo already owns fleet dependency-PR operations (`sign_bot_prs.harn`), so
the template lives here rather than in `harn-canon`, which is scoped to
per-language review invariants.

## Rules

1. **Cover every ecosystem the repo actually has.** Determine this from tracked
   manifests, not from assumption. A repo with only `.harn` files and workflows
   needs exactly one block: `github-actions`.
2. **Never vary the shared fields.** `schedule`, `cooldown`, and
   `open-pull-requests-limit` are identical in every block in every repo.
3. **Group so the fleet does not drown in PRs.** See the grouping rule below.
4. **Add a block, never a second file.** One `.github/dependabot.yml` per repo.

## Shared fields

```yaml
schedule:
  interval: "weekly"
  day: "monday"
  time: "09:00"
  timezone: "America/Los_Angeles"
cooldown:
  default-days: 7
open-pull-requests-limit: 5
```

`cooldown` defers freshly-published versions so a compromised release has time
to be yanked or flagged before Dependabot ever proposes it.

## Grouping rule

Two grouping shapes, chosen by blast radius rather than by ecosystem:

- **`github-actions`: group everything, including majors.** Action majors are
  overwhelmingly runner/Node-baseline bumps that land uneventfully, and they
  arrive fleet-wide at once. Grouping them turns a `checkout@v6 -> v7` sweep
  into one PR per repo instead of one PR per workflow dependency.
- **Package ecosystems (`npm`, `pip`, `cargo`, `swift`, `bundler`, `gomod`):
  group minor and patch; leave majors ungrouped.** A package major can carry a
  breaking API change that needs its own review and its own revert.

```yaml
# github-actions
groups:
  actions:
    patterns:
      - "*"

# package ecosystems
groups:
  <ecosystem>-minor-patch:
    patterns:
      - "*"
    update-types:
      - "minor"
      - "patch"
```

## Full template

```yaml
version: 2

# Cooldown defers freshly-published versions so a compromised release has time
# to be yanked or flagged before Dependabot proposes it.
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "America/Los_Angeles"
    cooldown:
      default-days: 7
    open-pull-requests-limit: 5
    groups:
      actions:
        patterns:
          - "*"

  # Repeat per package ecosystem the repo actually has. `directory` points at
  # the manifest; use `directories` for several copies of one ecosystem.
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "America/Los_Angeles"
    cooldown:
      default-days: 7
    open-pull-requests-limit: 5
    groups:
      npm-minor-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
```

## Permitted per-repo deviation

Only two, and both need a comment saying why:

- **`ignore`** for a dependency the repo deliberately pins (a `@types/vscode`
  held to an editor baseline; private sidecar packages that 404 on the public
  registry).
- **Extra `groups`** entries that split a large ecosystem into reviewable
  families (`react`, `eslint`, `opentelemetry`). These are additive; the
  `*-minor-patch` catch-all stays.

Large multi-package repos (`burin-code`, `harn`, `harn-cloud`) exercise both.
Everything else should be a verbatim instance of the template.

## Required signatures caveat

The org `required_signatures` rule blocks Dependabot's own commits, which are
unsigned. Dependabot PRs will sit un-mergeable until they are re-signed. Use
`sign_bot_prs.harn` in this repo:

```sh
harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --prs 3704,3705
```

Budget for this when adding coverage to a repo: more ecosystems means more bot
PRs to re-sign each Monday. It is the main reason the grouping rule above is
aggressive.
