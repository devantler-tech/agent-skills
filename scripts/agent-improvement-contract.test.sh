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

check_corpus_coverage_contract() { # skill
  local flat flat_lower section
  section="$(LC_ALL=C awk '
    /^## 1\. Gather$/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1")"
  [ -n "$section" ] || return 1
  flat="$(tr '\n' ' ' <<<"$section" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  flat_lower="$(tr '[:upper:]' '[:lower:]' <<<"$flat")"

  # Delegated transcripts are part of the corpus and are stored elsewhere.
  grep -Eqi 'delegated (transcript|session|work).{0,200}stored separately' <<<"$flat" || return 1
  grep -Eqi 'enumerat[a-z]*.{0,200}(only the top level|top level of the session store)' <<<"$flat" || return 1
  # The two clauses above are satisfied by the *diagnosis* sentence, so each requirement the
  # skill actually imposes needs its own conjunct or it is pinned by nothing.
  grep -Eqi 'enumerate delegated (transcript|session|work)s? explicitly' <<<"$flat" || return 1
  # `files enumerated` must be LINKED to the coverage statement: satisfied in an unrelated
  # sentence it pins nothing, because the requirement is that each measurement reports BOTH.
  # DIRECTION: the three parts must sit in ONE clause. Unbounded `.` spans crossed sentence
  # boundaries, so an unrelated "files enumerated" sentence in EITHER order satisfied this.
  # `[^.]` cannot cross a full stop, which closes the whole arrangement class rather than
  # one more ordering.
  grep -Eqi 'report coverage alongside every measurement[^.]{0,60}files enumerated[^.]{0,160}(share|proportion|fraction) of records[^.]{0,40}delegated' <<<"$flat" || return 1
  # A zero delegated share is only meaningful against an independently expected inventory.
  grep -Eqi 'independent expected delegated-(session|transcript) inventory.{0,160}(runtime|dispatch|parent|child|index|metadata)' <<<"$flat" || return 1
  grep -Eqi 'report every expected (session|transcript|id).{0,120}missing from.{0,80}(transcript )?(walk|enumeration|inventory)' <<<"$flat" || return 1
  # A control that re-reads the same population is not a control.
  grep -Eqi 'control must vary the (suspected )?filter' <<<"$flat" || return 1
  grep -Eqi 'shares the enumeration is not a control' <<<"$flat" || return 1
  # Removing a filter normally changes raw totals. Pin a comparable basis and explain that delta.
  grep -Eqi '(re-derive|compare).{0,80}(comparable|equivalent cohort).{0,120}(filter removed|differing only)' <<<"$flat" || return 1
  grep -Eqi 'reconcile the delta.{0,120}(records|population).{0,80}filter.{0,40}excluded' <<<"$flat" || return 1
  grep -Eqi 'only an unexplained residual.{0,80}(is|becomes|counts as) a finding' <<<"$flat" || return 1

  case "$flat_lower" in
    *"do not enumerate delegated transcripts explicitly"*|*"never enumerate delegated transcripts explicitly"*|*"a control that shares the enumeration is also a valid control"*) return 1 ;;
  esac
}

check_floor_disposition_contract() { # skill
  local flat flat_lower section
  section="$(LC_ALL=C awk '
    /^## 5\. Verify/ { capture=1 }
    capture && /^## 6\./ { exit }
    capture { print }
  ' "$1")"
  [ -n "$section" ] || return 1
  flat="$(tr '\n' ' ' <<<"$section" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  flat_lower="$(tr '[:upper:]' '[:lower:]' <<<"$flat")"

  # A floor has THREE dispositions. Two of them were already in the verdict map; the third is
  # what this pins, because conflating it with "regressed" or with "held" are opposite errors.
  grep -Eqi 'three dispositions' <<<"$flat" || return 1
  # The count alone does not pin the LABELS: with only 'three dispositions', renaming
  # REGRESSED to anything else still passes. Bind the adverse label to its own clause.
  grep -Eqi 'evidence showing a regression[^.]{0,60}regressed' <<<"$flat" || return 1
  # HELD must be TIED to the stated coverage, or the clause pins nothing: an unrelated sentence
  # mentioning coverage would satisfy a loose match. `[^.]` keeps it inside one sentence.
  grep -Eqi 'no regression[^.]{0,60}within a stated coverage[^.]{0,40}held' <<<"$flat" || return 1
  # The load-bearing direction: gathered-but-bounded is NOT the unmeasured state.
  grep -Eqi 'bounded sample[^.]{0,240}never unmeasured' <<<"$flat" || return 1
  grep -Eqi 'only the absence of admissible evidence is unmeasured' <<<"$flat" || return 1
  # Naming the consequence is what stops the rule being read as bookkeeping.
  grep -Eqi 'unscoreable in principle' <<<"$flat" || return 1
  # Coverage must travel WITH the disposition, mirroring the Gather step.
  grep -Eqi 'state the coverage next to the disposition' <<<"$flat" || return 1
  # UNMEASURED must terminate: a floor that never resolves cannot park a hypothesis forever.
  # Bind the threshold to the UNMEASURED disposition AND to the same hypothesis: without both, a
  # rewrite that drops what must terminate still satisfies the clause and pins nothing.
  grep -Eqi 'unmeasured[^.]{0,120}same hypothesis[^.]{0,80}three consecutive eligible dispatches[^.]{0,80}measurement gap[^.]{0,100}becomes tracked work' <<<"$flat" || return 1

  case "$flat_lower" in
    *"a bounded sample is always unmeasured"*|*"an unbounded not-yet-due is acceptable"*|*"gathered evidence within a bounded coverage is unmeasured"*) return 1 ;;
  esac
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

check_diagnosis_contract() { # skill
  local diagnosis_contract flat
  flat="$(LC_ALL=C awk '
    /^- \*\*Is the guard wrong, is the agent wrong, or is the prescription wrong\?\*\*/ { capture=1 }
    capture && (/^- \*\*One instance or all of them\?\*\*/ || /^---$/) { exit }
    capture { print }
  ' "$1" | LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -d '*' | LC_ALL=C sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  diagnosis_contract="- is the guard wrong, is the agent wrong, or is the prescription wrong? they look identical in telemetry — all appear as a blocked action. "
  diagnosis_contract+="trace which definition, prompt, skill, loader, or durable memory prescribed the behaviour before changing the guard or faulting the executing agent: "
  diagnosis_contract+="- the guard blocks something the contract already forbids, but the agent followed a stale or conflicting prescription → the guard is right and the root defect is the prescription; repair the canonical upstream definition, prompt, skill, loader, or memory and its stale projection, never the guard; "
  diagnosis_contract+="- the guard blocks something the contract already forbids, and the current prescription is clear → the guard is right and the agent's behaviour is the defect; fix the executable guidance or validation that failed to produce compliance, never the guard; "
  diagnosis_contract+="- the guard blocks mandated work → the guard is a gap; narrow it to the minimum that unblocks the real work."

  [ "$flat" = "$diagnosis_contract" ]
}

