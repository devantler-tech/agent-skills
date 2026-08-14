#!/usr/bin/env bash
#
# Contract test for the agent-improvement skill's evidence gates. Rate-based
# metrics need comparable baselines, post-change time and observation-volume
# floors, and an uncontaminated observation window before a success/failure
# verdict is meaningful; coordination verdicts need distinct-writer provenance.
# State checks may be decisive from one live inspection.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="${1:-$repo_root/agent-improvement/SKILL.md}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check_contract() { # skill
  local flat
  flat="$(tr '\n' ' ' <"$1" | sed -E 's/[[:space:]]+/ /g')"

  grep -Eqi 'rate-based metric.{0,240}baseline (observation volume|numerator.{0,80}denominator)' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}UTC verification-window start' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}UTC not-before timestamp' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}minimum post-change observation volume' <<<"$flat" || return 1
  grep -Eqi 'minimum post-change observation volume.{0,240}(sessions|dispatches|requests|artifacts)' <<<"$flat" || return 1
  grep -Eqi 'evidence generated at or after.{0,120}verification-window start' <<<"$flat" || return 1
  grep -Eqi 'if either floor is unmet.{0,240}NOT-YET-DUE' <<<"$flat" || return 1
  grep -Eqi 'NOT-YET-DUE.{0,240}(no verdict|without applying a verdict)' <<<"$flat" || return 1
  grep -Eqi 'hypothesis.{0,240}continue only.{0,240}cannot affect.{0,160}(signature|metric)' <<<"$flat" || return 1
  grep -Eqi 'state metric.{0,240}(single|one) live inspection.{0,240}(omit|without).{0,120}volume floor' <<<"$flat" || return 1
}

check_coordination_contract() { # skill
  local coordination_contract flat
  flat="$(LC_ALL=C awk '
    /^\*\*Collision verdicts require writer provenance\.\*\*/ { capture=1 }
    capture && NF == 0 { exit }
    capture { print }
  ' "$1" | LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -d '*' | LC_ALL=C sed -E 's/[[:space:]]+/ /g; s/ $//')"
  coordination_contract="collision verdicts require writer provenance. a cross-instance collision or two-writer race requires evidence identifying at least two distinct writers or instances and the artifacts or shared state on which they conflicted. "
  coordination_contract+="absent that distinct-writer provenance, a single session's stale edit or dirty local merge is reliability or local-state evidence, not a coordination verdict. "
  coordination_contract+="when second-writer provenance is unavailable, keep the signal unknown or a candidate pending investigation; do not count it as a collision."

  [ "$flat" = "$coordination_contract" ]
}

check_outcome_throughput_contract() { # skill
  local throughput_contract flat
  grep -Fq '| **Outcome throughput** |' "$1" || return 1
  flat="$(LC_ALL=C awk '
    /^\*\*Outcome throughput is a guarded rate, not an artifact contest\.\*\*/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1" | LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -d '*' | LC_ALL=C sed -E 's/[[:space:]]+/ /g; s/ $//')"
  throughput_contract="outcome throughput is a guarded rate, not an artifact contest. for each short and long window, record the raw number of completed sessions, sessions with at least one value-bearing state transition, unique work items advanced, and terminal outcomes. "
  throughput_contract+="report productive-session rate and terminal outcomes per completed session; keep intermediate transitions separate from terminal outcomes. count a work item once per session even if touched repeatedly. "
  throughput_contract+="terminal outcomes are deployment-defined completions that deliver the work, for example a merged change, resolved work item, shipped release, verified production repair, or recorded decision when the decision is the deliverable. "
  throughput_contract+="run reports, memory writes, status comments, review requests, duplicate artifacts, and waiting are not terminal outcomes. keep substantive-versus-filler mix visible. missing session-to-outcome attribution is unknown, never zero. "
  throughput_contract+="throughput never outranks its floors. do not combine throughput, safety, and quality into a weighted or composite score. every throughput comparison carries companion safety and quality raw metrics. "
  throughput_contract+="higher throughput counts as improvement only when every declared safety and quality floor is unchanged or better; any floor regression makes the hypothesis fail regardless of throughput and triggers the revert-first rule. "
  throughput_contract+="a throughput hypothesis records its throughput baseline numerator, denominator, and observation volume plus companion floor baselines and thresholds under the same verification window."

  [ "$flat" = "$throughput_contract" ]
}

