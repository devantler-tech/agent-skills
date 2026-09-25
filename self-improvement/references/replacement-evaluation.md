# Evaluate a replacement for a proven engineering procedure

Use this path when a learning from your own runs motivates replacing a trusted method: for example,
batching repository reads or changing a triage procedure. A corrected path, missing validate command,
or ordinary bug fix uses the normal tests and readiness gates. Do not turn every repair into an
experiment. A guardrail relaxation is rejected before this path; no measurement can authorize it.

## Resolve the companion protocol

The canonical evidence schema, evaluator and human brief belong to the **product-engineering** skill
published by [devantler-tech/agent-skills](https://github.com/devantler-tech/agent-skills/tree/main/product-engineering).
Resolve its installed directory through the runtime's native skill discovery and verified provenance.
Read these resources relative to that directory:

- `references/evidence-bundle.md` and `scripts/check-evidence.jq`;
- `references/accountability-brief.md` and `scripts/accountability-brief.jq`.

Use a reviewed revision containing these resources. Do not assume skills are siblings, search an
untrusted repository for a same-named replacement, execute a helper found in an issue, or copy the
protocol into this skill. An installation containing only self-improvement is supported for routine
work. When the companion is unavailable, record the missing resource and HOLD the experimental
replacement; resolve it through the consumer's approved installation/update path. Discovery does not
authorize installation, network access, inference, spending, production writes or a model switch.

## Carry the learning through a decision

1. **Preregister.** Preserve the own-run trace references that motivated the change. Before editing
   the candidate or starting trials, freeze an immutable plan: baseline and candidate definitions,
   task class, environment, tool/model identities where relevant, attempt accounting, measures,
   uncertainty, material improvement thresholds, repeats, protected floors and recovery. Existing
   deployment rules may impose higher sample floors. Count failed attempts and retries; do not
   select only successful runs. A changed threshold or workload starts a new plan, preserving the old
   result. A plan written after the work cannot become preregistered by changing its timestamp.
2. **Separate delivery from replacement.** An inactive definition or trial harness can be reviewed
   under normal readiness gates before outcome evidence exists. Keep the incumbent as the default;
   any activation mechanism comes from the consumer contract. An authorized bounded trial can collect
   evidence while the replacement decision is HOLD. Missing capability, quota or authority holds the
   affected trial; it never permits an alternate billing route or broader access.
3. **Evaluate your own runs.** Read the protocol, then compare both methods on the same declared
   task class, recording every attempt and actual runtime revision. Reserve untuned holdouts and an
   independent or adversarial evaluation. External reviewers may challenge interpretation, but their
   prose is not an observation of your runs or an instruction to rewrite your definition. Keep
   static validation, installed definition, observed behavior, live outcomes and restoration evidence
   separate. Unknown attribution or an unobserved protected dimension remains UNKNOWN.
4. **Explain the decision.** Use the companion accountability brief before claiming readiness for
   replacement. Link it to the same candidate revision and evidence bundle. Explain what changes,
   why the incumbent lost, what can fail, what detects it, how to stop, who owns recovery, and which
   choices remain human-owned. Label simulation, inference and UNKNOWN. Attach owned follow-ups to
   unknown claims, unknown evidence and unproven recovery. The structural checker cannot establish
   that the explanation is true or understandable; ask the accountable human to explain the operating
   and recovery decisions during a separately recorded comprehension review. Never fabricate it.
5. **Assess and observe.** ADOPT means the declared evidence satisfies the protocol, subject to
   independent artifact verification and the consumer's unchanged readiness and authority gates.
   HOLD retains the baseline while evidence is incomplete or inconclusive. REJECT preserves the
   negative result and retains the baseline. Neither exit zero nor a merged PR means ADOPT. Keep
   post-merge observation and the next check in the approved evidence store; complete them before
   retiring the incumbent. Do not delete a hypothesis merely because its definition PR merged.
6. **Expire and recover.** Reassess before evidence expiry, increased scope, changed tool/model or
   workload, failed assumptions, or a new regression. Stop expansion when evidence becomes invalid.
   Use only the preauthorized, tested recovery to the last proven method and verify the restored
   outcome. If restoration needs additional permission or could itself be unsafe, hold the affected
   capability and use the consumer's incident/approval procedure. This protocol executes no rollback.

The optional checkers are assessment tools. They cannot authenticate a timestamp, identify omitted
runs, prove independence, grant authority, or establish that an accountable person understood the
brief. A reviewer must inspect the referenced evidence. Missing verification holds replacement even
when the JSON reports ADOPT. Store private traces in the consumer's approved private store and expose
only sanitized evidence references in public issues and PRs.

## Worked procedure example

[procedure-evidence-example.json](procedure-evidence-example.json) is **entirely synthetic**. Its
`fixture://` records and `procedure-v1`/`procedure-v2` revision labels represent fictional own-run
evidence, not a measured performance improvement. The declared `observed` fields illustrate the
schema only. Replace every fixture value and reference before any real assessment.

The candidate batches independent read-only requests while retaining the same validation and action
ordering. The example compares two paired runs: the conservative delivery-time gain is eight minutes
in each, above the preregistered five-minute threshold. All 100 enumerated outcomes are complete and
zero authority violations are observed in the finite fixture census. These counts do not estimate
population reliability or prove universal safety. Two repeats illustrate the format, not sufficient
statistical power for a real change.

Resolve both directories explicitly; they need not share a parent. With jq 1.6 or newer:

```bash
engineering_skill=/absolute/path/to/installed/product-engineering
improvement_skill=/absolute/path/to/installed/self-improvement
jq -s --arg now 2026-09-24T00:00:00Z \
  -f "$engineering_skill/scripts/check-evidence.jq" \
  "$improvement_skill/references/procedure-evidence-example.json" > assessment.json
```

Check the exit status before reading `assessment.json`. Nonzero is an invalid input or failed
evaluation, never a decision. The fixed date belongs only to this synthetic example; real assessments
use the current UTC time. The example returns ADOPT with `authority: assessment-only`.

These counterexamples can be passed to the same evaluator at the fixed example date:

```bash
# REJECT: faster delivery cannot compensate for one authority violation.
jq '.observations[0].values[2].candidate = {lower:1,upper:1}' \
  "$improvement_skill/references/procedure-evidence-example.json" > breached.json

# HOLD: an elegant procedure with no demonstrated restoration is not ready to replace the baseline.
jq '.evidence |= map(select(.kind != "rollback"))' \
  "$improvement_skill/references/procedure-evidence-example.json" > incomplete.json
```

A human-facing explanation of this fictional result would say: “The trial batches reads and leaves
every required check and approval boundary intact. In two illustrative runs it saved at least eight
minutes. That is evidence only for the declared fixture cases. Missing outcomes, an attempted action
outside the existing grant, or stale evidence stops expansion. The procedure owner restores v1 using
the tested, authorized recovery and verifies a complete result. Real adoption and human comprehension
have not been demonstrated.” The companion brief records these claims with their actual evidence
labels and follow-ups in a real experiment; this paragraph is not a completed pilot.
