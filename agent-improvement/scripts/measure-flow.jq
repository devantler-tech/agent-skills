# Inspect decoded member paths before object reconstruction can overwrite them.
# A container prefix is declared once while active; after its closing event, a
# repeated prefix is a second declaration, even when its children are disjoint.
def raw_need($ok; $why): if $ok then . else error($why) end;
def raw_document:
  raw_need(type == "array" and all(.[]; type == "array" and (length == 1 or length == 2)
    and (.[0] | type == "array")); "use jq --stream -s")
  # A real stream leaf is a scalar or an empty container; a non-empty one is a hand-wrapped document.
  | raw_need(all(.[]; length == 1 or (.[1] | (type != "object" and type != "array") or length == 0));
      "use jq --stream -s")
  | . as $events
  | reduce .[] as $event ({active: [], seen: {}};
      $event[0] as $path
      | if ($event | length) == 2 then
          reduce range(1; ($path | length) + 1) as $n (.;
            $path[0:$n] as $prefix
            | if $n < ($path | length) and .active[0:$n] == $prefix then .
              else ($prefix | tojson) as $key
                | raw_need(.seen[$key] != true; "repeated decoded field path: " + $key)
                | .seen[$key] = true end)
          | .active = $path[0:-1]
        else .active = $path[0:-2] end)
  | [$events | fromstream(.[])]
  | raw_need(length == 1; "expected exactly one JSON document; before jq 1.8.0 the file must also end with a newline")
  | .[0];

# Read completed runs with measure-flow.sh, which validates retained bytes before this filter.
# This computes descriptive metrics; evidence authenticity and policy stay with the consumer.
def text: type == "string" and test("\\S");
def decimal_integer:
  tostring as $raw
  | ($raw | ltrimstr("-")) as $unsigned
  | ($unsigned == (1e-1147483647 | tostring)) as $underflowed
  | ($unsigned | capture("^(?<whole>[0-9]+)(?:\\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$")) as $parts
  | ($parts.fraction // "") as $fraction
  | ($parts.whole + $fraction) as $digits
  | if ($digits | test("^0+$")) then ($underflowed | not)
    else (($parts.exponent // "0") | tonumber) as $exponent
      | (($fraction | length) - $exponent) as $scale
      | if $scale <= 0 then true
        elif $scale > ($digits | length) then false
        else (($digits | length) - $scale) as $integer_length
          | ($digits[$integer_length:] | test("^0+$"))
        end
    end;
def timestamp:
  type == "number" and isfinite and . >= 0 and . <= 9007199254740991 and decimal_integer;
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

# Refuse lossy numeric backends before a rounded input can become a measurement.
[raw_document] | if (9007199254740991.1 > 9007199254740991) then .
else error("flow measurement requires decimal-preserving jq (1.7 or newer)") end
| if length != 1 then error("expected exactly one completed-run evidence document")
else .[0]
  | if valid then
      {version: 1, run, artifactMix: artifact_mix, selectionsComplete,
       selections: [.selections[] | selection_metric]}
    else error("invalid flow evidence; retain UNKNOWN, not a zero or a verdict") end
end
