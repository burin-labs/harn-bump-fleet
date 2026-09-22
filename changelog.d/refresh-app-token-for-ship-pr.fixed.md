Hosted ship-pr no longer pins a one-hour GitHub App installation token in
`GH_TOKEN` for the whole harness run. Credentials refresh every 40 minutes into
the git credential helper and `gh auth`, so the tag push after certification
still authenticates.
