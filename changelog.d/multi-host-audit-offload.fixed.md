Release audit offload now tries the maintained builder order before falling back to the local full audit, so a busy primary builder no longer forces every live release through the slow local path.
