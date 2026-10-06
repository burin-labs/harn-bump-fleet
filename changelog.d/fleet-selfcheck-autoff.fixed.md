A behind but fast-forwardable bump-fleet checkout now fast-forwards in place by
default instead of failing the launch with a manual `git pull --ff-only` step.
The self-check still fails loud only when a fast-forward would be unsafe — a
diverged history, or a dirty working tree without an explicit `--self-update`
override — so a routine stale checkout no longer burns a release attempt.
