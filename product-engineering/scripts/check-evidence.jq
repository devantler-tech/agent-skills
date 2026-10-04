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

# Offline evidence-bundle v1 evaluator. See ../references/evidence-bundle.md.
# Use check-evidence.sh to validate retained raw bytes before streaming into this filter.
def require($ok; $message): if $ok then . else error($message) end;
def text: type == "string" and test("\\S");
def source_identity: type == "string" and test("\\A[^\\s\\p{C}\\p{Default_Ignorable_Code_Point}]+\\z");
def number: type == "number" and isfinite;
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
def integer: number and decimal_integer;
def stamp:
  if type != "string" then false
  else try (test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
    and (. == (fromdateiso8601 | strftime("%Y-%m-%dT%H:%M:%SZ")))) catch false end;
def unique_ids: length == (map(.id) | unique | length);
def interval: . == null or (type == "object" and (.lower | number) and (.upper | number) and .lower <= .upper);
def kinds: ["measurement", "static", "behavior", "deployment", "live", "review", "holdout", "rollback"];
def schema:
  require(type == "object" and (.schemaVersion | integer) and .schemaVersion == 1; "unsupported evidence-bundle schema")
  | require((.outcome | text) and (.baseline.id | source_identity) and (.baseline.revision | source_identity)
      and (.candidate.id | source_identity) and (.candidate.revision | source_identity)
      and .baseline.id != .candidate.id and .baseline.revision != .candidate.revision; "outcome, baseline and distinct candidate required")
  | .baseline.id as $baseline
  | require((.alternatives | type == "array" and length > 0 and unique_ids)
      and all(.alternatives[]; (.id | source_identity) and (.reason | text))
      and any(.alternatives[]; .id == $baseline); "record alternatives including retaining the baseline and their disposition")
  | require((.plan.record | source_identity) and (.plan.registeredAt | stamp) and (.plan.startedAt | stamp)
      and (.plan.minRepeats | integer) and .plan.minRepeats >= 2; "invalid preregistration or repeat floor")
  | require((.plan.measures | type == "array" and length > 0 and unique_ids)
      and any(.plan.measures[]; .objective == true) and any(.plan.measures[]; .protected == true); "unique measures, objectives and protected dimensions required")
  | require(all(.plan.measures[];
      (.id | source_identity) and (.unit | text) and (.direction == "higher" or .direction == "lower")
      and (.objective | type == "boolean") and (.protected | type == "boolean")
      and (.minImprovement | number) and .minImprovement >= 0 and (if .objective then .minImprovement > 0 else true end)
      and (.maxRegression | number) and .maxRegression >= 0 and (if .protected then (.floor | number) else true end)
      and (.method | text) and (.environment | text) and (.uncertaintyMethod | text)); "invalid measure, threshold, floor or uncertainty method")
  | require((.assumptions | type == "array" and length > 0)
      and all(.assumptions[]; (.statement | text) and (.evidenceId | source_identity)
        and (.state == "supported" or .state == "unknown" or .state == "refuted")); "record assumptions and their evidence")
  | require((.falsification.approach == "independent" or .falsification.approach == "adversarial")
      and (.falsification.evaluator | text) and (.falsification.evidenceId | source_identity) and (.falsification.attempt | text); "independent or adversarial falsification required")
  | require((.rollout.stages | type == "array" and length > 0 and all(.[]; text))
      and (.rollout.stopConditions | type == "array" and length > 0 and all(.[]; text))
      and (.rollback.procedure | source_identity) and (.rollback.evidenceId | source_identity) and (.rollback.trigger | text)
      and .rollback.targetRevision == .baseline.revision; "staged rollout and recovery to the baseline required")
  | require((.observation.owner | text) and (.observation.evidenceId | source_identity)
      and (.observation.window.startedAt | stamp) and (.observation.window.endedAt | stamp)
      and .observation.window.startedAt < .observation.window.endedAt
      and (.observation.nextCheck | stamp); "observation owner, evidence, ordered window bounds and next check required")
  | require((.evidence | type == "array" and unique_ids) and all(.evidence[];
      (.id | source_identity) and (.kind as $kind | kinds | index($kind) != null)
      and .provenance == "observed" and (.revision | source_identity) and (.uri | source_identity)
      and (.baselineRevision == null or (.baselineRevision | source_identity))
      and (.observedAt | stamp) and (.expiresAt | stamp)
      and (.result == "pass" or .result == "fail" or .result == "unknown")); "invalid evidence or provenance; confidence is not observation")
  | require((.observations | type == "array" and unique_ids) and all(.observations[];
      (.id | source_identity) and (.evidenceId | source_identity) and (.values | type == "array")
      and ((.values | length) == (.values | map(.measure) | unique | length))
      and all(.values[]; (.measure | source_identity) and (.baseline | interval) and (.candidate | interval))); "invalid observation or uncertainty interval")
  | .plan.measures as $measures
  | require(all(.observations[].values[]; .measure as $id | any($measures[]; .id == $id)); "observation names an undeclared measure");