check_outcome_throughput_contract() { # skill
  local throughput_contract flat
  grep -Fq '| **Outcome throughput** |' "$1" || return 1
  flat="$(LC_ALL=C awk '
    /^\*\*Outcome throughput counts verified completions, not activity\.\*\*/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1" | LC_ALL=C tr '\n' ' ' | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -d '*' | LC_ALL=C sed -E 's/[[:space:]]+/ /g; s/ $//')"
  throughput_contract="outcome throughput counts verified completions, not activity. for each short and long window, record completed sessions, verified terminal outcomes, and terminal outcomes per completed session. "
  throughput_contract+="track sessions with at least one value-bearing state transition, unique work items advanced, and intermediate transitions under a separately named execution flow heading. these are leading indicators for diagnosis, never outcome-throughput numerators and never evidence that an intervention worked. count each work item once per scoring window and report revisits separately. "
  throughput_contract+="terminal outcomes are deployment-defined completions that deliver the work, for example a merged change, resolved work item, shipped release, verified production repair, or recorded decision when the decision is the deliverable. "
  throughput_contract+="run reports, memory writes, status comments, review requests, duplicate artifacts, and waiting are not terminal outcomes. keep substantive-versus-filler mix visible. missing session-to-outcome attribution is unknown, never zero. "
  throughput_contract+="throughput never outranks its floors. do not combine throughput or any companion parameter into a weighted or composite score. every throughput comparison carries companion raw metrics for every other applicable scorecard parameter. "
  throughput_contract+="higher throughput counts as improvement only when every declared companion floor is unchanged or better; any parameter regression makes the hypothesis fail regardless of throughput and triggers the revert-first rule. "
  throughput_contract+="a throughput hypothesis records its throughput baseline numerator, denominator, and observation volume plus companion floor baselines and thresholds for every applicable parameter under the same verification window."

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
  self_contract+="for the observation plane, report at minimum: scorecard coverage; diagnostic calibration as confirmed, false-positive, and unknown findings; hypothesis discipline as eligible, overdue, working, not-working, and no-verdict hypotheses; intervention effectiveness as verified-working changes per eligible shipped change; observer reliability and efficiency; and self-improvement outcome throughput as terminal verified rollouts. productive improver sessions and work advanced are execution-flow leading indicators, not improvement verdicts. "
  self_contract+="observation-plane verdicts require evidence independent of the improver run being scored: deterministic recomputation from an immutable or read-only source, or verification by a separate eligible run or instance. when the same improver instance's assertion is the only evidence, record unknown, never success. "
  self_contract+="pull requests opened, metrics added, words changed, hypotheses opened, reports, and memory writes are activity, not observer improvement. a failed or null hypothesis is calibration evidence and is never erased or relabelled to make the observer look better. "
  self_contract+="metric evolution is allowed when measured behavior exposes a coverage gap. version the metric definition, source, inclusion and exclusion rules, known blind spots, and effective timestamp; preserve the prior series and its bad news. never delete, rename, rebase, or narrow a metric merely because it regressed. unavailable attribution remains unknown. "
  self_contract+="a self-referential change cannot validate itself with only a metric it introduced or changed. a version-controlled change needs an independent green current-head review with all findings resolved. a runtime-local change instead needs an independently performed post-dispatch read-back against the recorded pre-change baseline through the consumer's declared runtime verification mechanism; the writer's immediate read-back is not independent verification. both paths also require unchanged companion floors for every applicable scorecard parameter and post-change evidence from the next eligible window; where possible keep one unchanged holdout measure. any self-improvement that weakens those checks fails regardless of its apparent observer score."

  [ "$flat" = "$self_contract" ]
}

check_research_fallback_contract() { # skill
  local clause flat flat_lower section
  section="$(LC_ALL=C awk '
    /^## 3a\. Research fallback/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1")"
  [ -n "$section" ] || return 1
  flat="$(tr '\n' ' ' <<<"$section" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  flat_lower="$(tr '[:upper:]' '[:lower:]' <<<"$flat")"

  while IFS= read -r clause; do
    case "$flat" in
      *"$clause"*) ;;
      *) return 1 ;;
    esac
  done <<'CLAUSES'
No-change fallback is research, never idle
improvement is actionable, run one **mandatory, bounded state-of-the-art research pass**
consumer-declared research budget
**first** of 20 minutes elapsed, 12 search or tool calls, or **eight primary sources**
consumer budget may tighten but never exceed these hard maxima
hard maxima cover discovery, disposition, persistence, and cursor advancement
Reserve at least two minutes and two tool calls inside the effective budget
Do not launch a discovery call that would consume the finalization reserve
Give every search or tool call a per-call deadline or cancellation timeout
discovery calls use the remaining discovery allowance and finalization calls use the reserved remaining pass allowance
cursor-selected topic
pending hypothesis
non-confounding
retain `QUERY-UNKNOWN`
leave the cursor unchanged
do not skip ahead
durable research cursor
Deduplicate against every existing issue, pull request, hypothesis, or research candidate
atomically claim the current cursor value
expiring lease
compare-and-set
stale claim
takeover
unexpired claim conflicts
lease duration to cover the declared pass bound, or renew it with a heartbeat
fencing token
compare-and-set verifies that token still owns the lease
one transaction or compare-and-set operation
validates the fencing token, records exactly one outcome, and advances the cursor
idempotency key stable for the claimed cursor value
durable, never-reused transition ID
Record the transition ID atomically with the cursor claim
takeover inherits the same transition ID
validates the fencing token on every write
outcome sink conditionally accepts the write only when the current fencing token matches in that same operation
If either conditional write is unavailable, retain `QUERY-UNKNOWN`
current primary sources
publication/release/version date
access/retrieval date
Research is discovery evidence, never authorization
current baseline capability
expected outcome
verification metric
`ENGINEER-CANDIDATE`
`IMPROVER-CANDIDATE`
`RESEARCH-CANDIDATE`
Research alone never authorizes or ships a change or self-modification
`RESEARCH-NO-CANDIDATE`
question, sources checked, and why each lead failed
advance the topic cursor exactly once
blocker prevents completion
routed candidate, `RESEARCH-NO-CANDIDATE`, or `QUERY-UNKNOWN`
neither a telemetry-backed nor direct-maintainer-directed improvement was actionable
fallback was not run
If either source selected actionable work
name the telemetry-backed or direct-maintainer-directed action path
discovery activity, **not a terminal improvement outcome**
CLAUSES

  case "$flat_lower" in
    *"do not give every search or tool call a per-call deadline or cancellation timeout"*|*"never give every search or tool call a per-call deadline or cancellation timeout"*) return 1 ;;
  esac
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