check_self_observation_contract() { # skill
  local self_contract flat
  grep -Fq '| **Observer effectiveness** |' "$1" || return 1
  flat="$(LC_ALL=C awk '
    /^\*\*The observer is one of its own measured subjects\.\*\*/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1" | LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -d '*' | LC_ALL=C sed -E 's/[[:space:]]+/ /g; s/ $//')"
  self_contract="the observer is one of its own measured subjects. keep two named scorecards: the execution plane (the agentic engineer) and the observation plane (every agent improver instance). never average them together or let improvement in one hide regression in the other. every required parameter reports separate raw numerators, denominators, observation volumes, attribution coverage, and unknowns per role and instance. "
  self_contract+="for the observation plane, report at minimum: scorecard coverage; diagnostic calibration as confirmed, false-positive, and unknown findings; hypothesis discipline as eligible, overdue, working, not-working, and no-verdict hypotheses; intervention effectiveness as verified-working changes per eligible shipped change; observer reliability and efficiency; and self-improvement throughput as productive improver sessions and terminal verified rollouts. "
  self_contract+="pull requests opened, metrics added, words changed, hypotheses opened, reports, and memory writes are activity, not observer improvement. a failed or null hypothesis is calibration evidence and is never erased or relabelled to make the observer look better. "
  self_contract+="metric evolution is allowed when measured behavior exposes a coverage gap. version the metric definition, source, inclusion and exclusion rules, known blind spots, and effective timestamp; preserve the prior series and its bad news. never delete, rename, rebase, or narrow a metric merely because it regressed. unavailable attribution remains unknown. "
  self_contract+="a self-referential change cannot validate itself with only a metric it introduced or changed. it needs independent current-head review, unchanged safety and quality companions, and post-change evidence from the next eligible window; where possible keep one unchanged holdout measure. any self-improvement that weakens those checks fails regardless of its apparent observer score."

  [ "$flat" = "$self_contract" ]
}

fail=0

if check_contract "$skill"; then
  printf '  ✅ live skill defines the hypothesis evidence floor\n'
else
  printf '  ❌ live skill permits an underpowered hypothesis verdict\n' >&2
  fail=1
fi

if check_coordination_contract "$skill"; then
  printf '  ✅ live skill requires two-writer collision evidence\n'
else
  printf '  ❌ live skill permits a single-session collision verdict\n' >&2
  fail=1
fi

if check_outcome_throughput_contract "$skill"; then
  printf '  ✅ live skill guards outcome throughput with quality floors\n'
else
  printf '  ❌ live skill does not continuously guard outcome throughput\n' >&2
  fail=1
fi

if check_self_observation_contract "$skill"; then
  printf '  ✅ live skill measures the Agent Improver without self-scoring shortcuts\n'
else
  printf '  ❌ live skill does not independently monitor the Agent Improver\n' >&2
  fail=1
fi

coordination_good="$tmp/coordination-good.md"
cat >"$coordination_good" <<'EOF'
**Collision verdicts require writer provenance.**
A cross-instance collision or two-writer race requires evidence identifying at least two distinct
writers or instances and the artifacts or shared state on which they conflicted.
Absent that distinct-writer provenance, a single session's stale edit or dirty local merge is
reliability or local-state evidence, not a coordination verdict.
When second-writer provenance is unavailable, keep the signal UNKNOWN or a candidate pending
investigation; do not count it as a collision.
EOF

if check_coordination_contract "$coordination_good"; then
  printf '  ✅ complete coordination evidence contract passes\n'
