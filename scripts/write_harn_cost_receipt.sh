#!/usr/bin/env bash
set -euo pipefail

if (( $# < 4 )); then
  echo "usage: write_harn_cost_receipt.sh OUTPUT SCHEMA TARGET REVISION [SUMMARY ...]" >&2
  exit 2
fi

output="$1"
schema="$2"
target="$3"
revision="$4"
shift 4
records=("$@")

write_unknown() {
  local reason="$1"
  local summaries
  summaries="$(printf '%s\n' "${records[@]}")"
  jq -n \
    --arg schema "$schema" \
    --arg target "$target" \
    --arg revision "$revision" \
    --arg summaries "$summaries" \
    --arg reason "$reason" '
      {
        schema_version: $schema,
        target: $target,
        controller_revision: $revision,
        cost_status: "unknown",
        cost_usd: null,
        known_cost_usd: null,
        call_count: null,
        input_tokens: null,
        output_tokens: null,
        unpriced_calls: null,
        usage_unknown_calls: null,
        source_summaries: ($summaries | split("\n") | map(select(. != ""))),
        reason: $reason
      }
    ' > "$output"
}

if (( ${#records[@]} == 0 )); then
  write_unknown "runtime_summaries_missing"
  exit 0
fi

for record in "${records[@]}"; do
  if [[ ! -f "$record" ]] || ! jq -e '
    .event == "run_summary"
      and (.schema_version | type == "number")
      and (.llm | type == "object")
      and ([
        .llm.call_count,
        .llm.input_tokens,
        .llm.output_tokens,
        .llm.known_cost_usd,
        .llm.unpriced_calls,
        .llm.usage_unknown_calls
      ] | all(type == "number" and . >= 0))
  ' "$record" >/dev/null; then
    write_unknown "runtime_summaries_invalid"
    exit 0
  fi
done

summaries="$(printf '%s\n' "${records[@]}")"
jq -s \
  --arg schema "$schema" \
  --arg target "$target" \
  --arg revision "$revision" \
  --arg summaries "$summaries" '
    map(.llm) as $usage |
    ($usage | map(.known_cost_usd) | add) as $known |
    ($usage | map(.unpriced_calls) | add) as $unpriced |
    ($usage | map(.usage_unknown_calls) | add) as $unknown |
    {
      schema_version: $schema,
      target: $target,
      controller_revision: $revision,
      cost_status: (
        if $unpriced == 0 and $unknown == 0 then "exact"
        elif $known > 0 then "lower_bound"
        else "unknown"
        end
      ),
      cost_usd: (if $unpriced == 0 and $unknown == 0 then $known else null end),
      known_cost_usd: $known,
      call_count: ($usage | map(.call_count) | add),
      input_tokens: ($usage | map(.input_tokens) | add),
      output_tokens: ($usage | map(.output_tokens) | add),
      unpriced_calls: $unpriced,
      usage_unknown_calls: $unknown,
      source_summaries: ($summaries | split("\n") | map(select(. != ""))),
      reason: null
    }
  ' "${records[@]}" > "$output"
