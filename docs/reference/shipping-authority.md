# Shipping ownership registry

Each `fleet.toml` repository declares `shipping`. The `shipping_authority`
package export owns decoding, complete-inventory validation, and record identity.
Inventory readers may omit this field in unrelated fixtures. A writer cannot:
`capture_shipping_authority` refuses missing or invalid declarations anywhere in
the current registry, an empty registry, duplicate repositories, and unknown targets.

An existing shipping path declares:

```toml
shipping = { kind = "legacy" }
```

A Harn-managed path declares its installation identity and the immutable Git
object containing its public configuration:

```toml
shipping = { kind = "harn", installation = "example-installation", configuration = { repository = "example/control", commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", path = "shipping/config.json" } }
```

The locator has no credentials or local filesystem paths. Its repository is a
slug, its commit is a full immutable SHA, and its path is relative to that tree.
Fetching that object and loading its configuration may fail. Failure grants no
legacy authority. The record is routing metadata, not a writer permit.

A writer captures one `ShippingRecord` at startup. Before each effect,
`shipping_authority_current` compares it with a fresh trusted registry read.
A changed descriptor refuses the original record; the writer cannot replace its
capture with the newer record. Unrelated valid repository edits leave its identity
unchanged. A managed writer also needs Harn's original generation-bound permit
and fresh canonical installation state before every effect.

`check_shipping_authority.harn` reports required, declared, valid, missing, and
invalid declarations. CI supplies `FLEET_SHIPPING_BASE_SHA` from the event's base
commit and compares that exact Git object. Once managed, a repository cannot be
removed, returned to legacy ownership, or assigned another installation. Rollback
uses the same installation's verified shadow generation and writer enrollment.

Declaring these records does not transfer controller authority. Live enrollment
still requires release guards, exact source and protection snapshots, a complete
authenticated drain census, and Harn's fenced generation transfer.
