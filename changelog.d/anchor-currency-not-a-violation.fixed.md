Stop failing the fleet policy check when a workflow policy pin merely trails
the owner's newest bytes. A pin that does not resolve is still a hard failure;
trailing is now reported as `behind` without turning the daily gate red, so the
check can return to green without waiting for a release.
