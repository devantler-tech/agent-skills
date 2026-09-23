#!/usr/bin/env bash
# Exercise the shipped calculator with independently hand-counted telemetry.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
calculator="$root/agent-improvement/scripts/measure-flow.jq"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/base.json" <<'JSON'
{
  "version": 1,
  "run": {"id":"run-1","role":"engineer","instance":"local","scoringVersion":"fixture-rubric-v1","startedAt":100,"endedAt":200,"evidence":"run/1"},
  "artifactsComplete": true,
  "selectionsComplete": true,
  "artifacts": [
    {"id":"change/1","class":"substantive","evidence":"event/1"},
    {"id":"comment/1","class":"easy","evidence":"event/2"},
    {"id":"comment/1","class":"easy","evidence":"event/3"},
    {"id":"unknown/1","class":"unknown","evidence":"event/4"}
  ],
  "selections": [{
    "id":"selection-1","at":110,"selectedId":"young","selectedClass":"easy",
    "evidence":"selection/1","candidatesComplete":true,
    "candidates":[
      {"id":"old","createdAt":10,"actionable":true,"startedByEnd":false,"evidence":"join/old"},
      {"id":"young","createdAt":100,"actionable":true,"startedByEnd":true,"evidence":"join/young"},
      {"id":"blocked","createdAt":0,"actionable":false,"startedByEnd":false,"evidence":"join/blocked"}
    ]
  }]
}
JSON
passed=0
# Run one valid-input case against the real calculator and fail on a mismatched result.
# Arguments: case name, input jq transformation, expected output jq predicate.
check() {
  local name=$1 change=$2 expected=$3
  jq "$change" "$work/base.json" > "$work/input.json"
  jq -e -s -f "$calculator" "$work/input.json" > "$work/output.json"
  jq -e "$expected" "$work/output.json" > /dev/null || {
    printf 'FAIL: %s\n' "$name" >&2
    cat "$work/output.json" >&2
    exit 1
  }
  passed=$((passed + 1))
}
# Require malformed evidence to fail without emitting a partial scorecard.
# Arguments: case name and input jq transformation.
reject() {
  local name=$1 change=$2
  jq "$change" "$work/base.json" > "$work/input.json"
  if jq -e -s -f "$calculator" "$work/input.json" > "$work/output.json" 2> "$work/error"; then
    printf 'FAIL: accepted %s\n' "$name" >&2; exit 1
  fi
  [ ! -s "$work/output.json" ] || { printf 'FAIL: partial result for %s\n' "$name" >&2; exit 1; }
  passed=$((passed + 1))
}

check 'deduplicate artifacts without hiding unclassified evidence' '.' \
  '.artifactMix == {complete:true,unique:3,easy:1,substantive:1,unknown:1,revisits:1,easyShare:null}'
check 'oldest actionable candidate excludes blocked and selected work' '.' \
  '.selections[0].state == "MEASURED" and .selections[0].oldestUnstarted == {id:"old",ageSeconds:100,evidence:"join/old"}'
check 'known artifact mix is hand-counted' '.artifacts |= map(select(.class != "unknown"))' \
  '.artifactMix.easyShare == 0.5 and .artifactMix.unique == 2'
check 'partial artifact census has no ratio' '.artifactsComplete=false' \
  '.artifactMix.complete == false and .artifactMix.easyShare == null'
check 'partial selection census remains visible even with measured observations' '.selectionsComplete=false' \
  '.selectionsComplete == false and .selections[0].state == "MEASURED"'
check 'partial candidates cannot prove an oldest issue' '.selections[0].candidatesComplete=false' \
  '.selections[0].state == "UNKNOWN" and .selections[0].oldestUnstarted == null and .selections[0].candidatesComplete == false'
check 'unknown actionability cannot be read as false' '.selections[0].candidates[0].actionable=null' \
  '.selections[0].state == "UNKNOWN" and .selections[0].candidatesComplete == true'
check 'unknown end state cannot be read as started' '.selections[0].candidates[0].startedByEnd=null' \
  '.selections[0].state == "UNKNOWN"'
check 'work started later in the same run was not left unstarted' '.selections[0].candidates[0].startedByEnd=true' \
  '.selections[0].state == "NONE" and .selections[0].oldestUnstarted == null'
check 'substantive selections are not easy-choice samples' '.selections[0].selectedClass="substantive"' \
  '.selections[0].state == "NOT-APPLICABLE"'
check 'unknown selection class does not disappear' '.selections[0].selectedClass="unknown"' \
  '.selections[0].state == "UNKNOWN"'
check 'zero artifacts does not create a zero percent ratio' '.artifacts=[]' \
  '.artifactMix.unique == 0 and .artifactMix.easyShare == null'
check 'equal-age candidates use a deterministic identifier tie-break' \
  '.selections[0].candidates += [{id:"aaa",createdAt:10,actionable:true,startedByEnd:false,evidence:"join/aaa"}]' \
  '.selections[0].oldestUnstarted.id == "aaa"'
check 'scoring definition version survives output unchanged' '.run.scoringVersion="fixture-rubric-v2"' \
  '.run.scoringVersion == "fixture-rubric-v2"'
reject 'missing scoring definition version' 'del(.run.scoringVersion)'
reject 'blank scoring definition version' '.run.scoringVersion="  "'
reject 'non-string scoring definition version' '.run.scoringVersion=2'
reject 'contradictory duplicate artifact classifications' '.artifacts[2].class="substantive"'
reject 'duplicate selection IDs' '.selections += .selections'
reject 'duplicate candidate IDs' '.selections[0].candidates += [.selections[0].candidates[0]]'
reject 'missing coverage flag' 'del(.artifactsComplete)'
reject 'missing selection coverage flag' 'del(.selectionsComplete)'
reject 'missing candidate actionability' 'del(.selections[0].candidates[0].actionable)'
reject 'missing source evidence' '.selections[0].candidates[0].evidence=""'
reject 'blank source evidence' '.run.evidence="   "'
reject 'complete candidate census omits selected work' '.selections[0].candidates |= map(select(.id != "young"))'
reject 'selection outside the run' '.selections[0].at=201'
reject 'future candidate creation time' '.selections[0].candidates[0].createdAt=111'
reject 'unfinished run' '.run.endedAt=null'
reject 'unknown schema version' '.version=2'
reject 'more than one input document' '., .'
printf 'agent improvement flow: PASS (%s cases)\n' "$passed"