# Improvement is positive in either direction. Use both interval endpoints so inconclusive
# evidence cannot become a positive or negative outcome through an optimistic point estimate.
# Arithmetic converts preserved JSON decimal spellings to signed digit strings. Only individual
# digits and bounded exponents use jq arithmetic; a full coefficient never becomes a float.
def decimal_parts:
  tostring | capture("^(?<sign>-?)(?<whole>[0-9]+)(?:\\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$") as $p
  | ($p.fraction // "") as $fraction
  | (($p.exponent // "0") | tonumber) as $exponent
  | require(($p.whole | length) + ($fraction | length) <= 4096
      and $exponent >= -4096 and $exponent <= 4096; "decimal arithmetic exceeds bounded representation")
  | (($p.whole + $fraction) | sub("^0+"; "")) as $digits
  | {digits: (if $digits == "" then "0" else $digits end),
     sign: (if $p.sign == "-" and $digits != "" then -1 else 1 end),
     scale: (($fraction | length) - $exponent)};
def decimal_aligned($p; $scale):
  $p.digits + ([range(0; $scale - $p.scale) | "0"] | join(""))
  | sub("^0+"; "") | if . == "" then "0" else . end;
def magnitude_compare($a; $b):
  if ($a | length) < ($b | length) then -1
  elif ($a | length) > ($b | length) then 1
  elif $a < $b then -1 elif $a > $b then 1 else 0 end;
def decimal_compare($a; $b):
  ($a | decimal_parts) as $x | ($b | decimal_parts) as $y
  | if $x.sign != $y.sign then (if $x.sign < $y.sign then -1 else 1 end)
    else ([$x.scale, $y.scale] | max) as $scale
      | magnitude_compare(decimal_aligned($x; $scale); decimal_aligned($y; $scale)) * $x.sign
    end;
# Add magnitudes, or subtract the smaller magnitude from the larger, right to left.
def decimal_digits($a; $b; $subtract):
  ($a | explode | reverse) as $x | ($b | explode | reverse) as $y
  | reduce range(0; ([($x | length), ($y | length)] | max)) as $i
      ({carry: 0, digits: []};
       (($x[$i] // 48) - 48 + (if $subtract then -1 else 1 end) * (($y[$i] // 48) - 48) + .carry) as $n
       | if $subtract then {carry: (if $n < 0 then -1 else 0 end),
           digits: (.digits + [(if $n < 0 then $n + 10 else $n end) + 48])}
         else {carry: ($n / 10 | floor), digits: (.digits + [($n % 10) + 48])} end)
  | (.digits + (if .carry > 0 then [.carry + 48] else [] end))
  | reverse | implode | sub("^0+"; "") | if . == "" then "0" else . end;
def decimal_difference($a; $b):
  ($a | decimal_parts) as $x
  | ($b | decimal_parts | .sign *= -1) as $y
  | ([$x.scale, $y.scale] | max) as $scale
  | decimal_aligned($x; $scale) as $left | decimal_aligned($y; $scale) as $right
  | (if $x.sign == $y.sign then {digits: decimal_digits($left; $right; false), sign: $x.sign}
     elif magnitude_compare($left; $right) >= 0 then {digits: decimal_digits($left; $right; true), sign: $x.sign}
     else {digits: decimal_digits($right; $left; true), sign: $y.sign} end)
  | (if .sign < 0 and .digits != "0" then "-" else "" end) + .digits + "e" + (-$scale | tostring);
def gain($m; $v):
  if $m.direction == "lower" then
    {low: decimal_difference($v.baseline.lower; $v.candidate.upper), high: decimal_difference($v.baseline.upper; $v.candidate.lower)}
  else
    {low: decimal_difference($v.candidate.lower; $v.baseline.upper), high: decimal_difference($v.candidate.upper; $v.baseline.lower)} end;
def floor_known_bad($m; $v):
  $m.protected and (if $m.direction == "lower" then $v.candidate.lower > $m.floor else $v.candidate.upper < $m.floor end);
def floor_proven($m; $v):
  ($m.protected | not) or (if $m.direction == "lower" then $v.candidate.upper <= $m.floor else $v.candidate.lower >= $m.floor end);

[raw_document] | require(9007199254740991.1 > 9007199254740991; "evidence assessment requires decimal-preserving jq (1.7 or newer)")
| require(type == "array" and length == 1; "use jq --stream -s with exactly one evidence bundle")
| .[0]
| require($now | stamp; "--arg now must be a UTC timestamp")
| schema
| require(all([.plan.measures[] | .minImprovement, .maxRegression, (.floor | select(type == "number"))]
    + [.observations[].values[] | .baseline, .candidate | select(. != null) | .lower, .upper] | .[];
    tostring | capture("^-?(?<whole>[0-9]+)(?:\\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$")
    | (.whole | length) + ((.fraction // "") | length) <= 1024
      and ((.exponent // "0") | tonumber) >= -1024 and ((.exponent // "0") | tonumber) <= 1024);
    "decimal inputs exceed 1024-digit/exponent bound")
| . as $b
| ($now | fromdateiso8601) as $time
| def evidence($id; $kind): any($b.evidence[]; .id == $id and .kind == $kind);
  # Expiry can revoke a positive verdict, but cannot erase a failure observed for this experiment.
  # Keep revision/window binding separate; another candidate's failures are not this one's outcome.
  def candidate_bound:
    .revision == $b.candidate.revision
    and .observedAt >= $b.plan.startedAt and .observedAt <= $now;
  def bound: candidate_bound and (.kind != "measurement" or .baselineRevision == $b.baseline.revision);
  def measured($id): any($b.evidence[]; .id == $id and .kind == "measurement" and bound and .result != "unknown");
  def complete_values($o): all($b.plan.measures[]; .id as $id |
    any($o.values[]; .measure == $id and .baseline != null and .candidate != null));
  def measurement_coverage: all($b.evidence[] | select(.kind == "measurement"); .id as $id |
    ([$b.observations[] | select(.evidenceId == $id)] | length) == 1);
  # A threshold miss is conclusive only once the declared measurement set is complete.
  def measurements_complete:
    ($b.observations | length) >= $b.plan.minRepeats and measurement_coverage
    and all($b.observations[]; measured(.evidenceId) and complete_values(.))
    and (($b.observations | length) == ([$b.observations[].evidenceId as $id |
      $b.evidence[] | select(.id == $id) | .uri] | unique | length));
  def deployed_before($stage): any($b.evidence[];
    .id == $stage.deploymentEvidenceId and .kind == "deployment" and bound
    and .result == "pass" and .observedAt < $stage.observedAt);
  [$b.evidence[] | select(.id == $b.observation.evidenceId and .kind == "live")] as $window_evidence
| [$b.observations[] | .evidenceId as $id
    | select(any($b.evidence[]; .id == $id and .kind == "measurement" and candidate_bound and .result != "unknown"))
    | .values[] | select(.candidate != null) as $v
    | $b.plan.measures[] | select(.id == $v.measure) as $m
    | {measure: $m, value: $v}] as $candidates
| [$b.observations[] | select(measured(.evidenceId)) | .values[] | select(.baseline != null and .candidate != null) as $v
    | $b.plan.measures[] | select(.id == $v.measure) as $m
    | {measure: $m, value: $v, gain: gain($m; $v)}] as $comparisons
| [
    if $b.plan.registeredAt >= $b.plan.startedAt then "thresholds were not registered before work started" else empty end,
    if $b.plan.startedAt > $now then "work has not started" else empty end,
    (kinds[] | . as $kind | if any($b.evidence[]; .kind == $kind) then empty else "missing \($kind) evidence" end),
    ($b.evidence[] |
      if .revision != $b.candidate.revision then "revision mismatch: \(.id)" else empty end,
      if .kind == "measurement" and .baselineRevision != $b.baseline.revision then "baseline mismatch: \(.id)" else empty end,
      if (.observedAt | fromdateiso8601) > $time or .observedAt < $b.plan.startedAt then "observation outside experiment window: \(.id)" else empty end,
      if (.expiresAt | fromdateiso8601) <= $time then "expired evidence: \(.id)" else empty end,
      if .result == "unknown" then "unknown result: \(.id)" else empty end),
    if ($b.observations | length) < $b.plan.minRepeats then "insufficient repeats" else empty end,
    if ($b.observations | length) != ($b.observations | map(.evidenceId) | unique | length) then "reused measurement evidence" else empty end,
    if ([$b.observations[].evidenceId as $id | $b.evidence[] | select(.id == $id) | .uri] | length)
        != ([$b.observations[].evidenceId as $id | $b.evidence[] | select(.id == $id) | .uri] | unique | length)
      then "reused measurement source" else empty end,
    ($b.observations[] |
      if complete_values(.) then empty else "unmeasured dimension: \(.id)" end,
      if evidence(.evidenceId; "measurement") then empty else "missing measurement source: \(.id)" end),
    ($b.evidence[] | select(.kind == "measurement") | .id as $id |
      if any($b.observations[]; .evidenceId == $id) then empty else "missing observation for measurement: \($id)" end),
    ($b.assumptions[] |
      if .state == "unknown" then "unknown assumption: \(.statement)" else empty end,
      if .evidenceId as $id | any($b.evidence[]; .id == $id) then empty else "missing assumption evidence" end),
    if evidence($b.falsification.evidenceId; "review") then empty else "missing falsification review" end,
    ($b.evidence[] | select(.kind == "holdout" and .usedForTuning != false) | "holdout isolation is unproven"),
    if evidence($b.rollback.evidenceId; "rollback") then empty else "unproven rollback" end,
    ($b.evidence[] | select(.kind == "live" or .kind == "rollback") |
      if deployed_before(.) then empty else "deployment must precede \(.kind) evidence: \(.id)" end),
    if $b.observation.window.startedAt < $b.plan.startedAt then "observation window starts before experiment" else empty end,
    if $b.observation.window.endedAt > $now then "observation window has not elapsed" else empty end,
    if ($window_evidence | length) == 0 then "missing observation window evidence" else empty end,
    ($window_evidence[] |
      if .observedAt >= $b.observation.window.endedAt then empty else "live evidence does not cover observation window" end,
      .deploymentEvidenceId as $deployment |
      if any($b.evidence[]; .id == $deployment and .kind == "deployment" and bound and .result == "pass"
          and .observedAt <= $b.observation.window.startedAt) then empty else "observation window precedes deployment" end),
    if ($b.observation.nextCheck | fromdateiso8601) <= $time then "observation check is overdue" else empty end,
    ($b.evidence[] | select(.expiresAt <= $b.observation.nextCheck) | "observation check must precede evidence expiry: \(.id)"),
    ($candidates[] | if floor_proven(.measure; .value) then empty else "unproven protected floor: \(.measure.id)" end),
    ($comparisons[] | if decimal_compare(.gain.low; decimal_difference(0; .measure.maxRegression)) < 0 then "possible material regression: \(.measure.id)" else empty end)
  ] | unique as $holds
| [
    ($b.evidence[] | select(bound and .result == "fail") | "failed \(.kind) evidence: \(.id)"),
    ($b.assumptions[] | select(.state == "refuted") | .evidenceId as $id
      | select(any($b.evidence[]; .id == $id and bound and .result != "unknown")) | "refuted assumption: \(.statement)"),
    ($candidates[] | if floor_known_bad(.measure; .value) then "protected floor breached: \(.measure.id)" else empty end),
    ($comparisons[] | if decimal_compare(.gain.high; decimal_difference(0; .measure.maxRegression)) < 0 then "material regression: \(.measure.id)" else empty end)
  ] | unique as $rejects
| [ $b.plan.measures[] | select(.objective) as $m
    | [$comparisons[] | select(.measure.id == $m.id)] as $rows
    | {proven: (($rows | length) >= $b.plan.minRepeats and all($rows[]; decimal_compare(.gain.low; $m.minImprovement) >= 0)),
       possible: all($rows[]; decimal_compare(.gain.high; $m.minImprovement) >= 0)} ] as $objectives
| (if measurements_complete and all($objectives[]; .possible | not)
    then $rejects + ["no objective met its repeatable improvement threshold"] else $rejects end) as $rejects
| if ($rejects | length) > 0 then {decision: "REJECT", reasons: ($rejects + $holds | unique)}
  elif ($holds | length) > 0 then {decision: "HOLD", reasons: $holds}
  elif any($objectives[]; .proven) then {decision: "ADOPT", reasons: []}
  elif any($objectives[]; .possible) then {decision: "HOLD", reasons: ["uncertainty prevents a repeatable improvement verdict"]}
  else {decision: "REJECT", reasons: ["no objective met its repeatable improvement threshold"]} end
| . + {schemaVersion: 1, evaluatedAt: $now, candidateRevision: $b.candidate.revision,
       baselineRevision: $b.baseline.revision, authority: "assessment-only"}
