# Shipping writer contract

Use `harn-bump-fleet/shipping_writer` when your adapter must retain its startup
authority across later effect checks. The [writer module](../../lib/shipping_writer.harn)
owns the contract. The [registry module](../../lib/shipping_authority.harn)
owns each repository's routing record.

## Interface

| Function | Result |
| --- | --- |
| `capture_writer(reader, writer)` | Captures the routing record and original controller permit, or throws. |
| `authorize_writer(reader, capture)` | Returns an authorized or denied decision without replacing the capture. |
| `run_writer_command(reader, payload)` | Decodes a JSON `capture` or `authorize` command and returns a typed response. |
| `parse_registry(text)` | Parses registry TOML through its owning manifest parser. |

`FormerWriter` names your writer, repository and actual control commit.
`WriterCapture` retains that identity, routing, configuration and opaque permit.
The controller owns the permit's contents and validation.

`AuthorityReader` supplies your registry read, configuration read and controller
call. This module performs no provider I/O and reads no credentials.

## Refusal behavior

Capture needs a complete registry. Missing or malformed data does not imply
legacy ownership. An explicit legacy record needs no controller call.

Managed capture needs a measured configuration and an authorized controller
answer for the same installation and writer. Later checks use the original
permit. Changed routing, denied authority or a replacement permit returns a
denied decision.

The command response uses `fleet.shipping-writer-response.v1`. Capture errors
return `denied` with no capture. An effect check that is denied retains your
original capture and includes the decision's reason.

The [command tests](../../tests/shipping_writer.harn) cover these boundaries,
including missing registry data, changed enrollment, mismatched identities and
permit replacement.

## Host obligations

Capture once at startup. Check authority just before each effect, using that
same capture. A failed startup must not gain a new permit during a later retry.

This library does not stop a running provider job or transfer live authority.
Your host must enforce the decision at its effect boundary. Your rollout must
also account for old jobs that cannot honor the generation fence.
