#!/usr/bin/env bash
set -euo pipefail

if (( $# < 5 )); then
  echo "usage: combine_harn_cost_receipts.sh OUTPUT SCHEMA TARGET REVISION RECEIPT..." >&2
  exit 2
fi

output="$1"
schema="$2"
target="$3"
revision="$4"
shift 4
receipts=("$@")
paths="$(printf '%s\n' "${receipts[@]}")"

jq -s \
  --arg schema "$schema" \
  --arg target "$target" \
  --arg revision "$revision" \
  --arg paths "$paths" '
    . as $records |
    ($records | all(
      .cost_status == "exact"
        and (.cost_usd | type == "number" and . >= 0)
        and (.call_count | type == "number" and . >= 0)
        and (.input_tokens | type == "number" and . >= 0)
        and (.output_tokens | type == "number" and . >= 0)
        and .unpriced_calls == 0
        and .usage_unknown_calls == 0
    )) as $exact |
    {
      schema_version: $schema,
      target: $target,
      controller_revision: $revision,
      cost_status: (if $exact then "exact" else "unknown" end),
      cost_usd: (if $exact then ($records | map(.cost_usd) | add) else null end),
      known_cost_usd: ($records | map(.known_cost_usd // 0) | add),
      call_count: ($records | map(.call_count // 0) | add),
      input_tokens: ($records | map(.input_tokens // 0) | add),
      output_tokens: ($records | map(.output_tokens // 0) | add),
      unpriced_calls: ($records | map(.unpriced_calls // 0) | add),
      usage_unknown_calls: ($records | map(.usage_unknown_calls // 0) | add),
      source_receipts: ($paths | split("\n") | map(select(. != ""))),
      reason: (if $exact then null else "source_cost_receipt_not_exact" end)
    }
  ' "${receipts[@]}" > "$output"
