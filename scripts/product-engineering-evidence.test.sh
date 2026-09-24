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
# Run a named fixture mutation and verify its decision plus an optional specific diagnostic.
# The diagnostic prevents another missing prerequisite from masking removal of the intended guard.
check() {
  local name=$1 expected=$2 mutation=$3 reason=${4:-}
  jq "$mutation" "$example" > "$work/input.json"
  jq -s --arg now "$now" -f "$filter" "$work/input.json" > "$work/output.json"
  jq -e --arg expected "$expected" --arg reason "$reason" '
    .decision == $expected and (.reasons | type == "array")
    and ($reason == "" or (.reasons | index($reason) != null))
  ' "$work/output.json" >/dev/null || {
    printf 'FAIL %s\n' "$name"; cat "$work/output.json"; exit 1;
  }
  passed=$((passed + 1))
}
# Assert that a malformed bundle fails evaluation, rather than emitting a successful assessment.
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
check 'expired failed rollback stays negative' REJECT '(.evidence[] | select(.kind == "rollback")) |= (.result = "fail" | .expiresAt = "2026-09-23T00:00:00Z")' 'failed rollback evidence: rollback'
check 'expired protected floor breach stays negative' REJECT '.evidence[0].expiresAt = "2026-09-23T00:00:00Z" | .observations[0].values[1].candidate = {lower:980000,upper:990000}' 'protected floor breached: reliability'
check 'expired material regression stays negative' REJECT '.evidence[0].expiresAt = "2026-09-23T00:00:00Z" | .observations[0].values[0].candidate = {lower:110,upper:115}' 'material regression: latency'
check 'missing live observation' HOLD '.evidence |= map(select(.kind != "live"))'
check 'CI alone is insufficient' HOLD '.evidence |= map(select(.kind == "static"))'
check 'stale evidence' HOLD '.evidence[0].expiresAt = "2026-09-23T00:00:00Z"' 'expired evidence: run-a'
check 'expiry boundary' HOLD '.evidence[0].expiresAt = "2026-09-24T00:00:00Z"' 'expired evidence: run-a'
check 'future observation' HOLD '.evidence[0].observedAt = "2026-09-25T00:00:00Z"' 'observation outside experiment window: run-a'
check 'wrong candidate revision' HOLD '.evidence[0].revision = "release-3"' 'revision mismatch: run-a'
check 'failure from another revision is not this candidate outcome' HOLD '.evidence[0].revision = "release-3" | .evidence[0].result = "fail" | .observations[0].values[1].candidate = {lower:980000,upper:990000}'
check 'wrong baseline revision' HOLD '.evidence[0].baselineRevision = "release-0"' 'baseline mismatch: run-a'
check 'post-hoc registration' HOLD '.plan.registeredAt = "2026-09-03T00:00:00Z"'
check 'unmeasured protected floor' HOLD '.observations[0].values |= map(select(.measure != "reliability"))'
check 'unknown baseline measurement' HOLD '.observations[0].values[0].baseline = null'
check 'insufficient repeats' HOLD '.observations = [.observations[0]]'
check 'repeat IDs do not create new evidence' HOLD '.observations[1].evidenceId = "run-a"'
check 'uncertainty erases improvement' HOLD '.observations[].values[0].candidate = {lower:80,upper:100}'
check 'improvement must repeat' REJECT '.observations[1].values[0].candidate = {lower:99,upper:100}'
check 'conclusive objective failure survives missing rollback' REJECT '.observations[1].values[0].candidate = {lower:99,upper:100} | .evidence |= map(select(.kind != "rollback"))' 'no objective met its repeatable improvement threshold'
check 'conclusive objective failure survives expiry' REJECT '.observations[1].values[0].candidate = {lower:99,upper:100} | .evidence[0].expiresAt = "2026-09-23T00:00:00Z"' 'no objective met its repeatable improvement threshold'
check 'incomplete repeats cannot establish objective failure' HOLD '.observations = [.observations[0]] | .observations[0].values[0].candidate = {lower:99,upper:100}' 'insufficient repeats'
check 'unmeasured objective cannot establish objective failure' HOLD '.observations[1].values[0].candidate = {lower:99,upper:100} | .observations[0].values[0].candidate = null' 'unmeasured dimension: repeat-a'
check 'an inconclusive second objective prevents conclusive rejection' HOLD '.plan.measures[1].objective = true | .plan.measures[1].minImprovement = 500 | .observations[1].values[0].candidate = {lower:99,upper:100} | .evidence |= map(select(.kind != "rollback"))' 'missing rollback evidence'
check 'every measurement must have numeric observations' HOLD '.evidence += [.evidence[0] | .id = "run-c" | .uri = "fixture://run-c"]' 'missing observation for measurement: run-c'
check 'omitted repeats cannot establish objective failure' HOLD '.evidence += [.evidence[0] | .id = "run-c" | .uri = "fixture://run-c"] | .observations[1].values[0].candidate = {lower:99,upper:100}' 'missing observation for measurement: run-c'
check 'all recorded repeats can satisfy adoption' ADOPT '.evidence += [.evidence[0] | .id = "run-c" | .uri = "fixture://run-c"] | .observations += [.observations[0] | .id = "repeat-c" | .evidenceId = "run-c"]'
check 'unprotected regression still matters' REJECT '.plan.measures[1].protected = false | .observations[].values[1].candidate = {lower:980000,upper:990000}'
check 'unknown result' HOLD '.evidence[0].result = "unknown"' 'unknown result: run-a'
check 'unknown assumption' HOLD '.assumptions[0].state = "unknown"'
check 'refuted assumption' REJECT '.assumptions[0].state = "refuted"'
check 'inconclusive evidence cannot refute an assumption' HOLD '.assumptions[0].state = "refuted" | (.evidence[] | select(.id == "holdout")).result = "unknown"' 'unknown result: holdout'
check 'expired refutation stays negative' REJECT '.assumptions[0].state = "refuted" | (.evidence[] | select(.id == "holdout")).expiresAt = "2026-09-23T00:00:00Z"' 'refuted assumption: The held-out workload represents the intended users'
check 'another revision cannot refute this candidate' HOLD '.assumptions[0].state = "refuted" | (.evidence[] | select(.id == "holdout")).revision = "release-3"' 'revision mismatch: holdout'
check 'overdue observation' HOLD '.observation.nextCheck = "2026-09-20T00:00:00Z"'
check 'next check precedes earliest expiry' ADOPT '.evidence[0].expiresAt = "2026-09-25T00:00:00Z" | .observation.nextCheck = "2026-09-24T23:59:59Z"'
check 'next check at earliest expiry' HOLD '.evidence[0].expiresAt = "2026-09-25T00:00:00Z" | .observation.nextCheck = "2026-09-25T00:00:00Z"' 'observation check must precede evidence expiry: run-a'
check 'next check after earliest expiry' HOLD '.evidence[0].expiresAt = "2026-09-25T00:00:00Z"' 'observation check must precede evidence expiry: run-a'
check 'no independent or adversarial review evidence' HOLD '.falsification.evidenceId = "static"'
check 'holdout used for tuning' HOLD '(.evidence[] | select(.kind == "holdout")).usedForTuning = true'
check 'unknown holdout isolation' HOLD '(.evidence[] | select(.kind == "holdout")) |= del(.usedForTuning)'
check 'uncertain protected floor' HOLD '.observations[0].values[1].candidate = {lower:994000,upper:999000}'
check 'same source under distinct IDs' HOLD '.evidence[1].uri = .evidence[0].uri'
check 'live outcome requires earlier deployment' HOLD '(.evidence[] | select(.kind == "live")).observedAt = "2026-09-02T10:00:00Z"' 'deployment must precede live evidence: live'
check 'rollback drill requires earlier deployment' HOLD '(.evidence[] | select(.kind == "rollback")).observedAt = "2026-09-02T10:00:00Z"' 'deployment must precede rollback evidence: rollback'
check 'deployment reference must name deployment evidence' HOLD '(.evidence[] | select(.kind == "live")).deploymentEvidenceId = "static"' 'deployment must precede live evidence: live'
check 'inconclusive deployment cannot establish ordering' HOLD '(.evidence[] | select(.kind == "deployment")).result = "unknown"' 'deployment must precede live evidence: live'
check 'rollback at deployment time has no proven ordering' HOLD '(.evidence[] | select(.kind == "rollback")).observedAt = "2026-09-04T10:00:00Z"' 'deployment must precede rollback evidence: rollback'
check 'observation window must finish' HOLD '.observation.window.endedAt = "2026-09-25T00:00:00Z"' 'observation window has not elapsed'
check 'live artifact must cover the complete window' HOLD '.observation.window.endedAt = "2026-09-06T00:00:00Z"' 'live evidence does not cover observation window'
check 'window must follow its deployment' HOLD '.observation.window.startedAt = "2026-09-03T00:00:00Z"' 'observation window precedes deployment'
check 'window must belong to the experiment' HOLD '.observation.window.startedAt = "2026-09-01T00:00:00Z"' 'observation window starts before experiment'
check 'observation must reference live evidence' HOLD '.observation.evidenceId = "behavior"' 'missing observation window evidence'
check 'observation window can end now' ADOPT '.observation.window.endedAt = "2026-09-24T00:00:00Z" | (.evidence[] | select(.id == "live")).observedAt = "2026-09-24T00:00:00Z"'
invalid 'missing baseline' 'del(.baseline)'
# shellcheck disable=SC2016 # $id is a jq binding, not a shell variable.
invalid 'baseline alternative is required' '.baseline.id as $id | .alternatives |= map(select(.id != $id))'
invalid 'observation window needs machine-readable bounds' '.observation.window = "365 days beginning today"'
invalid 'reversed observation window' '.observation.window.startedAt = "2026-09-06T00:00:00Z"'
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