if check_diagnosis_contract "$skill"; then
  printf '  ✅ live skill distinguishes guard, agent, and prescription defects\n'
else
  printf '  ❌ live skill can blame a guard or agent for a stale prescription\n' >&2
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

if check_research_fallback_contract "$skill"; then
  printf '  ✅ live skill turns an evidence-clean run into bounded research and routed candidates\n'
else
  printf '  ❌ live skill can stop idle when telemetry exposes no actionable improvement\n' >&2
  fail=1
fi

if check_corpus_coverage_contract "$skill"; then
  printf '  ✅ live skill enumerates delegated transcripts and rejects a filter-sharing control\n'
else
  printf '  ❌ live skill can measure a partial corpus and call a shared-filter recount a control\n' >&2
  fail=1
fi

if check_floor_disposition_contract "$skill"; then
  printf '  ✅ live skill reads a bounded no-regression sample as HELD within its coverage\n'
else
  printf '  ❌ live skill can file gathered floor evidence as UNMEASURED and park a hypothesis forever\n' >&2
  fail=1
fi

# One isolating ablation per floor-disposition conjunct, taken against the REAL skill so the
# fixture cannot silently drift away from the text it claims to pin. cmp-guarded: a sed that
# matched nothing would otherwise "pass" while proving the conjunct discriminates nothing.
while IFS='|' read -r label expr; do
  [ -n "$label" ] || continue
  bad="$tmp/floor-bad-$label.md"
  sed -E "$expr" "$skill" >"$bad"
  if cmp -s "$skill" "$bad"; then
    printf '  ❌ floor ablation %s changed nothing\n' "$label" >&2
    fail=1
  elif check_floor_disposition_contract "$bad"; then
    printf '  ❌ floor ablation %s still passes\n' "$label" >&2
    fail=1
  else
    printf '  ✅ floor ablation %s fails closed\n' "$label"
  fi
done <<'ABL'
three-dispositions|s/three dispositions/several dispositions/
regressed-label|s/\*\*REGRESSED\*\*/**FAILED**/
held-within-coverage|s/\*\*within a stated coverage\*\*/**within some coverage**/
bounded-never-unmeasured|s/never UNMEASURED/sometimes UNMEASURED/
absence-only|s/only the absence of admissible evidence is UNMEASURED/absence of evidence is UNMEASURED/
unscoreable|s/unscoreable in principle/hard to score/
coverage-adjacent|s/State the coverage next to the disposition/Coverage may be recorded separately/
bounded-unmeasured|s/three consecutive eligible dispatches/several dispatches/
unmeasured-binding|s/A floor recorded UNMEASURED for the same/A floor recorded for the same/
same-hypothesis-binding|s/UNMEASURED for the same/UNMEASURED for a different/
tracked-work|s/becomes tracked work/is worth noting/
ABL

# A contradiction inserted ALONGSIDE the correct text: every positive conjunct still matches, so
# only the forbidden-phrase guard can catch it.
while IFS='|' read -r label sentence; do
  [ -n "$label" ] || continue
  bad="$tmp/floor-contradiction-$label.md"
  awk -v s="$sentence" '/^## 6\./ && !ins {print "   " s; print ""; ins=1} {print}' "$skill" >"$bad"
  if cmp -s "$skill" "$bad"; then
    printf '  ❌ floor contradiction %s changed nothing\n' "$label" >&2
    fail=1
  elif check_floor_disposition_contract "$bad"; then
    printf '  ❌ contradictory %s floor guidance unexpectedly passes\n' "$label" >&2
    fail=1
  else
    printf '  ✅ contradictory %s floor guidance fails closed\n' "$label"
  fi
done <<'CON'
always-unmeasured|A bounded sample is always UNMEASURED.
unbounded-ok|An unbounded NOT-YET-DUE is acceptable.
gathered-unknown|Gathered evidence within a bounded coverage is UNMEASURED.
CON

diagnosis_good="$tmp/diagnosis-good.md"
cat >"$diagnosis_good" <<'EOF'
## 3. Diagnose

- **Is the guard wrong, is the agent wrong, or is the prescription wrong?** They look identical in
  telemetry — all appear as a blocked action. Trace which definition, prompt, skill, loader, or durable
  memory prescribed the behaviour before changing the guard or faulting the executing agent:
  - the guard blocks something the contract **already forbids**, but the agent followed a stale or
    conflicting prescription → the guard is right and the root defect is the prescription; repair the
    canonical upstream definition, prompt, skill, loader, or memory and its stale projection, never the
    guard;
  - the guard blocks something the contract **already forbids**, and the current prescription is clear
    → the guard is right and **the agent's behaviour is the defect**; fix the executable guidance or
    validation that failed to produce compliance, never the guard;
  - the guard blocks **mandated work** → the guard is a **gap**; narrow it to the minimum that unblocks
    the real work.

---
EOF

if check_diagnosis_contract "$diagnosis_good"; then
  printf '  ✅ complete three-way diagnosis contract passes\n'
else
  printf '  ❌ complete three-way diagnosis contract unexpectedly fails\n' >&2
  fail=1
fi

diagnosis_bad="$tmp/diagnosis-bad.md"
sed 's/, or is the prescription wrong//' "$diagnosis_good" >"$diagnosis_bad"
if check_diagnosis_contract "$diagnosis_bad"; then
  printf '  ❌ missing prescription diagnosis unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing prescription diagnosis fails closed\n'
fi

diagnosis_no_stale="$tmp/diagnosis-no-stale.md"
sed 's/a stale or/a/' "$diagnosis_good" >"$diagnosis_no_stale"
if check_diagnosis_contract "$diagnosis_no_stale"; then
  printf '  ❌ prescription without stale provenance unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ prescription without stale provenance fails closed\n'
fi

