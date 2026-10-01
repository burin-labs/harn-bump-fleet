# Consumer refresh finalization

A consumer-owned `.harn/fleet-projections.toml` may declare
`finalize_refresh_command` in its `[bump]` table. The value must be a non-empty
string. Fleet trims it and projects it as `finalize-refresh-command` in the
consumer's runtime-update workflow.

The reusable Harn workflow runs this command after migrations and formatting,
before marking refresh complete and validating the result. Use the consumer's
existing artifact writer when these phases can change generator inputs. A
failed command prevents refresh from completing.

Omitting the field preserves the existing update flow and emits no finalizer
input. Consumer-owned commands belong in the consumer manifest; declaring
`bump_finalize_refresh_command` for that consumer in public `fleet.toml` is
refused. The workflow policy check also refuses a finalizer input that differs
from the declared command.
