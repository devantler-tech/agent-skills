### Tool maturation — bash → Go program → CLI

Use three distinct rungs: a small, simple **bash** job; a **repository-local Go program** when
branching, error handling or reuse makes a script hard to maintain; and a **CLI product** when
people deliberately invoke it across repositories and it needs an independent interface and
lifetime. The consuming deployment's scripting/stack contract governs permitted languages and
host-mandated exceptions. Complexity can justify the second rung; **audience and lifetime, not
line count, justify the third**. A large CI-only program can remain repository-local.

**Prefer a compatible existing CLI before creating a new one.** Establish fit with its purpose,
users, interface, permission model and distribution; technical ability to host a command is
insufficient. When no existing tool fits, document the rejected alternatives and create a new
first-class product only within the consumer's authority: its own repository, portfolio-map entry,
product card, roadmap, health checks, and release/distribution path. Creating that product is a
feature decision, not a behavior-preserving refactor.

For a scripting survey or migration, use [the tool-maturation decision procedure](tool-maturation.md).
Its optional read-only helper records committed shell paths at an exact revision with caller
coverage left unknown; `--include-go` also supplies parsed Go entrypoint files without building
surveyed packages. Opt in explicitly and retain the procedure's declared scope before assessing use.
Record every in-scope candidate's observed callers, destination, fit rationale and unknowns in the
issue tracker. Preserve behavior, compatibility and recovery; exercise the installed command from
a real caller before claiming migration. A survey, suggested destination or new binary alone is
not a completed migration, and none replaces the normal readiness or adoption gates.

### Shared code — independent reuse before extraction

Extract a shared library only after **two independent products have an observed need for the
same mechanism**. Similar-looking functions, several callers inside one product, generated
copies, and anticipated users do not establish that need. Trace the actual callers and separate
the common mechanism from each product's policy before proposing a public contract.

**Prefer a compatible existing library before creating one.** Compare its supported API,
dependencies, compatibility, ownership, distribution, license and trust against the actual
callers. For Go, inspect the module path and dependency graph as well as the package: a useful
public package inside a CLI module does not automatically need a separate library repository.
Record the measured coupling and rejected alternatives. Local duplication can be the better
decision when the common contract or independent demand is unproven.

**Prefer a library to a hosted service.** A service needs a concrete requirement a library cannot
meet, plus an explicit account of network failures, availability, tenancy, data handling, cost,
operations and exit. Neither option grants authority to create a repository, deploy a service,
obtain access or spend money. Within the consuming deployment's authority, a new library is a
first-class product with its own repository, portfolio entry, product card, roadmap, owner,
health checks and release/compatibility policy.

Use [the shared-code decision procedure](shared-code.md) for a bounded survey or
extraction. Give every in-scope candidate an evidence-backed verdict in the issue tracker.
Keep extraction behavior-preserving, retain the original tests unchanged, and prove the released
API from the actual consumers before claiming adoption. Merge readiness and post-merge consumer
proof are separate gates; a decision record or published package alone completes neither.

