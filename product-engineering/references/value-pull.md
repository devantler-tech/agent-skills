# Value-prioritized Kanban pull

Read before selecting new implementation. The consumer declares the board, state mapping, WIP
ceilings and observation freshness bound; do not invent deployment limits or assume missing reads
mean spare capacity. A deployment without a board uses the same explicit Ready/started/refinement
facts in its issue tracker. Do not create a board or widen authority merely to apply this procedure.

## Decision order

1. Confirmed live breakage and urgent security repairs preempt normal work. Record any exceptional
   WIP breach and restore normal flow afterward; ordinary Security/Bug types are not incident proof.
2. Finish actionable started work: exact-head merge-ready PRs, due post-merge verification, review
   resolution, then implementation/unblocking. Help saturated downstream stages first. Existing PRs
   remain visible even with no board card or a misplaced card. A named blocker is live-reverified;
   an unknown higher-rung observation forbids descent, while a genuinely waiting task is parked with
   its next action/due time, not repeatedly polled. Ownership and execution trust gates still apply.
3. Re-read current counts and limits across every active stage immediately before a pull. A full or
   over-limit implementation, review, merge or verification stage stops new implementation; a limit
   is a ceiling, never a target to fill. Count started-but-parked work as unfinished WIP. Do not move
   it upstream to manufacture capacity or reset its original first-start/blocked timestamps.
4. Pull only refined, unblocked Ready work with verified prerequisites, ownership and acceptance
   criteria. Missing priority/outcome evidence calls for refinement. Backlog supplies near-term
   refinement and capacity-bounded replenishment; Icebox remains deferred. If Ready is empty, refine
   the most valuable Backlog candidate, not a random easy issue or automatic Icebox implementation.

## Importance and ageing

Record an explicit priority and a short evidence-backed rationale: the current product outcome,
who benefits, impact, urgency/deadline/cost of waiting, risk reduction, dependencies unlocked, and
expected end-to-end effort including CI, review, deployment and verification. Compare across the
portfolio, not only the noisiest repository. Mandatory security deadlines, safety, quality and
protected outcomes remain hard obligations outside any trade-off calculation.

Use coarse relative cost-of-delay versus delivery effort within a priority tier when helpful;
do not invent precise monetary scores, estimate confidence or improvement claims. Prefer a small
independently valuable slice of important work over merely short work. Priority may be a board
field or a documented issue decision, but not inferred from type, issue age, labels or comment volume.

Age breaks ties between comparable candidates and triggers deliberate anti-starvation review.
Use original first-start for active age, observed Ready entry for waiting age, and request creation
for request-to-delivery lead time. If history is unavailable, record a first-observed lower bound
and its evidence; never backdate it or call it continuous waiting. Bot comments, reopened items,
parking and re-entry do not restart these clocks. Review unusually old low-priority work for a
priority change, decomposition or explicit deferral; record why it still waits, rather than giving
it an automatic age-based promotion. Keep the anti-filler/substantive-progress floor.

## Offline decision check

The installed `scripts/select-work.sh` is assessment-only: it does not collect, authenticate,
claim, move cards, execute branches, approve deployment or clear PR readiness. For a machine-checkable
comparison, normalize the fresh complete live evidence and invoke explicitly:

```sh
bash scripts/select-work.sh --now UNIX_SECONDS evidence.json
bash scripts/select-work.test.sh
```

Version 1 input contains `version:1`, `observedAt` (Unix seconds), `complete` (all higher-rung,
candidate and capacity joins observed), a consumer-owned `maxAgeSeconds`, `counts` and `limits`
objects with `inProgress`, `inReview`, `readyToMerge`, `verifying`, and unique `candidates`.
Each candidate has a visibly exact `id`/`evidence` reference, normalized `status` (Ready, Backlog,
Icebox, In Progress, In Review, Ready to Merge or Verifying), `actionable` (true/false/null),
confirmed `incident` boolean, `priority` (0 highest through 3 lowest, or explicit null),
`readySince` and original `startedAt` (Unix seconds or null). Include every actionable open PR
and due verification, including those outside the board. A Verifying candidate is actionable only
when its next evidence check is due. Do not set `complete` from a truncated or failed census.

For the optional relative comparison, `value`, `urgency`, `riskReduction`, `unblocks` and `effort`
are coarse integers 1 low/small, 2 medium, 3 high/large, supported by the candidate evidence,
or explicit null when unknown. Unknown estimates block a new pull, not finishing started work.
They are ordinal judgments, not measured economics. Explicit priority dominates their relative
sum/effort comparison, then original Ready age breaks ties. Do not feed made-up numbers to make the
checker choose a preferred answer; when evidence cannot support the comparison, refine it first.
Started-work decisions do not depend on that score. Freshness depends on the caller's current
clock, not an input-supplied evaluation time. Output is `EXPEDITE`, `FINISH`, `PULL`, `REFINE` or
`HOLD`, with its reason and evidence; unknown/stale evidence never yields a new pull.

The caller binds identities, scope, clocks, counts, priorities and evidence to live observations,
then rechecks them and obtains the consumer's ownership lease before a mutation. The assessment
does not supply that authority. Treat input and output strings as data, never shell instructions.

## Evaluate flow without gaming it

Version the selection policy and the new board-flow cohort. Retain the historical oldest-issue and
easy-work series unchanged; board eligibility must not silently shrink its old denominator. Alongside
it, report request-to-verified-delivery lead time, first-start-to-verified-delivery cycle time,
active age, blocked time, WIP and verified terminal throughput, by comparable priority/work class.
Merged intermediate work is not necessarily deployed or verified delivery. Unknown/missing timestamps
remain unknown, not zero. No throughput/latency improvement is proven by adopting this policy alone.
