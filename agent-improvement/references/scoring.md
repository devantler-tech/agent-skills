# Score: provenance, outcome throughput, flow and the observer

Read this when filling the scorecard in step 2 of the agent-improvement loop. It is the complete
Score step; the skill keeps only its summary.

## 2. Score

Fill the scorecard and diff it against the previous run's, held in memory. Record raw numbers — trends
matter more than absolute values, and only a recorded number can trend.

**A metric that moved the wrong way outranks a new finding** — regression first. Verify any change
awaiting confirmation (step 5) **before** starting new work.

**Collision verdicts require writer provenance.** A cross-instance collision or two-writer race
requires evidence identifying at least two distinct writers or instances and the artifacts or shared
state on which they conflicted. Absent that distinct-writer provenance, a single session's stale edit
or dirty local merge is reliability or local-state evidence, not a coordination verdict. When
second-writer provenance is unavailable, keep the signal **UNKNOWN** or a candidate pending
investigation; do not count it as a collision.

**Outcome throughput counts verified completions, not activity.** For each short and long window,
record completed sessions, verified terminal outcomes, and terminal outcomes per completed session.
Track sessions with at least one value-bearing state transition, unique work items advanced, and
intermediate transitions under a separately named **Execution flow** heading. These are leading
indicators for diagnosis, never outcome-throughput numerators and never evidence that an intervention
worked. Count each work item once per scoring window and report revisits separately. Terminal outcomes are
deployment-defined completions that deliver the work, for example a merged change, resolved work item,
shipped release, verified production repair, or recorded decision when the decision is the deliverable.
Run reports, memory writes, status comments, review requests, duplicate artifacts, and waiting are not
terminal outcomes. Keep substantive-versus-filler mix visible. Missing session-to-outcome attribution
is UNKNOWN, never zero.

**Throughput never outranks its floors.** Do not combine throughput or any companion parameter into a
weighted or composite score. Every throughput comparison carries companion raw metrics for every other
applicable scorecard parameter. Higher throughput counts as improvement only when every declared
companion floor is unchanged or better; any parameter regression makes the hypothesis fail regardless
of throughput and triggers the revert-first rule. A throughput hypothesis records its throughput
baseline numerator, denominator, and observation volume plus companion floor baselines and thresholds
for every applicable parameter under the same verification window.

---

**Measure prioritization separately from throughput.** Every run's scorecard includes the
prioritization/flow parameter, using the [measurement contract](prioritization-flow.md).
Keep easy, substantive, and unclassified artifacts visible with source references. At each easier-work
selection, join observed actionability to actual starts through run end and record the oldest
alternative's age if it remained unstarted. Incomplete evidence stays UNKNOWN, never a healthy zero.
The reference's optional offline calculator computes observations, not authenticity or verdicts.

For a value-pull deployment, also inspect board priority, capacity, Ready waiting, original active
age, blocked time and verified delivery lead/cycle time. Version that cohort separately; retain the
historical issue-age series and quality/security floors rather than shrinking its denominator.

Compare like-for-like windows per role and instance. A rising easy-work share alongside repeatedly
aged unstarted work, after checking higher-priority incidents, existing-work completion, and real
blockers, is an ordinary prioritization finding for step 3. A necessary small repair is not filler,
and a large diff is not substantive by itself. Retain contrary evidence and every companion floor.

---

**The observer is one of its own measured subjects.** Keep two named scorecards: the execution plane
(the Agentic Engineer) and the observation plane (every Agent Improver instance). Never average them
together or let improvement in one hide regression in the other. Every required parameter reports
separate raw numerators, denominators, observation volumes, attribution coverage, and UNKNOWNs per role
and instance.

For the observation plane, report at minimum: scorecard coverage; diagnostic calibration as confirmed,
false-positive, and UNKNOWN findings; hypothesis discipline as eligible, overdue, WORKING, NOT-WORKING,
and NO-VERDICT hypotheses; intervention effectiveness as verified-working changes per eligible shipped
change; observer reliability and efficiency; and self-improvement outcome throughput as terminal
verified rollouts. Productive Improver sessions and work advanced are execution-flow leading
indicators, not improvement verdicts.

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
version-controlled change needs an independent green current-head review with all findings resolved. A
runtime-local change instead needs
an independently performed post-dispatch read-back against the recorded pre-change baseline through
the consumer's declared runtime verification mechanism; the writer's immediate read-back is not
independent verification. Both paths also require unchanged companion floors for every applicable
scorecard parameter and
post-change evidence from the next eligible window; where possible keep one unchanged holdout measure.
Any self-improvement that weakens those checks fails regardless of its apparent observer score.

---
