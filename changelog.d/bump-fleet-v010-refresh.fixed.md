- Fixed the scheduled Harn bump workflow for v0.10.0 by re-platforming the
  bump-fleet harness sources onto Harn's const/let-era syntax and updating the
  pinned GitHub connector dependency. The workflows also skip Rust cache
  metadata probing when the repo has no `Cargo.toml`, so cache setup no longer
  emits misleading `cargo metadata` errors in this Harn-only repo.