else
  printf '  ❌ complete coordination evidence contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in broad_heading leading_negation positive_requirement distinct_writer positive_conflicted_state conflicted_state positive_local_qualification provenance_qualification stale_edit dirty_merge local_classification provenance_missing positive_fallback unknown_verdict non_collision; do
  fixture="$tmp/coordination-$missing.md"
  case "$missing" in
    broad_heading) sed 's/Collision verdicts/Coordination verdicts/' "$coordination_good" >"$fixture" ;;
    leading_negation) sed 's/A cross-instance/It is not true that a cross-instance/' "$coordination_good" >"$fixture" ;;
    positive_requirement) sed 's/race requires evidence/race does not require evidence/' "$coordination_good" >"$fixture" ;;
    distinct_writer) sed 's/two distinct/two/' "$coordination_good" >"$fixture" ;;
    positive_conflicted_state) sed 's/instances and the artifacts/instances but does not require the artifacts/' "$coordination_good" >"$fixture" ;;
    conflicted_state) sed 's/ and the artifacts or shared state//' "$coordination_good" >"$fixture" ;;
    positive_local_qualification) sed 's/Absent that distinct-writer provenance/It is not true that absent that distinct-writer provenance/' "$coordination_good" >"$fixture" ;;
    provenance_qualification) sed 's/Absent that distinct-writer provenance, //' "$coordination_good" >"$fixture" ;;
    stale_edit) sed 's/stale edit/local edit/' "$coordination_good" >"$fixture" ;;
    dirty_merge) sed 's/dirty local merge/local merge/' "$coordination_good" >"$fixture" ;;
    local_classification) sed 's/reliability/ordinary/g' "$coordination_good" >"$fixture" ;;
    provenance_missing) sed 's/provenance is unavailable/provenance is observed/' "$coordination_good" >"$fixture" ;;
    positive_fallback) sed 's/keep the signal UNKNOWN/do not keep the signal UNKNOWN/' "$coordination_good" >"$fixture" ;;
    unknown_verdict) sed 's/UNKNOWN or a candidate/a collision/' "$coordination_good" >"$fixture" ;;
    non_collision) sed 's/do not count it as a collision/count it as a collision/' "$coordination_good" >"$fixture" ;;
  esac
  if check_coordination_contract "$fixture"; then
    printf '  ❌ missing coordination %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing coordination %s fails closed\n' "$missing"
  fi
done

throughput_good="$tmp/throughput-good.md"
cat >"$throughput_good" <<'EOF'
| **Outcome throughput** | terminal outcomes and productive sessions | the agent completes too little |

**Outcome throughput is a guarded rate, not an artifact contest.** For each short and long window,
record the raw number of completed sessions, sessions with at least one value-bearing state transition,
unique work items advanced, and terminal outcomes. Report productive-session rate and terminal outcomes
per completed session; keep intermediate transitions separate from terminal outcomes. Count a work item
once per session even if touched repeatedly. Terminal outcomes are deployment-defined completions that
deliver the work, for example a merged change, resolved work item, shipped release, verified production
repair, or recorded decision when the decision is the deliverable. Run reports, memory writes, status
comments, review requests, duplicate artifacts, and waiting are not terminal outcomes. Keep
substantive-versus-filler mix visible. Missing session-to-outcome attribution is UNKNOWN, never zero.

**Throughput never outranks its floors.** Do not combine throughput, safety, and quality into a weighted
or composite score. Every throughput comparison carries companion safety and quality raw metrics.
Higher throughput counts as improvement only when every declared safety and quality floor is unchanged
or better; any floor regression makes the hypothesis fail regardless of throughput and triggers the
revert-first rule. A throughput hypothesis records its throughput baseline numerator, denominator, and
observation volume plus companion floor baselines and thresholds under the same verification window.

---
EOF

if check_outcome_throughput_contract "$throughput_good"; then
  printf '  ✅ complete outcome-throughput contract passes\n'