diagnosis_no_followed="$tmp/diagnosis-no-followed.md"
sed 's/the agent followed a stale or/a stale or/' \
  "$diagnosis_good" >"$diagnosis_no_followed"
if check_diagnosis_contract "$diagnosis_no_followed"; then
  printf '  ❌ stale prescription without agent-followed causality unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ stale prescription without agent-followed causality fails closed\n'
fi

diagnosis_negated_trace="$tmp/diagnosis-negated-trace.md"
sed 's/Trace which/Do not trace which/' "$diagnosis_good" >"$diagnosis_negated_trace"
if check_diagnosis_contract "$diagnosis_negated_trace"; then
  printf '  ❌ negated instruction-source trace unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ negated instruction-source trace fails closed\n'
fi

diagnosis_negated_repair="$tmp/diagnosis-negated-repair.md"
sed 's/repair the/do not repair the/' \
  "$diagnosis_good" >"$diagnosis_negated_repair"
if check_diagnosis_contract "$diagnosis_negated_repair"; then
  printf '  ❌ negated prescription repair unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ negated prescription repair fails closed\n'
fi

diagnosis_weaken_guard="$tmp/diagnosis-weaken-guard.md"
sed 's/never the guard/always weaken the guard/' \
  "$diagnosis_good" >"$diagnosis_weaken_guard"
if check_diagnosis_contract "$diagnosis_weaken_guard"; then
  printf '  ❌ guard-weakening reversal unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ guard-weakening reversal fails closed\n'
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
| **Outcome throughput** | verified terminal outcomes per completed session | the agent completes too little |

**Outcome throughput counts verified completions, not activity.** For each short and long window,
record completed sessions, verified terminal outcomes, and terminal outcomes per completed session.
Track sessions with at least one value-bearing state transition, unique work items advanced, and
intermediate transitions under a separately named **Execution flow** heading. These are leading
indicators for diagnosis, never outcome-throughput numerators and never evidence that an intervention
worked. Count each work item once per scoring window and report revisits separately. Terminal outcomes are
deployment-defined completions that
deliver the work, for example a merged change, resolved work item, shipped release, verified production
repair, or recorded decision when the decision is the deliverable. Run reports, memory writes, status
comments, review requests, duplicate artifacts, and waiting are not terminal outcomes. Keep
substantive-versus-filler mix visible. Missing session-to-outcome attribution is UNKNOWN, never zero.

**Throughput never outranks its floors.** Do not combine throughput or any companion parameter into a
weighted or composite score. Every throughput comparison carries companion raw metrics for every other
applicable scorecard parameter. Higher throughput counts as improvement only when every declared
companion floor is unchanged or better; any parameter regression makes the hypothesis fail regardless
of throughput and triggers the revert-first rule. A throughput hypothesis records its throughput
baseline numerator, denominator, and observation volume plus companion floor baselines and thresholds
for every applicable parameter under the same verification window.

---
EOF

if check_outcome_throughput_contract "$throughput_good"; then
  printf '  ✅ complete outcome-throughput contract passes\n'
else
  printf '  ❌ complete outcome-throughput contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in table short_window verified_outcomes flow_separation no_flow_verdict dedup terminal_definition exclusions substantive_mix unknown_attribution composite_guard companion_metrics floor_veto hypothesis_floors; do
  fixture="$tmp/throughput-$missing.md"
  case "$missing" in
    table) sed '/| \*\*Outcome throughput\*\* |/d' "$throughput_good" >"$fixture" ;;
    short_window) sed 's/each short and long window/each available window/' "$throughput_good" >"$fixture" ;;
    verified_outcomes) sed 's/verified terminal outcomes/terminal activity/g' "$throughput_good" >"$fixture" ;;
    flow_separation) sed 's/separately named \*\*Execution flow\*\*/shared outcome throughput/' "$throughput_good" >"$fixture" ;;
    no_flow_verdict) sed 's/never evidence that an intervention/and evidence that an intervention/' "$throughput_good" >"$fixture" ;;
    dedup) sed 's/Count each work item once per scoring window/Count each work item once per session/' "$throughput_good" >"$fixture" ;;
    terminal_definition) sed 's/deployment-defined/activity-defined/' "$throughput_good" >"$fixture" ;;
    exclusions) sed 's/Run reports/Activity reports/' "$throughput_good" >"$fixture" ;;
    substantive_mix) sed 's/substantive-versus-filler/artifact-volume/' "$throughput_good" >"$fixture" ;;
    unknown_attribution) sed 's/Missing session-to-outcome attribution is UNKNOWN, never zero/Missing attribution is zero/' "$throughput_good" >"$fixture" ;;
    composite_guard) sed 's/weighted/single/' "$throughput_good" >"$fixture" ;;
    companion_metrics) sed 's/Every throughput comparison carries companion raw metrics for every other/Throughput comparisons ignore every other/' "$throughput_good" >"$fixture" ;;
    floor_veto) sed 's/any parameter regression makes the hypothesis fail/a throughput gain offsets a parameter regression/' "$throughput_good" >"$fixture" ;;
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
change; observer reliability and efficiency; and self-improvement outcome throughput as terminal verified
rollouts. Productive Improver sessions and work advanced are execution-flow leading indicators, not
improvement verdicts.

Observation-plane verdicts require evidence independent of the Improver run being scored: deterministic
recomputation from an immutable or read-only source, or verification by a separate eligible run or
instance. When the same Improver instance's assertion is the only evidence, record UNKNOWN, never
success.

Pull requests opened, metrics added, words changed, hypotheses opened, reports, and memory writes are
activity, not observer improvement. A failed or null hypothesis is calibration evidence and is never
erased or relabelled to make the observer look better.

Metric evolution is allowed when measured behavior exposes a coverage gap. Version the metric
definition, source, inclusion and exclusion rules, known blind spots, and effective timestamp; preserve
the prior series and its bad news. Never delete, rename, rebase, or narrow a metric merely because it
regressed. Unavailable attribution remains UNKNOWN.

A self-referential change cannot validate itself with only a metric it introduced or changed. A
version-controlled change needs an independent green current-head review with all findings resolved. A runtime-local change instead needs
an independently performed post-dispatch read-back against the recorded pre-change baseline through
the consumer's declared runtime verification mechanism; the writer's immediate read-back is not
independent verification. Both paths also require unchanged companion floors for every applicable scorecard parameter and
post-change evidence from the next eligible window; where possible keep one unchanged holdout measure.
Any self-improvement that
weakens those checks fails regardless of its apparent observer score.

