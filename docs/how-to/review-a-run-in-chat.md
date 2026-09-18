# Review a run in chat

Open an interactive loop over a finished run for a postmortem or a pre-release review.

Both harnesses drop into a TTY-aware chat loop after their pipeline
finishes. It auto-enables when stdin is a controlling terminal
(`/dev/tty` is openable) and auto-skips in CI / non-interactive shells.
The chat agent gets read + edit tools so it can investigate the run *and*
apply a fix to the harness or release artifacts mid-debrief if you ask.

```sh
# Disable chat even when at a TTY.
scripts/run_harn_release.sh --no-chat        # or `HARN_EXT_CHAT=0`

# Skip the pipeline; open the loop over a prior run.
scripts/run_harn_release.sh --chat-only                       # carousel
scripts/run_harn_release.sh --chat-only --chat-run <run-id>   # direct

# Change the start-typing timeout (default 60s).
scripts/with_env.sh harn run --no-sandbox bump_fleet.harn -- --chat-timeout-s 120
```

`release_harn.harn` also runs a **non-trivial classifier** before live
release side effects fire. When the CHANGELOG/PR body looks substantive
(breaking changes, new sections, >12 bullets, deterministic findings),
the pipeline pauses on a pager view and asks you to approve `[a]`,
abort `[q]`, or `[c]`hat first.

Slash commands inside the chat loop:

| Command | Description |
|---|---|
| `/help` | Print the command list |
| `/exit`, `/quit` | End the chat |
| `/cat <path>` | Print a file (resolved under the run dir or repo) |
| `/diff <path>` | `git diff` for a path, piped to the pager |
| `/runs` | List recent runs of this harness |
| `/load <run-id>` | Switch the chat to a different run (reseeds context) |
| `/save <path>` | Save the chat transcript so far |
| `/pager <path>` | Open a file in `$PAGER` (`less`) |

During the pre-release gate, the chat also accepts `/approve` and
`/abort` to resolve the decision and return to the main pipeline.