else
  printf '  ❌ complete outcome-throughput contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in table short_window productive_rate terminal_separation dedup terminal_definition exclusions substantive_mix unknown_attribution composite_guard companion_metrics floor_veto hypothesis_floors; do
  fixture="$tmp/throughput-$missing.md"
  case "$missing" in
    table) sed '/| \*\*Outcome throughput\*\* |/d' "$throughput_good" >"$fixture" ;;
    short_window) sed 's/each short and long window/each available window/' "$throughput_good" >"$fixture" ;;
    productive_rate) sed 's/Report productive-session rate/Report activity/' "$throughput_good" >"$fixture" ;;
    terminal_separation) sed 's/keep intermediate transitions separate from terminal outcomes/treat intermediate transitions as terminal outcomes/' "$throughput_good" >"$fixture" ;;
    dedup) sed 's/Count a work item/Count every touch of a work item/' "$throughput_good" >"$fixture" ;;
    terminal_definition) sed 's/deployment-defined/activity-defined/' "$throughput_good" >"$fixture" ;;
    exclusions) sed 's/Run reports/Activity reports/' "$throughput_good" >"$fixture" ;;
    substantive_mix) sed 's/substantive-versus-filler/artifact-volume/' "$throughput_good" >"$fixture" ;;
    unknown_attribution) sed 's/Missing session-to-outcome attribution is UNKNOWN, never zero/Missing attribution is zero/' "$throughput_good" >"$fixture" ;;
    composite_guard) sed 's/weighted/single/' "$throughput_good" >"$fixture" ;;
    companion_metrics) sed 's/Every throughput comparison carries companion safety and quality raw metrics/Throughput comparisons stand alone/' "$throughput_good" >"$fixture" ;;
    floor_veto) sed 's/any floor regression makes the hypothesis fail regardless of throughput/a throughput gain offsets a floor regression/' "$throughput_good" >"$fixture" ;;
    hypothesis_floors) sed 's/plus companion floor baselines and thresholds/without companion floor baselines/' "$throughput_good" >"$fixture" ;;
  esac
  if check_outcome_throughput_contract "$fixture"; then
    printf '  ❌ missing outcome-throughput %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing outcome-throughput %s fails closed\n' "$missing"
  fi
done

self_good="$tmp/self-good.md"
cat >"$self_good" <<'EOF'
| **Observer effectiveness** | calibration and verified interventions | the improver optimizes itself blindly |

**The observer is one of its own measured subjects.** Keep two named scorecards: the execution plane
(the Agentic Engineer) and the observation plane (every Agent Improver instance). Never average them
together or let improvement in one hide regression in the other. Every required parameter reports
separate raw numerators, denominators, observation volumes, attribution coverage, and UNKNOWNs per role
and instance.

For the observation plane, report at minimum: scorecard coverage; diagnostic calibration as confirmed,
false-positive, and UNKNOWN findings; hypothesis discipline as eligible, overdue, WORKING, NOT-WORKING,
and NO-VERDICT hypotheses; intervention effectiveness as verified-working changes per eligible shipped
change; observer reliability and efficiency; and self-improvement throughput as productive Improver
sessions and terminal verified rollouts.

Pull requests opened, metrics added, words changed, hypotheses opened, reports, and memory writes are
activity, not observer improvement. A failed or null hypothesis is calibration evidence and is never
erased or relabelled to make the observer look better.

Metric evolution is allowed when measured behavior exposes a coverage gap. Version the metric
definition, source, inclusion and exclusion rules, known blind spots, and effective timestamp; preserve
the prior series and its bad news. Never delete, rename, rebase, or narrow a metric merely because it
regressed. Unavailable attribution remains UNKNOWN.

A self-referential change cannot validate itself with only a metric it introduced or changed. It needs
independent current-head review, unchanged safety and quality companions, and post-change evidence from
the next eligible window; where possible keep one unchanged holdout measure. Any self-improvement that
weakens those checks fails regardless of its apparent observer score.

---
EOF

if check_self_observation_contract "$self_good"; then
  printf '  ✅ complete self-observation contract passes\n'
