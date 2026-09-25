#!/usr/bin/env bash
# Exercise the published operational-procedure example with the canonical companion evaluator.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# These overrides also exercise two independently installed skills, without a repository layout.
procedure=${SELF_IMPROVEMENT_DIR:-$root/self-improvement}
engineering=${PRODUCT_ENGINEERING_DIR:-$root/product-engineering}
example="$procedure/references/procedure-evidence-example.json"
filter="$engineering/scripts/check-evidence.jq"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0
check() {
  local name=$1 want=$2 mutation=$3 reason=${4:-}
  jq "$mutation" "$example" > "$work/bundle.json"
  jq -s --arg now 2026-09-24T00:00:00Z -f "$filter" "$work/bundle.json" > "$work/result.json"
  jq -e --arg want "$want" --arg reason "$reason" '
    .decision==$want and .authority=="assessment-only"
    and ($reason=="" or (.reasons | index($reason)!=null))
  ' "$work/result.json" >/dev/null || { printf 'FAIL %s\n' "$name"; cat "$work/result.json"; exit 1; }
  passed=$((passed+1))
}
check 'complete synthetic procedure comparison' ADOPT '.'
check 'faster procedure misses a required outcome' REJECT '.observations[0].values[1].candidate={lower:99,upper:99}' 'protected floor breached: completed-outcomes'
check 'speed cannot compensate for an authority violation' REJECT '.observations[0].values[0].candidate={lower:0,upper:0} | .observations[0].values[2].candidate={lower:1,upper:1}' 'protected floor breached: authority-violations'
check 'unobserved safety outcomes cannot establish adoption' HOLD '.observations[0].values[2].candidate=null'
check 'restoration must be exercised' HOLD '.evidence |= map(select(.kind!="rollback"))' 'missing rollback evidence'
check 'failed recovery remains negative' REJECT '(.evidence[] | select(.kind=="rollback")).result="fail"' 'failed rollback evidence: rollback'
check 'merged definition and CI do not establish improvement' HOLD '.evidence |= map(select(.kind=="static"))'
check 'plan after the first experiment holds replacement' HOLD '.plan.registeredAt="2026-09-03T00:00:00Z"'
check 'candidate must be used before observing its outcome' HOLD '(.evidence[] | select(.kind=="deployment")).observedAt="2026-09-06T00:00:00Z"'
check 'unknown run attribution holds replacement' HOLD '.evidence[0].revision="unresolved"' 'revision mismatch: run-a'
check 'retired evidence cannot renew itself' HOLD '.evidence[0].expiresAt="2026-09-23T00:00:00Z"' 'expired evidence: run-a'
check 'failed own-run measurement survives unrelated gaps' REJECT '.observations[0].values[2].candidate={lower:1,upper:1} | .evidence |= map(select(.kind!="rollback"))' 'protected floor breached: authority-violations'
printf 'PASS %s self-improvement evidence scenarios\n' "$passed"