---
EOF

if check_self_observation_contract "$self_good"; then
  printf '  ✅ complete self-observation contract passes\n'
else
  printf '  ❌ complete self-observation contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in table separate_planes no_average raw_evidence calibration hypothesis_discipline effectiveness terminal_rollout_only independent_score unknown_self_score anti_activity failed_hypothesis metric_version history_preservation unknown_attribution independent_review runtime_readback immediate_readback holdout floor_veto; do
  fixture="$tmp/self-$missing.md"
  case "$missing" in
    table) sed '/| \*\*Observer effectiveness\*\* |/d' "$self_good" >"$fixture" ;;
    separate_planes) sed 's/two named scorecards/one combined scorecard/' "$self_good" >"$fixture" ;;
    no_average) sed 's/Never average them/Average them/' "$self_good" >"$fixture" ;;
    raw_evidence) sed 's/raw numerators, denominators, observation volumes/summary scores/' "$self_good" >"$fixture" ;;
    calibration) sed 's/diagnostic calibration/diagnostic count/' "$self_good" >"$fixture" ;;
    hypothesis_discipline) sed 's/hypothesis discipline/hypothesis volume/' "$self_good" >"$fixture" ;;
    effectiveness) sed 's/intervention effectiveness as verified-working changes/intervention effectiveness as changes/' "$self_good" >"$fixture" ;;
    terminal_rollout_only) sed 's/execution-flow leading indicators, not/execution-flow leading indicators and/' "$self_good" >"$fixture" ;;
    independent_score) sed 's/require evidence independent of the Improver run being scored/use the Improver run being scored/' "$self_good" >"$fixture" ;;
    unknown_self_score) sed 's/record UNKNOWN, never/record/' "$self_good" >"$fixture" ;;
    anti_activity) sed 's/activity, not observer improvement/observer improvement/' "$self_good" >"$fixture" ;;
    failed_hypothesis) sed 's/evidence and is never/evidence and may be/' "$self_good" >"$fixture" ;;
    metric_version) sed 's/Version the metric/Update the metric/' "$self_good" >"$fixture" ;;
    history_preservation) sed 's/effective timestamp; preserve/effective timestamp; replace/' "$self_good" >"$fixture" ;;
    unknown_attribution) sed 's/Unavailable attribution remains UNKNOWN/Unavailable attribution is zero/' "$self_good" >"$fixture" ;;
    independent_review) sed 's/an independent green current-head review with all findings resolved/self-review/' "$self_good" >"$fixture" ;;
    runtime_readback) sed 's/an independently performed post-dispatch read-back/an immediate read-back/' "$self_good" >"$fixture" ;;
    immediate_readback) sed "s/the writer's immediate read-back is not/the writer's immediate read-back is/" "$self_good" >"$fixture" ;;
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

research_good="$tmp/research-good.md"
cat >"$research_good" <<'EOF'
## 3a. Research fallback — no idle no-op

No-change fallback is research, never idle. When no telemetry-backed improvement is actionable, run
one **mandatory, bounded state-of-the-art research pass**. Use the consumer-declared research budget;
otherwise stop at the **first** of 20 minutes elapsed, 12 search or tool calls, or **eight primary
sources**. A consumer budget may tighten but never exceed these hard maxima. The hard maxima cover
discovery, disposition, persistence, and cursor advancement. Reserve at least two minutes and two tool
calls inside the effective budget. Do not launch a discovery call that would consume the finalization
reserve. Give every search or tool call a per-call deadline or cancellation timeout:
discovery calls use the remaining discovery allowance and finalization calls use the reserved remaining
pass allowance. Compare the cursor-selected topic with every pending hypothesis and proceed only with
non-confounding work; on overlap retain `QUERY-UNKNOWN`, leave the cursor unchanged, and do not skip
ahead. Rotate with a durable research cursor. Deduplicate against every existing issue, pull request,
hypothesis, or research candidate. In multiple instances, atomically claim the current cursor value
with an expiring lease and compare-and-set. Recover a stale claim only by compare-and-set takeover; if
an unexpired claim conflicts, retain `QUERY-UNKNOWN` and leave the cursor unchanged. Set the lease
duration to cover the declared pass bound, or renew it with a heartbeat. Carry a fencing token;
compare-and-set verifies that token still owns the lease before commit. Persist with one transaction
or compare-and-set operation that validates the fencing token, records exactly one outcome, and
advances the cursor. Otherwise use an idempotency key stable for the claimed cursor value and a
durable, never-reused transition ID. Record the transition ID atomically with the cursor claim; every
takeover inherits the same transition ID. Every recovery validates the fencing token on every write.
The outcome sink conditionally accepts the write only when the current fencing token matches in that
same operation. If either conditional write is unavailable, retain `QUERY-UNKNOWN`.

Use current primary sources and record each publication/release/version date and access/retrieval
date. Research is discovery evidence, never authorization. Compare current baseline capability,
expected outcome, and verification metric. Route `ENGINEER-CANDIDATE`, `IMPROVER-CANDIDATE`, or
`RESEARCH-CANDIDATE`. Research alone never authorizes or ships a change or self-modification. A null
result is `RESEARCH-NO-CANDIDATE` with the question, sources checked, and why each lead failed. Every
completed pass must advance the topic cursor exactly once. If a blocker prevents completion, retain
`QUERY-UNKNOWN` and leave the cursor unchanged. When neither a telemetry-backed nor
direct-maintainer-directed improvement was actionable, report one routed candidate,
`RESEARCH-NO-CANDIDATE`, or `QUERY-UNKNOWN`. If either source selected actionable work, say the
fallback was not run and name the telemetry-backed or direct-maintainer-directed action path. Research
is discovery activity, **not a terminal improvement outcome**.

---
EOF

if check_research_fallback_contract "$research_good"; then
  printf '  ✅ complete research-fallback contract passes\n'
else
  printf '  ❌ complete research-fallback contract unexpectedly fails\n' >&2
  fail=1
fi

research_scope_bad="$tmp/research-scope-bad.md"
{
  printf '## 3a. Research fallback — no idle no-op\n\n'
  printf '**No-change fallback is research, never idle.** This section is incomplete.\n\n---\n\n'
  cat "$research_good"
} >"$research_scope_bad"
if check_research_fallback_contract "$research_scope_bad"; then
  printf '  ❌ research contract can be satisfied by prose outside its canonical section\n' >&2
  fail=1
else
  printf '  ✅ research contract is scoped to its canonical section\n'
