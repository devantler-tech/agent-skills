#!/usr/bin/env bash
# Exercise the shipped assessment, not a second implementation of its ranking.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
# Hand-checked: high priority must beat an older, shorter low-priority item.
printf '%s\n' '{"version":1,"observedAt":1000,"complete":true,"maxAgeSeconds":60,"counts":{"inProgress":0,"inReview":0,"readyToMerge":0,"verifying":0},"limits":{"inProgress":12,"inReview":12,"readyToMerge":6,"verifying":3},"candidates":[{"id":"old","status":"Ready","actionable":true,"incident":false,"priority":3,"value":1,"urgency":1,"riskReduction":1,"unblocks":1,"effort":1,"readySince":10,"startedAt":null,"evidence":"selection/old"},{"id":"valuable","status":"Ready","actionable":true,"incident":false,"priority":1,"value":3,"urgency":3,"riskReduction":2,"unblocks":2,"effort":3,"readySince":900,"startedAt":null,"evidence":"selection/valuable"}]}' > "$tmp/base.json"
check() {
  local name=$1 expression=$2 wanted=$3
  jq "$expression" "$tmp/base.json" > "$tmp/input.json"
  bash "$root/select-work.sh" --now 1000 "$tmp/input.json" > "$tmp/result.json" || fail "$name: assessment failed"
  jq -e "$wanted" "$tmp/result.json" >/dev/null || fail "$name: wrong decision"
  printf 'PASS: %s\n' "$name"
}
check 'value before age and size' '.' '.decision == "PULL" and .id == "valuable"'
check 'finish merge-ready work' '.candidates[0].status="Ready to Merge" | .candidates[0].startedAt=50' '.decision == "FINISH" and .id == "old"'
check 'due verification before review' '.candidates[0].status="Verifying" | .candidates[0].startedAt=50 | .candidates[1].status="In Review" | .candidates[1].startedAt=60' '.decision == "FINISH" and .id == "old"'
check 'blocked work is not a finish action' '.candidates[0].status="In Review" | .candidates[0].startedAt=50 | .candidates[0].actionable=false' '.decision == "PULL" and .id == "valuable"'
for column in inProgress inReview readyToMerge verifying; do
  check "full $column stops starts" ".counts.$column=.limits.$column" '.decision == "HOLD" and .id == null'
done
check 'Icebox is not implementable' '.candidates |= map(.status="Icebox")' '.decision == "REFINE" and .id == null'
check 'Backlog is not implementable' '.candidates |= map(.status="Backlog")' '.decision == "REFINE" and .id == null'
check 'comparable work ages fairly' '.candidates[1].priority=3 | .candidates[1].value=1 | .candidates[1].urgency=1 | .candidates[1].riskReduction=1 | .candidates[1].unblocks=1 | .candidates[1].effort=1' '.decision == "PULL" and .id == "old"'
check 'end-to-end effort within priority' '.candidates[0].priority=1 | .candidates[0].value=3 | .candidates[0].urgency=3 | .candidates[0].riskReduction=2 | .candidates[0].unblocks=2' '.decision == "PULL" and .id == "old"'
check 'parked work retains start age and is resumed' '.candidates[0].startedAt=50' '.decision == "FINISH" and .id == "old" and .ageSeconds == 950'
check 'incident preempts capacity' '.counts.verifying=3 | .candidates[0].incident=true | .candidates[0].status="Backlog"' '.decision == "EXPEDITE" and .id == "old"'
check 'incomplete evidence stops starts' '.complete=false' '.decision == "HOLD" and .id == null'
check 'stale evidence stops starts' '.observedAt=900' '.decision == "HOLD" and .id == null'
check 'unknown started action blocks descent' '.candidates[0].status="In Review" | .candidates[0].startedAt=50 | .candidates[0].actionable=null' '.decision == "HOLD" and .id == null'
check 'no priority defaults' '.candidates[0].priority=null' '.decision == "HOLD" and .id == null'
check 'finish without intake estimates' '.candidates[0] |= (.status="In Review" | .startedAt=50 | .value=null | .urgency=null | .riskReduction=null | .unblocks=null | .effort=null)' '.decision == "FINISH" and .id == "old"'
check 'missing Ready estimate blocks intake' '.candidates[0].effort=null' '.decision == "HOLD" and .id == null'
check 'future observation is not fresh' '.observedAt=1001' '.decision == "HOLD" and .id == null'
# Invalid inputs cannot emit even a partial favorable result.
for expression in '.version=2' '.limits.verifying=0' '.counts.verifying=-1' '.candidates += [.candidates[0]]' '.candidates[0].readySince=1001'; do
  jq "$expression" "$tmp/base.json" > "$tmp/input.json"
  if bash "$root/select-work.sh" --now 1000 "$tmp/input.json" > "$tmp/result.json" 2> "$tmp/error"; then fail 'invalid evidence accepted'; fi
  [[ ! -s "$tmp/result.json" ]] || fail 'invalid evidence emitted a result'
done
sed 's/"complete":true/"complete":false,"complete":true/' "$tmp/base.json" > "$tmp/input.json"
if bash "$root/select-work.sh" --now 1000 "$tmp/input.json" > "$tmp/result.json" 2> "$tmp/error"; then fail 'repeated field accepted'; fi
[[ ! -s "$tmp/result.json" ]] || fail 'repeated field emitted a result'
for mutation in '.status="Ready to Merge"' '.status="In Review"'; do
  check "finish $mutation without priority" ".candidates[0] |= ($mutation | .startedAt=50 | .priority=null)" '.decision == "FINISH" and .id == "old"'
done
