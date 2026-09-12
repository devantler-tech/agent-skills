# Routing evidence and experiments

Use this procedure only for work under the consumer's declared **Inference routing** contract. The
`agent-improvement` skill's ingestion, authority, coverage, eligibility, companion-floor, and
revert-first rules apply unchanged. This reference owns measurement and governance; execution follows
the consuming deployment's run loop rather than a second delegation procedure here.

## Gather the complete attempt chain

Link every routed work item to its full attempt chain, including work with no successful outcome.
Record accepted, failed, abandoned and ongoing/window-censored work explicitly at the observation
boundary; never drop unfinished work from the cohort. Retain parent and child identities, failed and
abandoned attempts, handoffs, requested and effective models, reasoning effort, task class, runtime
version, and loaded contract/policy revisions. Use runtime-produced metadata with provenance rather
than agent assertions. Count a completion once; never credit the whole result to the final model or
count each child's report as a delivery. Report missing attribution under the Gather coverage rules.

Collect instruction/history loading, preloaded skills, input and cached tokens, cache creation, output
and reasoning usage where available, tool work, parent integration, active/waiting time, rework, and
escalation causes. Compare delegation with completing the same accepted result in the existing context;
packet size and nominal model price alone cannot establish savings.

For quota observations, retain provider/account bucket identity, unit, timestamp, reset information,
source coverage, and outstanding or unsettled reservations. Keep short-window and weekly buckets
separate. Missing values are UNKNOWN, never zero. Concurrent sessions or delayed snapshots prevent
exact per-model attribution unless the source supplies it; label estimates and record unobserved
account activity. A writer lease expiring does not prove inference stopped, and completed work does
not prove a quota snapshot has settled its usage. This skill observes admission controls; it does not
create billing authority or implement a launcher through prose.

## Govern assignments through experiments

Benchmarks nominate candidates; comparable local outcomes justify assignments. Stratify by task class,
difficulty, repository, runtime, and policy revision; include failures and rework. Compare accepted
outcomes per measured quota unit within each provider, alongside delivery rate, quality, and coverage.
Never convert benchmark API prices into subscription consumption or combine unlike quota units into
a score.

Predeclare one changed variable, baseline/holdout, canary allocation, date and volume floors,
uncertainty method, promotion criteria, and rollback revision. Compare fresh context with reused
context using measured hydration and integration costs; retain required instructions in both arms.
Missing eligibility remains NOT-YET-DUE; insufficient admissible attribution remains NO-VERDICT with
the existing bounded measurement-gap procedure. Neither condition authorises automatic promotion.

Only the consumer's named publisher advances a routing experiment or policy revision. Fence overlapping
runs of that publisher through the consumer's declared coordination mechanism; siblings contribute
evidence without becoming additional publishers. Verify loaded revisions and native controls before
canary execution. The policy cannot authorise its own relaxation: changing billing routes, prohibited
models, runtime scopes, or other protected limits requires the consumer's explicit authority. A real
prohibited-path execution is a safety incident even when throughput improves; rollback and recovery
must preserve those limits.
