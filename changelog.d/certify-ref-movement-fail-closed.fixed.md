Hosted platform certification now fails closed whenever the write-once
`release-certify/<pin>` ref moves during the run, including under `--at-sha`.
That tip only changes via force-update, so the old explicit-pin exemption —
which existed for natural `main` drift — no longer applies. Continuous-main
certification is attributed to the write-once dispatch ref itself.
