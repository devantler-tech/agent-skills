# Inspect decoded paths before reconstruction can erase repeated declarations.
def need($ok; $why): if $ok then . else error($why) end;
def document:
  . as $events
  | reduce .[] as $event ({active: [], seen: {}};
      $event[0] as $path
      | if ($event | length) == 2 then
          reduce range(1; ($path | length) + 1) as $n (.;
            $path[0:$n] as $prefix
            | if $n < ($path | length) and .active[0:$n] == $prefix then .
              else ($prefix | tojson) as $key
                | need(.seen[$key] != true; "repeated decoded field")
                | .seen[$key] = true end)
          | .active = $path[0:-1]
        else .active = $path[0:-2] end)
  | [$events | fromstream(.[])]
  | need(length == 1; "one complete JSON document required") | .[0];
def integer: type == "number" and isfinite and . >= 0 and . <= 9007199254740991 and floor == .;
def text: type == "string" and test("\\A[^\\s\\p{Z}\\p{C}]+( [^\\s\\p{Z}\\p{C}]+)*\\z")
  and (test("\\p{Default_Ignorable_Code_Point}") | not);
def scale: integer and . >= 1 and . <= 3;
def estimates: ["value","urgency","riskReduction","unblocks","effort"];
def columns: ["inProgress","inReview","readyToMerge","verifying"];
def started: .startedAt != null or .status == "In Progress" or .status == "In Review" or .status == "Ready to Merge" or .status == "Verifying";
def stage: if .status == "Ready to Merge" then 0 elif .status == "Verifying" then 1 elif .status == "In Review" then 2 else 3 end;
def ratio: (.value + .urgency + .riskReduction + .unblocks) / .effort;
def valid:
  . as $input
  | type == "object" and .version == 1 and (.complete | type == "boolean")
  and (.observedAt | integer) and (.maxAgeSeconds | integer and . > 0)
  and ($now | integer)
  and (.counts | type == "object") and (.limits | type == "object")
  and all(columns[]; . as $key | ($input.counts[$key] | integer) and ($input.limits[$key] | integer and . > 0))
  and (.candidates | type == "array"
    and length == (map(.id) | unique | length)
    and all(.[]; type == "object"
      and (.id | text) and (.evidence | text)
      and (.status == "Ready" or .status == "Backlog" or .status == "Icebox"
        or .status == "In Progress" or .status == "In Review" or .status == "Ready to Merge" or .status == "Verifying")
      and has("actionable") and (.actionable == null or (.actionable | type == "boolean"))
      and (.incident | type == "boolean")
      and has("priority") and (.priority == null or (.priority | integer and . <= 3))
      and (. as $candidate | all(estimates[]; . as $key |
        ($candidate | has($key)) and ($candidate[$key] == null or ($candidate[$key] | scale))))
      and has("readySince") and (.readySince == null or (.readySince | integer and . <= $now))
      and has("startedAt") and (.startedAt == null or (.startedAt | integer and . <= $now))));
def result($decision; $reason; $candidate):
  {version:1, policy:"value-pull-v1", decision:$decision, reason:$reason,
    id:($candidate.id // null), evidence:($candidate.evidence // null),
    ageSeconds:(if $candidate == null then null
      elif $candidate.startedAt != null then $now - $candidate.startedAt
      elif $candidate.readySince != null then $now - $candidate.readySince else null end)};
document | need(valid; "invalid normalized selection evidence")
| . as $input
| [.candidates[] | select(.incident and .actionable == true)] as $incidents
| [.candidates[] | select(started and .actionable == true)] as $finishing
| [.candidates[] | select(.status == "Ready" and (.startedAt == null) and .actionable == true)] as $ready
| [columns[] | . as $key | select($input.counts[$key] >= $input.limits[$key])] as $full
| if (.complete | not) or .observedAt > $now or ($now - .observedAt) > .maxAgeSeconds then
    result("HOLD"; "incomplete or stale observation"; null)
  elif ($incidents | length) > 0 then
    result("EXPEDITE"; "confirmed live breakage; record capacity exception"; ($incidents | sort_by(.priority // 4,.readySince // $now,.id) | .[0]))
  elif ($finishing | length) > 0 then
    result("FINISH"; "finish started work before intake"; ($finishing | sort_by(stage,.startedAt // $now,.id) | .[0]))
  elif any(.candidates[]; (started or .status == "Ready") and .actionable == null) then
    result("HOLD"; "actionability is unknown"; null)
  elif ($full | length) > 0 then
    result("HOLD"; "help the full downstream columns: " + ($full | join(",")); null)
  elif any($ready[]; .priority == null or .readySince == null
    or (. as $candidate | any(estimates[]; $candidate[.] == null))) then
    result("HOLD"; "Ready priority, estimates or waiting age needs refinement"; null)
  elif ($ready | length) > 0 then
    result("PULL"; "documented priority, relative cost of delay/effort, then Ready age";
      ($ready | sort_by(.priority, -(ratio), .readySince, .id) | .[0]))
  else result("REFINE"; "no unblocked Ready work; refine/replenish without starting Icebox or Backlog"; null)
  end