fi

research_negated_bad="$tmp/research-negated-bad.md"
sed 's/one \*\*mandatory/do not run one **mandatory/' "$research_good" >"$research_negated_bad"
if check_research_fallback_contract "$research_negated_bad"; then
  printf '  ❌ a negated mandatory research fallback unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ a negated mandatory research fallback fails closed\n'
fi

research_timeout_negated_bad="$tmp/research-timeout-negated-bad.md"
sed 's/Give every search or tool call/Do not give every search or tool call/' "$research_good" >"$research_timeout_negated_bad"
if check_research_fallback_contract "$research_timeout_negated_bad"; then
  printf '  ❌ a negated per-call deadline unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ a negated per-call deadline fails closed\n'
fi

for missing in mandatory bounded enforceable_bound budget_clamp finalization_scope finalization_reserve every_call per_call_timeout allowance_routing current primary source_dates authorization baseline expected engineer_route improver_route research_route dedup dedup_hypothesis pending_confound topic_skip cursor_atomic lease_recovery lease_fencing outcome_atomic outcome_exactly_once idempotency idempotency_scope fencing_every_write conditional_outcome conditional_unavailable report_predicate report_not_run unrun_scope research_only null_question null_sources null_rationale null_cursor blocked_cursor report_unknown terminal_guard; do
  fixture="$tmp/research-$missing.md"
  case "$missing" in
    mandatory) sed 's/mandatory, bounded/optional, bounded/' "$research_good" >"$fixture" ;;
    bounded) sed 's/mandatory, bounded/mandatory, broad/' "$research_good" >"$fixture" ;;
    enforceable_bound) sed 's/of 20 minutes/of 200 minutes/' "$research_good" >"$fixture" ;;
    budget_clamp) sed 's/never exceed/may exceed/' "$research_good" >"$fixture" ;;
    finalization_scope) sed 's/discovery, disposition, persistence, and cursor advancement/discovery only/' "$research_good" >"$fixture" ;;
    finalization_reserve) sed 's/Reserve at least two minutes and two tool/Reserve no/' "$research_good" >"$fixture" ;;
    every_call) sed 's/Give every search or tool/Give some/' "$research_good" >"$fixture" ;;
    per_call_timeout) sed 's/per-call deadline or cancellation timeout/best-effort timeout/' "$research_good" >"$fixture" ;;
    allowance_routing) sed 's/finalization calls use the reserved remaining/finalization calls use the exhausted discovery/' "$research_good" >"$fixture" ;;
    current) sed 's/current primary sources/recent primary sources/' "$research_good" >"$fixture" ;;
    primary) sed 's/current primary sources/current commentary/' "$research_good" >"$fixture" ;;
    source_dates) sed 's/publication\/release\/version date/source date/' "$research_good" >"$fixture" ;;
    authorization) sed 's/never authorization/sufficient authorization/' "$research_good" >"$fixture" ;;
    baseline) sed 's/current baseline capability/current trend/' "$research_good" >"$fixture" ;;
    expected) sed 's/expected outcome/general benefit/' "$research_good" >"$fixture" ;;
    engineer_route) sed $'s/`ENGINEER-CANDIDATE`/`PRODUCT-CANDIDATE`/' "$research_good" >"$fixture" ;;
    improver_route) sed $'s/`IMPROVER-CANDIDATE`/`PROCESS-CANDIDATE`/' "$research_good" >"$fixture" ;;
    research_route) sed $'s/`RESEARCH-CANDIDATE`/`UNOWNED-CANDIDATE`/' "$research_good" >"$fixture" ;;
    dedup) sed 's/Deduplicate/Repeat/' "$research_good" >"$fixture" ;;
    dedup_hypothesis) sed 's/hypothesis, or/hypothesis or/' "$research_good" >"$fixture" ;;
    pending_confound) sed 's/non-confounding/confounding/' "$research_good" >"$fixture" ;;
    topic_skip) sed 's/do not skip/skip/' "$research_good" >"$fixture" ;;
    cursor_atomic) sed 's/atomically claim the current cursor/read the current cursor/' "$research_good" >"$fixture" ;;
    lease_recovery) sed 's/expiring lease/permanent lock/' "$research_good" >"$fixture" ;;
    lease_fencing) sed 's/fencing token/ordinary token/' "$research_good" >"$fixture" ;;
    outcome_atomic) sed 's/one transaction/separate operations/' "$research_good" >"$fixture" ;;
    outcome_exactly_once) sed 's/records exactly one outcome/records an outcome/' "$research_good" >"$fixture" ;;
    idempotency) sed 's/idempotency key stable for the claimed cursor value/random request key/' "$research_good" >"$fixture" ;;
    idempotency_scope) sed 's/durable, never-reused transition ID/reusable topic name/' "$research_good" >"$fixture" ;;
    fencing_every_write) sed 's/validates the fencing token on every write/checks the token during claim/' "$research_good" >"$fixture" ;;
    conditional_outcome) sed 's/conditionally accepts the write/unconditionally accepts the write/' "$research_good" >"$fixture" ;;
    conditional_unavailable) sed $'s/If either conditional write is unavailable, retain `QUERY-UNKNOWN`/If conditional writes are unavailable, continue anyway/' "$research_good" >"$fixture" ;;
    report_predicate) sed 's/neither a telemetry-backed nor/only when no/' "$research_good" >"$fixture" ;;
    report_not_run) sed 's/fallback was not run/fallback completed/' "$research_good" >"$fixture" ;;
    unrun_scope) sed 's/If either source selected actionable work/If only direct maintainer direction selected actionable work/' "$research_good" >"$fixture" ;;
    research_only) sed 's/never authorizes/authorizes/' "$research_good" >"$fixture" ;;
    null_question) sed 's/question, sources checked/inquiry, sources checked/' "$research_good" >"$fixture" ;;
    null_sources) sed 's/sources checked/sources listed/' "$research_good" >"$fixture" ;;
    null_rationale) sed 's/each lead failed/lead disposition/' "$research_good" >"$fixture" ;;
    null_cursor) sed 's/advance the topic cursor exactly once/repeat the same topic/' "$research_good" >"$fixture" ;;
    blocked_cursor) sed 's/leave the cursor unchanged/advance the cursor/' "$research_good" >"$fixture" ;;
    report_unknown) sed $'s/or `QUERY-UNKNOWN`/or UNKNOWN/' "$research_good" >"$fixture" ;;
    terminal_guard) sed 's/discovery activity, \*\*not/discovery activity, **always/' "$research_good" >"$fixture" ;;
  esac
  if check_research_fallback_contract "$fixture"; then
    printf '  ❌ missing research-fallback %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing research-fallback %s fails closed\n' "$missing"
  fi
