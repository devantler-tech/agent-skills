#!/usr/bin/env bash
# Exercise the shipped synthetic kata example through the canonical raw-byte entrypoint.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
improvement=${AGENT_IMPROVEMENT_DIR:-$root/agent-improvement}
engineering=${PRODUCT_ENGINEERING_DIR:-$root/product-engineering}
example="$improvement/references/kata-evidence-example.json"
[[ -r $example ]] || { printf 'FAIL missing published kata example\n' >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0
check() {
  local name=$1 want=$2 mutation=$3
  jq "$mutation" "$example" > "$work/bundle.json"
  bash "$engineering/scripts/check-evidence.sh" --now 2026-09-24T00:00:00Z "$work/bundle.json" > "$work/result.json"
  jq -e --arg want "$want" '.decision==$want and .authority=="assessment-only"' "$work/result.json" >/dev/null ||
    { printf 'FAIL %s\n' "$name"; cat "$work/result.json"; exit 1; }
  passed=$((passed+1))
}
check 'complete bounded synthetic kata' ADOPT '.'
check 'delivery merge without deployed observation is inconclusive' HOLD '.evidence |= map(select(.kind!="deployment" and .kind!="live"))'
check 'faster checkpoint cannot buy missing outcome measurements' REJECT '.observations[0].values[1].candidate={lower:99,upper:99}'
check 'integrity violation stops adoption despite speed' REJECT '.observations[0].values[2].candidate={lower:1,upper:1}'
check 'unobserved companion floor is inconclusive' HOLD '.observations[0].values[2].candidate=null'
check 'one sample cannot meet registered repeat floor' HOLD '.observations |= .[0:1]'
check 'retrospective registration is inconclusive' HOLD '.plan.registeredAt="2026-09-03T00:00:00Z"'
check 'unknown candidate attribution is inconclusive' HOLD '.evidence[0].revision="unresolved"'
check 'failed recovery stops adoption' REJECT '(.evidence[] | select(.kind=="rollback")).result="fail"'
check 'expired evidence cannot renew itself' HOLD '.evidence[0].expiresAt="2026-09-23T00:00:00Z"'
check 'observed regression survives an unrelated evidence gap' REJECT '.observations[0].values[2].candidate={lower:1,upper:1} | .evidence |= map(select(.kind!="rollback"))'
printf 'PASS %s improvement-kata evidence scenarios\n' "$passed"
