# Renamed: Harn updates

The primary name for this system is now **Harn updates**. See
[Harn updates](harn-updates.md) for the current contract and
[Run or resume an update](harn-update-operations.md) for operator steps.

The text below describes the previous v1 compatibility surface.

# Compatibility surface

Older links and schema identifiers use “fleet convergence.” The live controller
is the versioned [Harn update contract](harn-update-contract.v1.json): a
deterministic update first, then a bounded, evidence-led repair when exact CI
reports a source failure. Harn—not a second static GitHub step—decides whether
one fresh hosted round is warranted. The current limits, providers, receipts,
and refusal rules are documented in [Harn updates](harn-updates.md).
