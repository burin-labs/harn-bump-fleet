Fix the v0.10.116 fleet update controller so its typed bump entrypoint compiles
before dispatching consumer updates, with the public-surface impact shape kept
typed across preparation and concurrent execution.
