- `release_harn --watch-publish` now dispatches a non-blocking
  `build-release-binaries.yml` warm-cache run after the tag-triggered publish
  workflows are confirmed green, so the next Harn release is less likely to pay
  for a cold default-branch release build.
