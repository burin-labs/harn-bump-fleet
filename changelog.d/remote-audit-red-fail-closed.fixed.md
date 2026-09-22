Remote release-audit offload now aborts a release when the remote audit starts
successfully and exits red, instead of rerunning the same audit locally and
turning deterministic release failures into long timing-dependent retries.
