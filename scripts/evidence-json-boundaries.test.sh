#!/usr/bin/env bash
# Read actual raw JSON through each independently installed evidence tool.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0
failed=0
for tool in proof flow brief; do
  case $tool in
    proof) filter="$root/product-engineering/scripts/check-evidence.jq"; example="$root/product-engineering/references/evidence-example.json"; args=(--arg now 2026-09-24T00:00:00Z) ;;
    flow) filter="$root/agent-improvement/scripts/measure-flow.jq"; example="$root/agent-improvement/references/flow-example.json"; args=(--arg unused unused) ;;
    brief) filter="$root/product-engineering/scripts/accountability-brief.jq"; example="$root/product-engineering/references/accountability-product.json"; args=(--arg mode check) ;;
  esac
  for scenario in healthy scalar empty-container disjoint-container escaped nested-array multiple malformed ordinary-slurp; do
    jq -c . "$example" > "$work/input.json"
    case $scenario in
      scalar)
        case $tool in
          proof|brief) sed 's/"result":"pass"/"result":"fail","result":"pass"/' "$work/input.json" > "$work/new" ;;
          flow) sed 's/"artifactsComplete":true/"artifactsComplete":false,"artifactsComplete":true/' "$work/input.json" > "$work/new" ;;
        esac; mv "$work/new" "$work/input.json" ;;
      empty-container) sed 's/^{/{"boundary":{},"boundary":[],/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      disjoint-container) sed 's/^{/{"boundary":{"a":1},"boundary":{"b":2},/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      escaped) sed 's/^{/{"boundary":false,"boun\\u0064ary":true,/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      nested-array) sed 's/^{/{"boundary":[{"a":false,"a":true}],/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      multiple) cat "$example" >> "$work/input.json" ;;
      malformed) printf '\n{"broken":' >> "$work/input.json" ;;
    esac
    rc=0
    stream=(--stream -s); [ "$scenario" != ordinary-slurp ] || stream=(-s)
    jq "${stream[@]}" "${args[@]}" -f "$filter" "$work/input.json" > "$work/output" 2> "$work/error" || rc=$?
    case $scenario in
      scalar|empty-container|disjoint-container|escaped|nested-array)
        if ! grep -q 'repeated decoded field path' "$work/error"; then
          printf 'FAIL missing duplicate-path diagnostic: %s %s\n' "$tool" "$scenario"; failed=$((failed+1))
        fi ;;
    esac
    if { [ "$scenario" = healthy ] && [ "$rc" -eq 0 ] && [ -s "$work/output" ]; } ||
       { [ "$scenario" != healthy ] && [ "$rc" -ne 0 ] && [ ! -s "$work/output" ]; }; then
      passed=$((passed+1))
    else printf 'FAIL %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi
  done
  # The examples repeat names in distinct objects throughout their evidence arrays.
  if [ "$tool" = brief ]; then
    jq --stream -sr --arg mode render -f "$filter" "$example" > "$work/render" 2> "$work/error" || { failed=$((failed+1)); continue; }
    grep -q 'SIMULATED' "$work/render" || failed=$((failed+1))
  fi
done
printf 'raw evidence: %s passes, %s failures\n' "$passed" "$failed"
test "$failed" -eq 0
