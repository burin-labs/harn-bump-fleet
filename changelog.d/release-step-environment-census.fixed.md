The hosted release's "Run release harness" step lost `RELEASE_MODE` from its
environment while keeping two reads of it. Under `set -u` every cut would have
aborted about ten minutes in, past the checkout, the mint, and the harness
build. The variable is restored, and a structural check now refuses any shell
step that reads a name neither its own environment, its job's environment, nor
an earlier step's `GITHUB_ENV` export declares.
