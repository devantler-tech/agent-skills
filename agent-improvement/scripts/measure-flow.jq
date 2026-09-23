# Read one completed run with: jq -e -s -f measure-flow.jq evidence.json
# This computes descriptive metrics; evidence authenticity and policy stay with the consumer.
def text: type == "string" and test("\\S");
def timestamp: type == "number" and . >= 0 and floor == .;
def classification: . == "easy" or . == "substantive" or . == "unknown";
def nullable_boolean: type == "boolean" or . == null;
def unique_ids: length == (map(.id) | unique | length);

def valid:
  . as $input
  | type == "object" and .version == 1
  and (.run | type == "object"
    and (.id | text) and (.instance | text) and (.evidence | text)
    and (.scoringVersion | text)
    and (.role == "engineer" or .role == "improver")
    and (.startedAt | timestamp) and (.endedAt | timestamp)
    and .endedAt >= .startedAt)
  and (.artifactsComplete | type == "boolean")
  and (.selectionsComplete | type == "boolean")
  and (.artifacts | type == "array" and all(.[];
    type == "object" and (.id | text) and (.class | classification) and (.evidence | text)))
  and (.artifacts | group_by(.id) | all(.[]; (map(.class) | unique | length) == 1))
  and (.selections | type == "array" and unique_ids and all(.[];
    . as $selection
    | type == "object" and (.id | text) and (.evidence | text)
    and (.at | timestamp) and .at >= $input.run.startedAt and .at <= $input.run.endedAt
    and (.selectedId | text) and (.selectedClass | classification)
    and (.candidatesComplete | type == "boolean")
    and (.candidates | type == "array" and unique_ids and all(.[];
      type == "object" and (.id | text) and (.evidence | text)
      and (.createdAt | timestamp) and .createdAt <= $selection.at
      and has("actionable") and (.actionable | nullable_boolean)
      and has("startedByEnd") and (.startedByEnd | nullable_boolean)))
    and (if .candidatesComplete then any(.candidates[]; .id == $selection.selectedId) else true end)));

def artifact_mix:
  . as $input | (.artifacts | unique_by(.id)) as $artifacts
  | {complete: .artifactsComplete, unique: ($artifacts | length),
     easy: ([$artifacts[] | select(.class == "easy")] | length),
     substantive: ([$artifacts[] | select(.class == "substantive")] | length),
     unknown: ([$artifacts[] | select(.class == "unknown")] | length),
     revisits: (($input.artifacts | length) - ($artifacts | length))}
  | . + {easyShare: (if .complete and .unknown == 0 and .unique > 0
                    then .easy / .unique else null end)};

def selection_metric:
  . as $selection
  | {id, at, evidence, selectedId, selectedClass, candidatesComplete} +
    (if .selectedClass == "unknown" then
       {state: "UNKNOWN", oldestUnstarted: null}
     elif .selectedClass != "easy" then
       {state: "NOT-APPLICABLE", oldestUnstarted: null}
     elif (.candidatesComplete | not) or any(.candidates[];
         .actionable == null or (.actionable == true and .startedByEnd == null)) then
       {state: "UNKNOWN", oldestUnstarted: null}
     else
       ([.candidates[] | select(.id != $selection.selectedId
          and .actionable == true and .startedByEnd == false)]
        | sort_by(.createdAt, .id) | .[0]) as $oldest
       | if $oldest == null then {state: "NONE", oldestUnstarted: null}
         else {state: "MEASURED", oldestUnstarted:
           {id: $oldest.id, ageSeconds: ($selection.at - $oldest.createdAt), evidence: $oldest.evidence}}
         end
     end);

if length != 1 then error("expected exactly one completed-run evidence document")
else .[0]
  | if valid then
      {version: 1, run, artifactMix: artifact_mix, selectionsComplete,
       selections: [.selections[] | selection_metric]}
    else error("invalid flow evidence; retain UNKNOWN, not a zero or a verdict") end
end
