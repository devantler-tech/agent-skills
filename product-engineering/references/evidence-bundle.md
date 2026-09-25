# Evidence bundles for unfamiliar engineering methods

Use this protocol when deciding whether an unfamiliar method can replace a proven one. It works for
an application design, infrastructure change, library implementation, or operational procedure.
Scale the experiment to the consequence of being wrong. Routine repairs do not need a new ceremony.

The bundle is a decision record, stored with the issue or in the deployment's approved evidence store.
Keep private measurements and sensitive topology out of public artifacts. An evidence URI can point
to a restricted store; the evaluator never opens it. Record failed and inconclusive experiments too.

## Before implementation or experimentation

State the user outcome, current method and immutable revision, proposed candidate, and alternatives
(including retaining the baseline). Freeze the experiment plan in a timestamped, immutable artifact:
measures, units, workload/environment, uncertainty calculation, repeat count, material improvement
thresholds, tolerated regression, and **every relevant protected dimension**. Security, correctness,
reliability, accessibility, cost or recovery may be floors even when speed is the objective.
Never translate a protected outcome into a weighted score that another metric can compensate for.

Record assumptions and how to falsify them; reserve end-to-end and holdout cases that will not be used
for tuning. Identify an independent evaluator or an explicitly adversarial evaluation procedure,
staged rollout, stop conditions, the last proven revision and an executable recovery procedure.
Specify the observation window's UTC start and end, owner and next check. Two repeats are the format's minimum, **not a
claim of statistical power**: choose sufficient independent trials before collecting results.

Changing thresholds, units, workloads or protected dimensions after seeing results creates a new
preregistered experiment. Preserve the original result. Do not relabel an old run as preregistered.

## Collect and assess

Compare the baseline and candidate on comparable workloads, dependencies, hardware, time windows
and measurement methods. Retain raw artifacts, sample sizes, uncertainty calculations and failed
attempts in the referenced evidence. Use separate source identifiers for independent repeats, and
include numeric observations for every recorded measurement artifact exactly once.

Keep these evidence types distinct:

| Kind | What it demonstrates |
| --- | --- |
| `measurement` | Baseline/candidate comparison, both revisions, raw samples and uncertainty |
| `static` | CI, lint, schema and other static validity checks at the candidate revision |
| `behavior` | User-visible end-to-end behavior |
| `deployment` | The revision actually installed or used in the target environment |
| `live` | The resulting outcome over the declared observation window |
| `review` | Independent or adversarial attempts to falsify the proposal and resolve findings |
| `holdout` | End-to-end or holdout cases not used to optimize the candidate |
| `rollback` | An executed restoration drill to the baseline, including restored data and outcomes |

For libraries and procedures, deployment can mean installation into a representative consumer or
using the revised procedure in a bounded operational trial. A published package or approved document
alone proves neither adoption nor outcome. Bound claims to the environment actually observed.

Use authorized, bounded trials to obtain deployment/live evidence before retiring the baseline.
Missing live evidence holds the **replacement decision**; it does not prohibit an otherwise
authorized experiment. This protocol supplies no permission for a trial, deployment, model switch,
spending, production mutation or automatic rollback.

Adopt only when at least one declared objective improves materially **in every recorded repeat**,
all protected floors are demonstrated, and no material regression remains. This v1 checker
conservatively holds or rejects any material regression; an explanation never cancels a protected
floor. Investigate and preregister a revised experiment when the tradeoff is still worth testing.

## Version 1 JSON contract

[evidence-example.json](evidence-example.json) is a complete **synthetic fixture**, not evidence about
a real product. Copy its shape and replace every fixture URI and value. The executable schema and
decision rule live together in [check-evidence.jq](../scripts/check-evidence.jq); `schemaVersion` is `1`.

| Field | Meaning |
| --- | --- |
| `outcome`, `baseline`, `candidate`, `alternatives` | Desired result, distinct method IDs and immutable revisions, and unique considered alternatives with reasons, including the baseline ID |
| `plan.record`, `registeredAt`, `startedAt` | Immutable plan artifact; registration strictly before the earliest implementation/experiment activity |
| `plan.minRepeats`, `plan.measures[]` | Integer repeat floor ≥2; unique IDs, units, `higher`/`lower` direction, objective flag, positive objective `minImprovement`, nonnegative `maxRegression`, protected flag and numeric `floor`, method, environment, uncertainty method |
| `assumptions[]` | Statement, `supported`/`unknown`/`refuted` state and evidence ID |
| `falsification` | `independent`/`adversarial` approach, evaluator, attempted falsification and review evidence ID |
| `rollout`, `rollback` | Stages and stop conditions; baseline target revision, executable procedure URI, trigger and restoration evidence ID |
| `observation` | Owner, live `evidenceId`, window `{startedAt,endedAt}` and next-check timestamp |
| `evidence[]` | Unique ID, kind, `observed` provenance, immutable candidate revision, source URI, observation/expiry timestamps, and `pass`/`fail`/`unknown` result |
| `observations[]` | Unique repeat ID, measurement evidence ID, and measure values with baseline/candidate uncertainty intervals `{lower,upper}`; `null` means unmeasured |

