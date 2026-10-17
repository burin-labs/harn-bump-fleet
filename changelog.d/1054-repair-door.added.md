A failed release stage now performs exactly the repair its typed cause names,
at most once, and stops with a stated reason otherwise. The set of effects a
repair may perform is a closed allowlist, so no repair can re-cut a release,
and an effect that reads nothing back is refused rather than reported as done.
