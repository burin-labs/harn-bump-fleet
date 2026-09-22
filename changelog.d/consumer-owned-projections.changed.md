Fleet projection and runtime-update details are now declared by each consumer
in `.harn/fleet-projections.toml`. The public fleet manifest retains repository
identity and ownership but no longer publishes consumer target paths, commands,
pin paths, or permitted generated files.