Measurement evidence additionally pins `baselineRevision`. Holdout evidence declares
`usedForTuning: false`; absent or true holds adoption. All timestamps use UTC `YYYY-MM-DDTHH:MM:SSZ`.
Live and rollback evidence name their `deploymentEvidenceId`: a passing deployment of the same
candidate must have been observed strictly before the outcome or restoration drill. The declared
observation window must start at or after that deployment and experiment start, finish after its
start and no later than evaluation time, and be covered by the referenced live artifact's observation
timestamp. Missing links or incomplete windows hold adoption. Verify that the source artifact actually
covers the whole declared interval; a timestamp alone cannot prove continuous observation.

Thresholds are absolute values in each measure's declared unit. Prefer scaled integer units such as
microseconds or successful responses per million when decimal rounding could decide a boundary.
An interval is not automatically a confidence interval: its meaning, estimator, sample size and
coverage must be established by the preregistered method and checked against the source artifacts.

The evaluator uses pessimistic interval endpoints for improvement, floors and regression allowance.
If even optimistic endpoints breach a floor or regression allowance, the result is negative.
An absolute protected floor uses the candidate interval independently of the baseline; a missing
baseline value or mismatched baseline revision cannot erase that candidate's demonstrated breach.
Intervals straddling a boundary are inconclusive. No field substitutes model confidence for observed
evidence. Missing baseline/schema fields are invalid input; missing measurements or evidence remain
incomplete. Unknown assumptions, expired evidence, future observations and mismatched revisions hold
adoption. Known failures, refuted assumptions and measured regressions bound to this experiment remain
negative even after their evidence expires or other evidence is missing. Evidence from another
revision or outside this experiment's observation window cannot establish this candidate's outcome.
A refuted assumption needs conclusive supporting evidence; an explicitly unknown result stays on
hold. If the complete measurement set conclusively misses every objective, unrelated missing evidence
does not erase that negative result. Incomplete measurement sets or an objective whose uncertainty
still permits improvement remain inconclusive.

## Run the optional offline check

Requires jq 1.6 or newer. Resolve paths relative to this installed skill, not the consuming repository.
The helper reads JSON, performs no network calls or writes, and is **not enabled as a runtime gate**.

```bash
jq -s --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -f /path/to/product-engineering/scripts/check-evidence.jq bundle.json > assessment.json
```

Check the command's exit status first. Nonzero means invalid input or evaluation failure, never a
decision. Slurp mode (`-s`) lets the evaluator reject empty or multiple input bundles.
Successful evaluation emits `decision`, `reasons`, revisions, evaluation time and
`authority: "assessment-only"`. It exits zero for all three decisions; inspect the JSON explicitly:

```bash
jq -e -s 'length == 1 and .[0].decision == "ADOPT"' assessment.json
```

| Decision | Meaning and next action |
| --- | --- |
| `ADOPT` | Declared evidence satisfies the rule; independently verify the artifacts and existing readiness/authority gates before replacement |
| `HOLD` | Incomplete, stale or inconclusive; retain the baseline, resolve the listed gaps or collect a properly authorized trial |
| `REJECT` | Observed failure, refuted assumption or completed evidence missing the improvement threshold; preserve the negative result and retain the baseline |

**The checker verifies declarations and arithmetic, not their truth.** It cannot authenticate the
preregistration timestamp, detect altered thresholds behind a URI, validate statistical methodology,
prove independence or untuned holdouts, discover omitted protected dimensions, or inspect whether a
rollback restores the outcome. The reviewer must verify those facts against immutable artifacts.
Keep the decision HOLD when that verification is unavailable. Synthetic passing fixtures demonstrate
the checker only; they do not prove this protocol improves engineering outcomes.

## Worked decisions

Run the synthetic example with `--arg now 2026-09-24T00:00:00Z`. It reports `ADOPT`: both trials reduce
the conservative latency bound by 15ms against the predeclared 10ms threshold; reliability remains
above 995,000 successful responses per million, within its 1,000-per-million regression allowance.
All evidence stages and the restore drill are present. The test date is fixed solely for the fixture.

These transformations create reproducible counterexamples; pass the resulting JSON to the checker
using the same fixed fixture date:

```bash
# Faster but less reliable: REJECT, regardless of the latency gain.
jq '.observations[].values[1].candidate = {lower:980000,upper:990000}' evidence-example.json

# Elegant implementation without a restore drill: HOLD; rollback is unproven.
jq '.evidence |= map(select(.kind != "rollback"))' evidence-example.json

# Uncertainty overlaps the improvement threshold: HOLD, not success or failure.
jq '.observations[].values[0].candidate = {lower:80,upper:100}' evidence-example.json
```

## Expiry and recovery

Expiry is explicit per artifact; a changed revision, changed workload, failed assumption, new
material regression or overdue observation invalidates the relevant decision earlier. Schedule the
next check strictly before the earliest evidence expiry; a check at or after expiry holds adoption.
Reassess at the next check and before increasing rollout. Missing current evidence never renews itself.

On invalidation, stop expansion and return the capability to its last proven method through the
preauthorized, tested recovery procedure. If recovery would be unsafe or requires new permission,
hold the affected capability and invoke the consumer's incident/approval procedure. Preserve evidence
of the failed candidate and verify the restored outcome; the checker does not execute recovery.