done

research_blocked_good="$tmp/research-blocked-good.md"
cp "$research_good" "$research_blocked_good"
if check_research_fallback_contract "$research_blocked_good"; then
  printf '  ✅ blocked research preserves QUERY-UNKNOWN and the cursor\n'
else
  printf '  ❌ blocked research contract unexpectedly fails\n' >&2
  fail=1
fi

research_blocked_bad="$tmp/research-blocked-bad.md"
sed $'s/`QUERY-UNKNOWN`/`RESEARCH-NO-CANDIDATE`/g' "$research_blocked_good" >"$research_blocked_bad"
if check_research_fallback_contract "$research_blocked_bad"; then
  printf '  ❌ blocked research can masquerade as a completed null result\n' >&2
  fail=1
else
  printf '  ✅ blocked research cannot masquerade as RESEARCH-NO-CANDIDATE\n'
fi

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

coverage_good="$tmp/coverage-good.md"
cat >"$coverage_good" <<'EOF'
## 1. Gather

Delegated work is stored separately from the parent session's transcript, commonly nested beneath it.
An enumeration that walks only the top level of the session store omits every one of them. Enumerate
delegated transcripts explicitly and report coverage alongside every measurement: files enumerated,
and the share of records drawn from delegated sessions.
Build an independent expected delegated-session inventory from runtime metadata.
Report every expected session missing from the transcript walk.
A control must vary the suspected filter, not merely the method.
A control that shares the enumeration is not a control.
Re-derive a comparable count with the suspected filter removed.
Reconcile the delta to the records that filter excluded; only an unexplained residual is a finding.

---
EOF

if check_corpus_coverage_contract "$coverage_good"; then
  printf '  ✅ complete corpus-coverage contract passes\n'
else
  printf '  ❌ complete corpus-coverage contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in separate_storage top_level coverage_share vary_filter not_a_control \
  explicit_enumeration files_enumerated files_enumerated_unlinked delegated_scope \
  files_enumerated_before independent_inventory missing_records common_basis \
  reconcile_delta; do
  fixture="$tmp/coverage-$missing.md"
  case "$missing" in
    separate_storage) sed 's/stored separately/stored together/' "$coverage_good" >"$fixture" ;;
    top_level) sed 's/only the top level of the session store/across the whole store/' "$coverage_good" >"$fixture" ;;
    coverage_share) sed 's/the share of records/the number of files/' "$coverage_good" >"$fixture" ;;
    vary_filter) sed 's/control must vary the suspected filter/control should use a second tool/' "$coverage_good" >"$fixture" ;;
    not_a_control) sed 's/shares the enumeration is not a control/shares the enumeration is acceptable/' "$coverage_good" >"$fixture" ;;
    explicit_enumeration) sed 's/^delegated transcripts explicitly and report/delegated transcripts and report/' "$coverage_good" >"$fixture" ;;
    files_enumerated) sed 's/: files enumerated,/:/' "$coverage_good" >"$fixture" ;;
    delegated_scope) sed 's/drawn from delegated sessions/drawn from all sessions/' "$coverage_good" >"$fixture" ;;
    files_enumerated_before) sed 's/measurement: files enumerated,/measurement. Files enumerated are listed in a separate audit./' "$coverage_good" >"$fixture" ;;
    files_enumerated_unlinked) sed -e 's/measurement: files enumerated,/measurement:/' \
      -e 's/drawn from delegated sessions\./drawn from delegated sessions. A separate audit lists files enumerated./' \
      "$coverage_good" >"$fixture" ;;
    independent_inventory) sed 's/independent expected delegated-session inventory/local delegated-session sample/' "$coverage_good" >"$fixture" ;;
    missing_records) sed 's/Report every expected session missing from the transcript walk/Report the delegated share/' "$coverage_good" >"$fixture" ;;
    common_basis) sed 's/Re-derive a comparable count/Re-derive the raw count/' "$coverage_good" >"$fixture" ;;
    reconcile_delta) sed 's/Reconcile the delta/Accept the delta/' "$coverage_good" >"$fixture" ;;
  esac
  if ! cmp -s "$coverage_good" "$fixture"; then
    if check_corpus_coverage_contract "$fixture"; then
      printf '  ❌ missing corpus-coverage %s unexpectedly passed\n' "$missing" >&2
      fail=1
    else
      printf '  ✅ missing corpus-coverage %s fails closed\n' "$missing"
    fi
  else
    printf '  ❌ corpus-coverage ablation %s changed nothing\n' "$missing" >&2
    fail=1
  fi
done

coverage_outside_gather_bad="$tmp/coverage-outside-gather-bad.md"
{
  sed 's/^## 1\. Gather$/## 0. Pre-flight/' "$coverage_good"
  cat <<'EOF'
## 1. Gather

Gather some telemetry.

---
EOF
} >"$coverage_outside_gather_bad"
if check_corpus_coverage_contract "$coverage_outside_gather_bad"; then
  printf '  ❌ corpus coverage can be satisfied outside the canonical Gather section\n' >&2
  fail=1
else
  printf '  ✅ corpus coverage is scoped to the canonical Gather section\n'
fi

coverage_negated_bad="$tmp/coverage-negated-bad.md"
sed 's/Enumerate$/Do not enumerate/' \
  "$coverage_good" >"$coverage_negated_bad"
if check_corpus_coverage_contract "$coverage_negated_bad"; then
  printf '  ❌ a negated delegated enumeration unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ a negated delegated enumeration fails closed\n'
fi

coverage_contradictory_bad="$tmp/coverage-contradictory-bad.md"
sed '/^---$/i\
A control that shares the enumeration is also a valid control.' \
  "$coverage_good" >"$coverage_contradictory_bad"
if check_corpus_coverage_contract "$coverage_contradictory_bad"; then
  printf '  ❌ contradictory shared-enumeration guidance unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ contradictory shared-enumeration guidance fails closed\n'
fi

