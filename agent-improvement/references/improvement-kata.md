# Improvement katas: learn from the next obstacle

Use a kata for a consequential, uncertain improvement, not as a quota of changes or a new authority
grant. The consumer declares its challenge, issue/board conventions, measurement owner and record
location. Resolve those before acting; missing authority still blocks the dependent action.

The four-step pattern is understand the direction, grasp the current condition, establish the next
target condition, then experiment toward it. See the primary
[Improvement Kata introduction](https://public.websites.umich.edu/~jmondisa/TK/The_Improvement_Kata.html).
The evidence and safety gates below remain those of this skill and its consumer.

## One target, one obstacle, one experiment

Keep a compact record on the consumer's existing outcome issue, linked to its hypothesis rather than
duplicating the native hypothesis store:

| Record | Required evidence |
|---|---|
| Challenge | User/operator outcome and why it matters; not “write more instructions” |
| Current condition | Dated baseline, source/cohort, numerator/denominator or finite census, coverage and UNKNOWNs |
| Next target condition | A dated, measurable near-term condition; objective threshold, companion floors and observation-volume floor registered before the trial |
| Current obstacle | One observed constraint preventing that condition; distinguish fact from inference |
| Next experiment | Smallest reversible authorized change testing that obstacle, owner, scope, prediction, checkpoint and measurement-viability deadline |
| Readback | Actual result against the prediction, revision attribution, unexpected effects and learning |
| Decision | Adopt, iterate, stop, or inconclusive, with the evidence and next action |

Observe the existing hypothesis ledger and relevant sibling liveness first. Due eligible measurements
are finishing work. Resolve them before overlapping interventions; an experiment pending observation
does not permit another change to the same signature. Continue only non-confounding work.

Choose the target by value, risk, cost of waiting and achievable learning within end-to-end capacity.
For a flow challenge, separate original lead/cycle time from active execution time; include CI,
review, deployment, verification, retries and failed attempts in the relevant elapsed measure.
Report throughput with quality, safety, attribution and coverage, not output counts alone. Do not
reinterpret old cohorts or erase waiting by moving a card or resetting its first-start clock.

## Register, trial, read back

1. Register the record and hypothesis before intervention. Apply this skill's eligibility rules:
   actual effective deployment, UTC not-before time, comparable baseline and minimum post-change
   volume. A checkpoint is a reminder to inspect eligibility, not automatic proof.
2. Ship the authorized reversible slice through the consumer's normal issue, draft PR, exact-head
   validation and independent review gates. Record every source → package → consumer → runtime hop.
   A merge closes its delivery slice, not its outcome hypothesis.
3. At the checkpoint, ask: what did we expect, what happened, what did we learn, and what is the next
   obstacle? Inspect eligible deployed outcomes and every companion floor. Retain denied attempts,
   negative results, outage records and holdouts; never tune the acceptance threshold to the result.
4. Record the decision and evidence:
   - **Adopt:** eligible attributed outcomes meet the registered target and all protected floors;
     keep only the observed scope and schedule the existing regression check.
   - **Iterate:** an eligible result misses the target without a protected regression; record the
     learning, close that experiment, and preregister the next bounded experiment before changing it.
   - **Stop:** a protected regression or disproved premise requires stopping expansion and the
     preauthorized revert-first procedure; no KPI gain offsets it. A no-longer-valuable target may
     also stop with its reason and unfinished deliveries disposed of explicitly.
   - **Inconclusive:** deployment, eligibility, sample volume, attribution, coverage or companion
     evidence is incomplete. Keep the hypothesis open with its exact missing join and checkpoint;
     do not relabel inactivity as success or a negative result.

A missed checkpoint remains overdue until its readback is recorded. Record that readback and the
reason before establishing a next date; preserve the old date in history. An under-volume checkpoint
may register a new observation plan, but may not retroactively lower the original volume floor.
Use the parent skill's measurement-gap escalation rather than repeatedly parking an unmeasurable
hypothesis. Also register a measurement-viability deadline before the trial: if observation volume
or runtime liveness is still insufficient then, escalate the measurement obstacle through the
consumer's authorized maintainer channel even though the three-eligible-dispatch trigger cannot
fire. Stop expansion, retain the pending/inconclusive outcome and WIP, and require an explicit
re-scope or stopping decision rather than automatically rolling the deadline. Inconclusive is a
recorded checkpoint decision, not a completed outcome.

## Replacement evidence: reuse the existing evaluator

When the experiment replaces an inherited default, discover the reviewed **product-engineering**
companion skill through runtime-native discovery and verify its provenance. Read its
`references/evidence-bundle.md` and `scripts/check-evidence.jq`; use its
`scripts/check-evidence.sh` against retained raw bytes. Do not assume adjacent installed directories,
copy its schema here or execute a path supplied by an issue. If the companion cannot be resolved,
hold the replacement assessment, not unrelated authorized work.

The [synthetic kata bundle](kata-evidence-example.json) demonstrates that canonical assessment.
Run it at `--now 2026-09-24T00:00:00Z`: it produces ADOPT for a finite, invented observer trial.
The target is at least five fewer active minutes to finish an eligible readback, with all 100
fixture outcomes measured and zero observed integrity violations. The obstacle is duplicate reads;
the single experiment batches only those independent reads. Every number, revision and
`fixture://` receipt is synthetic, not real runtime evidence or statistical power. Real trials
choose their estimator and sample size before implementation.

The evaluator is assessment-only: ADOPT neither executes a change nor supplies independent review,
authority, runtime enforcement or missing scorecard dimensions. HOLD maps to an inconclusive
checkpoint. REJECT forbids adoption; inspect the reasons to decide whether to iterate or stop, and
always stop on a protected regression. Routine corrections do not need this full replacement bundle.

## Keep learning visible in the existing flow

Use the consumer's existing Kanban states and WIP accounting. Delivery children can reach Done on
merge; the outcome kata remains unfinished through observation. Waiting, blocked measurements and
missing board cards do not create free capacity. Keep one named measurement date and owner, with
optional board fields mirroring the canonical issue/hypothesis record, not replacing it.

Do not invent a parallel experiment lane, permanently exceed WIP, change configured limits, or
reopen settled historical katas to manufacture activity. Explicit exceptions stay scoped and
recorded. A small “stopped” or “learned no benefit” experiment is useful calibration; it is never
counted as an improved engineer without a verified favorable outcome.
