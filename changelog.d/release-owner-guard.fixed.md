Live `release_harn` prepare/ship-pr runs now acquire a durable owner guard before
release side effects, so concurrent sessions fail fast with the recorded owner,
version, pin, and takeover instructions instead of racing release branches or tags.