check_deployment_liveness_contract() { # skill
  local flat flat_lower section
  section="$(LC_ALL=C awk '
    /^## 5\. Verify/ { capture=1 }
    capture && /^---$/ { exit }
    capture { print }
  ' "$1")"
  [ -n "$section" ] || return 1
  flat="$(tr '\n' ' ' <<<"$section" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  flat_lower="$(tr '[:upper:]' '[:lower:]' <<<"$flat")"

  # An adverse verdict must be gated on deployment, not merely stated near it.
  grep -Eqi 'before any adverse verdict[^.]{0,80}prove the intervention is deployed' <<<"$flat" || return 1
  # Deployment is established from CONTENT at the revision the runtime loads.
  grep -Eqi 'content at[^.]{0,80}revision the consuming deployment loads' <<<"$flat" || return 1
  # The insufficient evidence must be named, or "prove it is deployed" is satisfied by the merge.
  grep -Eqi 'upstream merge[^.]{0,140}version string[^.]{0,140}is not delivery' <<<"$flat" || return 1
  # The third forbidden signal must be pinned too. Without it the clause can drop the
  # authoring-PR check and still satisfy every other conjunct, so a green PR check becomes
  # a declarable substitute for delivery.
  grep -Eqi 'green check on the authoring pull request[^.]{0,80}is not delivery' <<<"$flat" || return 1
  # WHY a merge is not delivery: intermediate hops. Without this the rule reads as a formality.
  grep -Eqi '(synced|vendored)[^.]{0,100}only after every intermediate hop' <<<"$flat" || return 1
  # The verdict mapping must sit in ONE clause; split across sentences it pins no substitution.
  grep -Eqi 'not live is not-yet-due[^.]{0,80}blocked on rollout[^.]{0,60}never not-working' <<<"$flat" || return 1
  # The blockage is work to pursue, not a reason to revert.
  grep -Eqi 'stalled rollout is itself the finding' <<<"$flat" || return 1
  # The ladder's own unchanged branch must carry the liveness condition, or the gate above is
  # contradicted three lines later by the rule a reader actually executes.
  grep -Eqi 'metric unchanged[^.]{0,60}intervention proven live' <<<"$flat" || return 1
  # The OTHER adverse branch needs the same gate. A metric that moved the wrong way while the
  # intervention was never live indicts the rollout, not the diagnosis, so reverting on it
  # discards a change that was never given a chance to act.
  grep -Eqi 'wrong direction[^.]{0,120}intervention proven live' <<<"$flat" || return 1

  case "$flat_lower" in
    *"an upstream merge is sufficient"* | \
    *"a version string is sufficient"* | \
    *"a green check on the authoring pull request is sufficient"* | \
    *"score an undeployed intervention not-working"* | \
    *"not live is not-working"*) return 1 ;;
  esac
}

if check_deployment_liveness_contract "$skill"; then
  printf '  ✅ Verify gates an adverse verdict on proven deployment\n'
else
  printf '  ❌ Verify does not require deployment liveness before an adverse verdict\n' >&2
  fail=1
fi

liveness_good="$tmp/liveness-good.md"
cat >"$liveness_good" <<'EOF'
## 5. Verify

Before any adverse verdict, prove the intervention is deployed. Establish deployment by reading the
intervention's content at the revision the consuming deployment loads; an upstream merge, a version
string, or a green check on the authoring pull request is not delivery, because a synced or vendored
artifact reaches the runtime only after every intermediate hop lands. An intervention that is not
live is NOT-YET-DUE, blocked on rollout, never NOT-WORKING, and the stalled rollout is itself the
finding to pursue rather than a reason to revert.
- metric unchanged and the intervention proven live, the diagnosis was wrong.
- metric moved in the wrong direction, or a companion floor regressed, and the intervention proven live, revert first.

---
EOF

if check_deployment_liveness_contract "$liveness_good"; then
  printf '  ✅ liveness good fixture passes\n'
else
  printf '  ❌ liveness good fixture unexpectedly fails\n' >&2
  fail=1
fi

# One isolating ablation per conjunct. Each is cmp-guarded: a sed that changed nothing would
# otherwise "pass" the ablation while proving the conjunct discriminates nothing.
while IFS='|' read -r label expr; do
  [ -n "$label" ] || continue
  bad="$tmp/liveness-bad-$label.md"
  sed -E "$expr" "$liveness_good" >"$bad"
  if cmp -s "$liveness_good" "$bad"; then
    printf '  ❌ liveness ablation %s changed nothing\n' "$label" >&2
    fail=1
  elif check_deployment_liveness_contract "$bad"; then
    printf '  ❌ liveness ablation %s still passes\n' "$label" >&2
    fail=1
  else
    printf '  ✅ liveness ablation %s fails closed\n' "$label"
  fi
done <<'EOF'
gate|s/Before any adverse verdict, prove the intervention is deployed/Deployment is worth considering/
loaded-revision|s/revision the consuming deployment loads/latest upstream revision/
named-insufficient|s/an upstream merge, a version/a merge, a version/
hops|s/only after every intermediate hop lands/promptly/
verdict-map|s/never NOT-WORKING/and may also be NOT-WORKING/
pursue|s/stalled rollout is itself the/rollout is a separate concern and the/
ladder|s/metric unchanged and the intervention proven live/metric unchanged/
authoring-pr|s/, or a green check on the authoring pull request is not delivery/ is not delivery/
ladder-adverse|s/regressed, and the intervention proven live/regressed/
EOF

# One contradiction fixture per forbidden delivery signal, plus the inverse verdict mapping. Each is
# inserted ALONGSIDE the correct text, so every positive conjunct still matches and only these
# guards can catch it — which is exactly the case a single upstream-merge fixture missed.
while IFS='|' read -r label sentence; do
  [ -n "$label" ] || continue
  bad="$tmp/liveness-contradiction-$label.md"
  awk -v s="$sentence" '/^---$/ && !ins {print s; ins=1} {print}' "$liveness_good" >"$bad"
  if cmp -s "$liveness_good" "$bad"; then
    printf '  ❌ liveness contradiction %s changed nothing\n' "$label" >&2
    fail=1
  elif check_deployment_liveness_contract "$bad"; then
    printf '  ❌ contradictory %s guidance unexpectedly passes\n' "$label" >&2
    fail=1
  else
    printf '  ✅ contradictory %s guidance fails closed\n' "$label"
  fi
done <<'EOF'
upstream-merge|An upstream merge is sufficient.
version-string|A version string is sufficient.
authoring-pr|A green check on the authoring pull request is sufficient.
inverse-verdict|An intervention that is not live is NOT-WORKING.
EOF

if [ "$fail" -ne 0 ]; then
  printf '❌ agent-improvement contract test failed\n' >&2
  exit 1
fi

printf '✅ agent-improvement contract test passed\n'
