Promotion no longer fails a published release on its own projection pull
request. A fleet-owned projection that is green, mergeable, and at the head the
promotion already verified is now a typed `mergeable_projection` waiting for
admission rather than a terminal failure, and the promotion admits it. On the
v0.10.127 cut a projection that had been green for eleven minutes failed the
prerequisite on the first attempt, after the tag, the assets, and crates.io were
all complete. A red projection, or one whose head drifted off the lease, is still
refused and is never admitted.
