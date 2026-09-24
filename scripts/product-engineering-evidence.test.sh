#!/usr/bin/env bash
# Test the shipped evaluator as a user would, with actual JSON data and no network.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
filter="$root/product-engineering/scripts/check-evidence.jq"
example="$root/product-engineering/references/evidence-example.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
now=2026-09-24T00:00:00Z
passed=0
check() {
  local name=$1 expected=$2 mutation=$3
  jq "$mutation" "$example" > "$work/input.json"
  jq -s --arg now "$now" -f "$filter" "$work/input.json" > "$work/output.json"
  jq -e --arg expected "$expected" '.decision == $expected and (.reasons | type == "array")' "$work/output.json" >/dev/null || {
    printf 'FAIL %s\n' "$name"; cat "$work/output.json"; exit 1;
  }
  passed=$((passed + 1))
}
invalid() {
  local name=$1 mutation=$2
  jq "$mutation" "$example" > "$work/input.json"
  if jq -s --arg now "$now" -f "$filter" "$work/input.json" > "$work/output.json" 2> "$work/error"; then
    printf 'FAIL malformed bundle accepted: %s\n' "$name"; exit 1
  fi
  passed=$((passed + 1))
}
check 'complete repeatable improvement' ADOPT '.'
check 'faster but less reliable' REJECT '.observations[].values[1].candidate = {lower:980000,upper:990000}'
check 'unproven rollback' HOLD '.evidence |= map(select(.kind != "rollback"))'
check 'failed rollback drill' REJECT '(.evidence[] | select(.kind == "rollback")).result = "fail"'
check 'missing live observation' HOLD '.evidence |= map(select(.kind != "live"))'
check 'CI alone is insufficient' HOLD '.evidence |= map(select(.kind == "static"))'
check 'stale evidence' HOLD '.evidence[0].expiresAt = "2026-09-23T00:00:00Z"'
check 'expiry boundary' HOLD '.evidence[0].expiresAt = "2026-09-24T00:00:00Z"'
check 'future observation' HOLD '.evidence[0].observedAt = "2026-09-25T00:00:00Z"'
check 'wrong candidate revision' HOLD '.evidence[0].revision = "release-3"'
check 'failure from another revision is not this candidate outcome' HOLD '.evidence[0].revision = "release-3" | .evidence[0].result = "fail" | .observations[0].values[1].candidate = {lower:980000,upper:990000}'
check 'wrong baseline revision' HOLD '.evidence[0].baselineRevision = "release-0"'
check 'post-hoc registration' HOLD '.plan.registeredAt = "2026-09-03T00:00:00Z"'
check 'unmeasured protected floor' HOLD '.observations[0].values |= map(select(.measure != "reliability"))'
check 'unknown baseline measurement' HOLD '.observations[0].values[0].baseline = null'
check 'insufficient repeats' HOLD '.observations = [.observations[0]]'
check 'repeat IDs do not create new evidence' HOLD '.observations[1].evidenceId = "run-a"'
check 'uncertainty erases improvement' HOLD '.observations[].values[0].candidate = {lower:80,upper:100}'
check 'improvement must repeat' REJECT '.observations[1].values[0].candidate = {lower:99,upper:100}'
check 'unprotected regression still matters' REJECT '.plan.measures[1].protected = false | .observations[].values[1].candidate = {lower:980000,upper:990000}'
check 'unknown result' HOLD '.evidence[0].result = "unknown"'
check 'unknown assumption' HOLD '.assumptions[0].state = "unknown"'
check 'refuted assumption' REJECT '.assumptions[0].state = "refuted"'
check 'overdue observation' HOLD '.observation.nextCheck = "2026-09-20T00:00:00Z"'
check 'no independent or adversarial review evidence' HOLD '.falsification.evidenceId = "static"'
check 'holdout used for tuning' HOLD '(.evidence[] | select(.kind == "holdout")).usedForTuning = true'
check 'unknown holdout isolation' HOLD '(.evidence[] | select(.kind == "holdout")) |= del(.usedForTuning)'
check 'uncertain protected floor' HOLD '.observations[0].values[1].candidate = {lower:994000,upper:999000}'
check 'same source under distinct IDs' HOLD '.evidence[1].uri = .evidence[0].uri'
invalid 'missing baseline' 'del(.baseline)'
invalid 'model confidence as proof' '.evidence[0].provenance = "model-confidence"'
invalid 'unknown schema' '.schemaVersion = 2'
invalid 'duplicate measurement' '.plan.measures += [.plan.measures[0]]'
invalid 'duplicate evidence' '.evidence += [.evidence[0]]'
invalid 'reversed interval' '.observations[0].values[0].candidate = {lower:85,upper:80}'
invalid 'numeric-looking string' '.observations[0].values[0].candidate.lower = "80"'
invalid 'no objectives' '.plan.measures[].objective = false'
invalid 'no protected dimensions' '.plan.measures[].protected = false'
invalid 'zero improvement threshold' '.plan.measures[0].minImprovement = 0'
invalid 'unbounded regression' '.plan.measures[0].maxRegression = -1'
invalid 'invalid timestamp' '.evidence[0].observedAt = "yesterday"'
invalid 'rollback to another candidate' '.rollback.targetRevision = "release-3"'
invalid 'missing uncertainty method' 'del(.plan.measures[0].uncertaintyMethod)'
invalid 'empty input' 'empty'
invalid 'multiple input bundles' '., .'

if jq -s --arg now yesterday -f "$filter" "$example" > "$work/output.json" 2> "$work/error"; then
  printf 'FAIL invalid evaluation time accepted\n'; exit 1
fi
passed=$((passed + 1))

# The package works after installation, independent of the repository's scripts directory.
cp -R "$root/product-engineering" "$work/installed"
(cd "$work" && jq -s --arg now "$now" -f installed/scripts/check-evidence.jq installed/references/evidence-example.json) > "$work/installed.json"
jq -e '.decision == "ADOPT"' "$work/installed.json" >/dev/null
passed=$((passed + 1))
printf 'product engineering evidence: PASS (%s cases)\n' "$passed"
