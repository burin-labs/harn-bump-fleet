# Sign blocked bot pull requests

Rewrite an unsigned dependency bot head as a signed commit so a signature-required branch will take it.

`sign_bot_prs.harn` fixes a narrow merge-queue failure mode: an organization
ruleset requires signed commits, but a bot-authored dependency branch contains
unsigned commits. GitHub can show the PR as green while merge-queue admission
stays blocked by policy.

The helper is dry-run by default. It reads typed PR commit-signature and
merge-queue evidence through `harn-github-connector`, then prints whether each
selected PR can be rewritten. Live mode refuses queued PRs, missing head
branches/OIDs, and already-signed PRs.
It also refuses forks and non-bot authors unless the corresponding override is
passed. The volume of PRs this helper has to handle is set by how much
Dependabot coverage the fleet carries; see
[docs/dependabot-fleet-template.md](../dependabot-fleet-template.md) for the
canonical per-repo config and its grouping rules.
A live rewrite verifies the local checkout's origin matches `--repo`, uses a
fsmonitor-disabled temp worktree, and soft-resets the PR tree to `origin/main`,
leaving the index holding exactly the tree the PR proposes. That state is
published as one commit through `createCommitOnBranch`, which GitHub signs
server-side under the identity of the token already in hand. The rewrite then
waits for GitHub's pull request record to catch up to the publish, verifies the
confirmed head no longer has unsigned commits, and re-checks auto-merge. It does
not bypass CI.

Nothing here holds a signing key, and nothing here pushes: the mutation is the
write. That is what lets a workflow run this against its own blocked PR. The
branch is leased with `expected_branch_oid`, which means what
`git push --force-with-lease=<branch>:<oid>` meant before it — a branch that
moved, or that was deleted, refuses with `stale_head` and nothing is written.
The scratch worktree is always removed, and failing to remove it does not
retract a signature GitHub has already issued.

Common flags:

| Flag | Effect |
|---|---|
| `--repo owner/name` | Repository to inspect |
| `--pr N` / `--prs N,N` | Selected PR numbers |
| `--live` | Perform the rewrite; omitted means dry-run |
| `--checkout <path>` | Local checkout to use; defaults to `~/projects/<repo>` |
| `--allow-non-bot` | Permit a non-bot author |
| `--allow-fork` | Permit a cross-repository PR |
| `--no-auto-merge` | Skip the final auto-merge check |
