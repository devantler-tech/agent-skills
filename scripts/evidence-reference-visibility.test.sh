#!/usr/bin/env bash
# Exercise actual standalone evaluators with visibly ambiguous evidence identities.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0 passed=0
refuse() {
  local name=$1 filter=$2 input=$3
  shift 3
  if jq --stream -s "$@" -f "$filter" "$input" > "$work/output" 2> "$work/error" || [ -s "$work/output" ]; then
    printf 'FAIL %s\n' "$name"; failed=$((failed+1))
  else passed=$((passed+1)); fi
}
brief="$root/product-engineering/scripts/accountability-brief.jq"
proof="$root/product-engineering/scripts/check-evidence.jq"
for mark in '\u034f' '\ufe0f' '\u115f' '\u3164' '\U000e0100'; do
  # jq JSON escapes use a surrogate pair for the supplementary variation selector.
  [ "$mark" != '\U000e0100' ] || mark='\udb40\udd00'
  jq ".synthetic=false | .evidence[].source |= sub(\"example://\";\"example:${mark}//\")" \
    "$root/product-engineering/references/accountability-product.json" > "$work/brief.json"
  for mode in check render; do refuse "invisible brief $mark $mode" "$brief" "$work/brief.json" --arg mode "$mode"; done
done
for ref in 'fixture://run-a ' ' fixture://run-a' 'fixture://run-a\n' 'fixture://run-a\u034f' 'fixture://run-a\ufe0f'; do
  jq ".evidence[1].uri=\"$ref\"" "$root/product-engineering/references/evidence-example.json" > "$work/proof.json"
  refuse "ambiguous measurement $ref" "$proof" "$work/proof.json" --arg now 2026-09-24T00:00:00Z
done
# Visible international references remain exact and support distinct observations.
for field in '.baseline.id' '.baseline.revision' '.candidate.id' '.candidate.revision' '.alternatives[0].id' '.plan.record' '.rollback.procedure' '.plan.measures[0].id' '.evidence[0].id' '.evidence[0].revision' '.observations[0].id' '.observations[0].evidenceId' '.observations[0].values[0].measure'; do
  jq "$field += \"\\u202e\"" "$root/product-engineering/references/evidence-example.json" > "$work/proof.json"
  refuse "invisible machine identity $field" "$proof" "$work/proof.json" --arg now 2026-09-24T00:00:00Z
done
jq '.candidate.id="測定-é"' "$root/product-engineering/references/evidence-example.json" > "$work/proof.json"
jq --stream -s --arg now 2026-09-24T00:00:00Z -f "$proof" "$work/proof.json" > "$work/output"
jq -e '.decision=="ADOPT" and .authority=="assessment-only"' "$work/output" >/dev/null
passed=$((passed+1))
jq '.evidence[1].uri="artifact://測定-é"' "$root/product-engineering/references/evidence-example.json" > "$work/proof.json"
jq --stream -s --arg now 2026-09-24T00:00:00Z -f "$proof" "$work/proof.json" > "$work/output"
jq -e '.decision=="ADOPT" and .authority=="assessment-only"' "$work/output" >/dev/null
passed=$((passed+1))
jq '.synthetic=false | .evidence[].source |= sub("example://";"artifact://測定-é/")' "$root/product-engineering/references/accountability-product.json" > "$work/brief.json"
jq --stream -s --arg mode check -f "$brief" "$work/brief.json" > "$work/output"
jq -e '.status=="STRUCTURALLY_VALID" and .authority=="none"' "$work/output" >/dev/null
passed=$((passed+1))
printf 'reference visibility: %s passes, %s failures\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
