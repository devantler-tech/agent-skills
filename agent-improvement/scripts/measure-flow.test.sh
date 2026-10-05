#!/usr/bin/env bash
# Exercise the installed flow entrypoint against real retained-evidence bytes.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
example="$script_dir/../references/flow-example.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$script_dir/measure-flow.sh" "$example" > "$work/result.json"
jq -e '
  .version == 1
  and .run.id == "synthetic-run"
  and .artifactMix == {
    complete: true,
    unique: 2,
    easy: 1,
    substantive: 1,
    unknown: 0,
    revisits: 1,
    easyShare: 0.5
  }
' "$work/result.json" >/dev/null

printf '{"broken":' > "$work/malformed.json"
rc=0
bash "$script_dir/measure-flow.sh" "$work/malformed.json" > "$work/out" 2> "$work/err" || rc=$?
[[ $rc -eq 2 && ! -s $work/out && -s $work/err ]]

# Every identity participates in a join, including evidence and rubric pointers.
# Refuse invisible or ambiguous bytes rather than silently making another artifact.
paths='[["run","id"],["run","instance"],["run","evidence"],["run","scoringVersion"],
 ["artifacts",2,"id"],["artifacts",0,"evidence"],["selections",0,"id"],
 ["selections",0,"evidence"],["selections",0,"selectedId"],
 ["selections",0,"candidates",0,"id"],["selections",0,"candidates",0,"evidence"]]'
refuse() {
  local rc=0
  bash "$script_dir/measure-flow.sh" "$work/input.json" > "$work/out" 2> "$work/err" || rc=$?
  if [[ $rc -ne 2 || -s $work/out || ! -s $work/err ]]; then
    printf 'expected refusal: %s (exit %s)\n' "$1" "$rc" >&2
    return 1
  fi
}
while IFS= read -r path; do
  while IFS= read -r value; do
    jq --argjson path "$path" --argjson value "$value" 'setpath($path; $value)' "$example" > "$work/input.json"
    if [[ $path == '["selections",0,"selectedId"]' ]]; then
      jq '.selections[0].candidatesComplete = false' "$work/input.json" > "$work/partial.json"
      mv "$work/partial.json" "$work/input.json"
    fi
    refuse "identity $path = $value"
  done < <(jq -cn '"status\u200b", "status\u202e", "status\u034f", "status\u3164",
    "status\u0000", "status\u007f", "status\u0085", "status\u00a0", "status\t",
    " status", "status ", "two  words"')
done < <(jq -cn "${paths}[]")

# Visible international identities, ordinary single spaces and literal U+FFFD remain exact.
jq --argjson paths "$paths" 'reduce $paths[] as $path (.; setpath($path; "東京 café �"))
  | .selections[0].candidatesComplete = false' "$example" > "$work/input.json"
bash "$script_dir/measure-flow.sh" "$work/input.json" > "$work/out"
jq -e '.run.id == "東京 café �" and .selections[0].state == "UNKNOWN"' "$work/out" >/dev/null

# Creation and completed-run start facts must agree across independent selections.
jq '.selections += [.selections[0] | .id = "selection-2" | .at = 120]' "$example" > "$work/cohort.json"
jq '.selections[1].candidates[0].createdAt = 90' "$work/cohort.json" > "$work/input.json"
refuse 'contradictory creation timestamp'
jq '.selections[1].candidates[0].startedByEnd = true' "$work/cohort.json" > "$work/input.json"
refuse 'contradictory completed-run start state'

bash "$script_dir/measure-flow.sh" "$work/cohort.json" > "$work/out"
jq -e '[.selections[].oldestUnstarted.ageSeconds] == [100,110]' "$work/out" >/dev/null

# Actionability is observed at selection time and may change; unknown end facts may
# gain a conclusive observation without inventing a contradiction or filling a gap.
while IFS=$'\t' read -r mutation expected; do
  jq "$mutation" "$work/cohort.json" > "$work/input.json"
  bash "$script_dir/measure-flow.sh" "$work/input.json" > "$work/out"
  jq -e "$expected" "$work/out" >/dev/null
done <<'CASES'
.selections[1].candidates[0].actionable = false	[.selections[].state] == ["MEASURED","NONE"] and .selections[0].oldestUnstarted.ageSeconds == 100 and .selections[1].oldestUnstarted == null
.selections[0].candidates[0].startedByEnd = null	[.selections[].state] == ["UNKNOWN","MEASURED"] and .selections[0].oldestUnstarted == null and .selections[1].oldestUnstarted.ageSeconds == 110
.selections[].candidates[0].startedByEnd = true | .selections[0].candidates[0].startedByEnd = null	[.selections[].state] == ["UNKNOWN","NONE"] and all(.selections[]; .oldestUnstarted == null)
.selections[1].candidatesComplete = false	[.selections[].state] == ["MEASURED","UNKNOWN"] and .selections[0].oldestUnstarted.ageSeconds == 100 and .selections[1].oldestUnstarted == null
CASES

printf 'measure-flow entrypoint: PASS (identity matrix and candidate coherence)\n'
