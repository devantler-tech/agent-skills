# Testing incomplete observations

Use this procedure for collectors, validators and readiness checks whose output stands for
examined evidence. Its purpose is to catch a successful-looking result over data that was never
fully read. It does not introduce a new checklist for unrelated edits or grant any authority.

## Choose observable outcomes

Identify what the actual caller treats as success: exit status, an output field, a check conclusion,
or a published artifact. Distinguish these three outcomes using the component's existing contract:

- **Complete and clean:** the declared scope was examined and its rules passed.
- **Complete and rejected:** the evidence was examined and violated a rule.
- **Incomplete:** a required read, decode, transformation or coverage join did not complete.

Incomplete evidence cannot satisfy a clean result. Preserve the caller's UNKNOWN, error or hold
state rather than inventing a new protocol. A nonzero status alone may be insufficient if the
caller treats emitted JSON or an earlier OK line as clearance; assert the fields and streams it
actually consumes. Keep partial output diagnostic or private until the component knows whether
it is complete. Do not discard a known finding because the overall observation is incomplete.

## Keep a healthy control beside the failed observation

Start with a real fixture that should pass and a second input whose behavior is independently
known. Exercise the production component while failing only the second input's dependency. A
failure of every read may trip a no-data guard and miss the bug that a successful first read hides.

Test the relevant boundaries, including both no output and plausible output followed by failure:

| Boundary | Case that exposes a false clean result |
|---|---|
| Discovery | A listing emits some valid paths and then fails; omitted paths cannot be treated as absent |
| Reading | A file passes an accessibility check but its actual read fails or ends after partial content |
| Decoding | Syntax inspection succeeds but the subsequent decoder fails; earlier validity does not prove extraction |
| Transformation | A filter emits a plausible record before failing; downstream tools finishing cannot clear it |
| Matching | An ordinary no-match is accepted under the tool's documented convention, while a matching-tool error is incomplete |
| Aggregation | A healthy input contributes a count while another observation fails; a nonempty count does not prove complete coverage |
| Changing input | Counting sees a finding and a later read does not; classify the same retained observation that was counted |

Use real filesystem and process behavior where practical. A small fault-injecting executable is
appropriate for an I/O or tool error that is otherwise difficult to reproduce deterministically.
Keep the healthy dependency behavior real; assert the production component's outcome, not that
the test double was called. Derive expected clean, rejected and incomplete results independently.
Watch the regression fail for that intended reason before changing production behavior.

## Preserve the observation through its caller

Check every boundary that can lose a failure: a fallback that suppresses all statuses, a pipeline
whose last command succeeds, command substitution, process substitution, or an unchecked
temporary artifact. A normal no-match exception belongs only to that operation; it must not
suppress a failed upstream reader or transform. In shell, pipeline status handling does not by
itself expose the exit status of a process-substitution producer.

Retain one successfully completed extraction for counting and classification. If an exemption,
signature or digest governs acceptance, bind it to the evidence actually evaluated rather than
using a later independent observation to clear earlier content. When a stable snapshot cannot
be established, keep the uncertainty explicit.

Exercise the actual installed or CI caller before and after merge. Preserve existing successful
and rejected cases as well as the new incomplete cases. A passing fixture establishes those
scenarios; it does not prove every provider failure, runtime adoption or readiness gate.

## Worked regression

[Agent Plugins #308](https://github.com/devantler-tech/agent-plugins/pull/308) repairs a guard whose
clean baseline masked failed definition reads and whose counting and classification read inputs
independently. Its behavioral suite includes empty and partial read/decode failures, failures in
each transformation stage, normal no-match cases, and a changing read. The regression is useful
because it observes the guard's actual result with other healthy evidence still present, rather
than merely asserting that error-handling text exists.