else
  printf '  ❌ complete self-observation contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in table separate_planes no_average raw_evidence calibration hypothesis_discipline effectiveness anti_activity failed_hypothesis metric_version history_preservation unknown_attribution independent_review holdout floor_veto; do
  fixture="$tmp/self-$missing.md"
  case "$missing" in
    table) sed '/| \*\*Observer effectiveness\*\* |/d' "$self_good" >"$fixture" ;;
    separate_planes) sed 's/two named scorecards/one combined scorecard/' "$self_good" >"$fixture" ;;
    no_average) sed 's/Never average them/Average them/' "$self_good" >"$fixture" ;;
    raw_evidence) sed 's/raw numerators, denominators, observation volumes/summary scores/' "$self_good" >"$fixture" ;;
    calibration) sed 's/diagnostic calibration/diagnostic count/' "$self_good" >"$fixture" ;;
    hypothesis_discipline) sed 's/hypothesis discipline/hypothesis volume/' "$self_good" >"$fixture" ;;
    effectiveness) sed 's/intervention effectiveness as verified-working changes/intervention effectiveness as changes/' "$self_good" >"$fixture" ;;
    anti_activity) sed 's/activity, not observer improvement/observer improvement/' "$self_good" >"$fixture" ;;
    failed_hypothesis) sed 's/evidence and is never/evidence and may be/' "$self_good" >"$fixture" ;;
    metric_version) sed 's/Version the metric/Update the metric/' "$self_good" >"$fixture" ;;
    history_preservation) sed 's/effective timestamp; preserve/effective timestamp; replace/' "$self_good" >"$fixture" ;;
    unknown_attribution) sed 's/Unavailable attribution remains UNKNOWN/Unavailable attribution is zero/' "$self_good" >"$fixture" ;;
    independent_review) sed 's/independent current-head review/self-review/' "$self_good" >"$fixture" ;;
    holdout) sed 's/keep one unchanged holdout measure/use the new metric/' "$self_good" >"$fixture" ;;
    floor_veto) sed 's/fails regardless of its apparent observer score/is offset by its observer score/' "$self_good" >"$fixture" ;;
  esac
  if check_self_observation_contract "$fixture"; then
    printf '  ❌ missing self-observation %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing self-observation %s fails closed\n' "$missing"
  fi
done

good="$tmp/good.md"
cat >"$good" <<'EOF'
For a rate-based metric, record the baseline observation volume, a UTC verification-window start,
a UTC not-before timestamp, and a minimum post-change observation volume in sessions, dispatches,
requests, or artifacts. Count only evidence generated at or after the verification-window start.
If either floor is unmet, record NOT-YET-DUE without applying a verdict. While the hypothesis is
pending, continue only with work that cannot affect its tracked signature or metric. A state metric
that is decisive from one live inspection may omit the volume floor.
EOF

if check_contract "$good"; then
  printf '  ✅ complete eligibility contract passes\n'
else
  printf '  ❌ complete eligibility contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in baseline timestamp verification_start volume post_change polarity no_verdict confounding state_carveout; do
  fixture="$tmp/$missing.md"
  case "$missing" in
    baseline) sed 's/baseline observation volume/baseline count/' "$good" >"$fixture" ;;
    timestamp) sed 's/UTC not-before timestamp/calendar date/' "$good" >"$fixture" ;;
    verification_start) sed 's/UTC verification-window start/change date/' "$good" >"$fixture" ;;
    volume) sed 's/minimum post-change observation volume/minimum wait/' "$good" >"$fixture" ;;
    post_change) sed 's/evidence generated at or after the verification-window start/evidence from the rolling window/' "$good" >"$fixture" ;;
    polarity) sed 's/If either floor is unmet/If either floor is met/' "$good" >"$fixture" ;;
    no_verdict) sed 's/without applying a verdict/and apply the unchanged verdict/' "$good" >"$fixture" ;;
    confounding) sed 's/continue only with work that cannot affect its tracked signature or metric/continue with other authorised work/' "$good" >"$fixture" ;;
    state_carveout) sed 's/A state metric.*//' "$good" >"$fixture" ;;
  esac
  if check_contract "$fixture"; then
    printf '  ❌ missing %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing %s fails closed\n' "$missing"
  fi
done

if [ "$fail" -ne 0 ]; then
  printf '❌ agent-improvement contract test failed\n' >&2
  exit 1
fi

printf '✅ agent-improvement contract test passed\n'
