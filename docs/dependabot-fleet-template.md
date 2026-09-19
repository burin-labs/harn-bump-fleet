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
```

`cooldown` defers freshly-published versions so a compromised release has time
to be yanked or flagged before Dependabot ever proposes it.

`open-pull-requests-limit: 5` is set on package-ecosystem blocks only. It is
also Dependabot's default, so stating it on a `github-actions` block is inert
noise: that block covers a handful of actions and the grouping rule below
collapses them into a single PR. Package blocks can genuinely reach the cap, so
there the limit is worth stating where a reader will look for it.

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
  `*-minor-patch` catch-all stays, and it must name every family in
  `exclude-patterns`:

  ```yaml
  groups:
    opentelemetry:
      patterns:
        - "opentelemetry*"
    cargo-minor-patch:
      patterns:
        - "*"
      exclude-patterns:
        - "opentelemetry*"
      update-types:
        - "minor"
        - "patch"
  ```

  GitHub would resolve the overlap on its own by assigning an update to the
  first group it matches in file order, so the excludes change nothing about
  what Dependabot does. They change what a reader — and
  `scripts/check_dependabot_groups.harn` in `harn` — can verify: membership
  becomes a property of the group rather than of where it sits in the file.
  Reordering the file then cannot silently move a family into the batch.

Large multi-package repos (`burin-code`, `harn`, `harn-cloud`) exercise both.
Everything else should be a verbatim instance of the template.

Shipping a manifest is not by itself a reason for a block. `tree-sitter-harn-spm`
has a `Package.swift` with an empty `dependencies` list — the grammar is
vendored and updated by hand under supply-chain review — so a `swift` block
there would monitor nothing. Rule 1 says cover every ecosystem the repo *has*;
an ecosystem with no external dependencies is not one. Its config also drops
`day`/`time`/`timezone` and adds a `ci` commit prefix; that is grandfathered,
not a third permitted deviation.

## Enforcement ownership

This file owns the *written* fleet contract (schedule, cooldown, grouping,
`open-pull-requests-limit`). Delivery-policy *checks* that fail closed on the
silent absence of Dependabot PRs live in
`burin-labs/.github/.github/actions/check-dependabot-config`:

- every update entry has a catch-all group (block or inline `patterns: ["*"]`)
- every committed lockfile has a matching ecosystem entry
- Cargo workspace members and path deps stay inside the configured `directory`
- exact `pnpm-workspace.yaml` overrides carry a `# pin:` annotation

Product repos call that composite action from always-on hygiene (or an
always-on-equivalent job). Do not re-home a parallel line-reader per repo.
Harn-local family membership (`check_dependabot_groups.harn`) remains a
deepening for named groups + catch-all `update-types`; it is not the fleet
delivery gate.

Org package repos still project `templates/dependabot.yml` as a byte-for-byte
`github-actions` prefix via `harn-repo-policy`.

## Audit the fleet

Read every repository from `origin/main`, never from a local checkout. A stale
clone reports gaps that do not exist, and it will report a pin as several
majors behind when the upstream file is current.

```sh
for r in ~/projects/*/; do
  git -C "$r" fetch -q origin 2>/dev/null
  git -C "$r" show origin/main:.github/dependabot.yml 2>/dev/null >/dev/null \
    && echo "$(basename "$r") has" || echo "$(basename "$r") MISSING"
done
```

The gap worth looking for is grouping, not absence. A package block with no
catch-all group turns every dependency into its own pull request, and under
required signatures that means its own manual re-sign.

## Required signatures caveat

The org `required_signatures` rule blocks Dependabot's own commits, which are
unsigned. Dependabot PRs will sit un-mergeable until they are re-signed. Use
`sign_bot_prs.harn` in this repo:

```sh
scripts/with_env.sh harn run --no-sandbox sign_bot_prs.harn -- --repo burin-labs/harn --prs 3704,3705
```

Budget for this when adding coverage to a repo: more ecosystems means more bot
PRs to re-sign each Monday. It is the main reason the grouping rule above is
aggressive.
