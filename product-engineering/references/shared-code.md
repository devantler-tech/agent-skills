# Shared code — prove the need and choose the smallest owner

Use this procedure when similar mechanisms appear across products or when a reusable package
seems coupled to a larger product. Its output is a decision for every candidate in a **bounded,
declared scope**, followed by separately tracked implementation and adoption where justified.
It does not imply that a library or service must be created.

## 1. Establish independent demand

Record the repositories, revisions, paths and callers being examined. State what lies outside
the survey; an inspected sample cannot stand in for a complete portfolio inventory. Read each
product's instructions and the consuming deployment's authority and stack contracts first.

Trace each candidate from an actual product entry point to the proposed shared mechanism.
Show the inputs, outputs, errors and compatibility requirements each caller relies on. Require
**two independent products with observed needs** before extracting a new shared library:

- Several commands or tests in one product can justify local sharing, not a second product.
- Generated mirrors, bundled skill copies and test fixtures are not independent product needs.
- A hoped-for consumer or future roadmap item is not an observed caller.
- Similar syntax or use of the same SDK does not prove that the products share a policy.

Separate mechanism from policy: encoding a request may be common, while deciding which release
to publish is owned by each product. Keep product-specific choices in their owners. If a common
contract cannot be stated without adding speculative configuration, retain local ownership and
record what evidence would change that decision.

## 2. Keep a decision record

Put one record per candidate in the issue tracker, including candidates retained locally:

| Field | Evidence to retain |
|---|---|
| Identity and scope | Candidate, examined repositories/revisions/paths, exclusions and observation time |
| Independent callers | Actual entry points in each product; behavior and compatibility they require |
| Common contract | Shared mechanism, inputs/outputs/errors, and policy that stays with each consumer |
| Options and fit | Local ownership, supported existing libraries, a new library, and a service only if justified |
| Coupling and cost | Dependency/platform constraints, maintenance and adoption cost, ownership and trust/license fit |
| Verdict and unknowns | Chosen owner, rejected alternatives with evidence, blockers and the evidence needed to resolve them |
| Delivery and recovery | Implementation/adoption issues, validation, releases, real consumer proof and rollback path |

Use a verdict such as **keep local**, **reuse existing library**, **extract library**,
**service justified**, or **blocked pending evidence**. A blocker is a finding, not permission
to assume fit. Do not label a scope complete while an in-scope candidate is missing its record.

## 3. Evaluate existing libraries first

Check the library's supported public contract against both real callers. Record incompatible
inputs, error behavior, supported platforms or versions; do not reject an existing owner merely
because a new repository would look cleaner. Consider:

- Public API stability, versioning and compatibility guarantees.
- Dependency graph, toolchain/platform requirements and required privileges.
- Maintainer, security/reliability signals, distribution and release support.
- License and trust compatibility, including the deployment's rules for external dependencies.
- Work required at the callers and the continuing maintenance cost of each option.

For **Go**, inspect the module path, public package boundaries, supported Go version and module
graph. Measure what importing the package actually brings in and what consumers cannot use.
A CLI module containing public packages, or a module with a major-version suffix, is not by
itself proof that those packages need a new repository. Keep a compatible existing package in
its current owner when it meets the callers' needs; propose a split only for measured coupling
or lifecycle constraints that a smaller change cannot address.

If a new library is justified, define the smallest stable API demonstrated by the callers.
Make it a first-class product within the deployment's authority: its own repository, portfolio
entry, product card, roadmap, owner, health checks, distribution, release policy and compatibility
commitment. Plan issue ownership and dependency updates in the consumers. An ownerless helper
repository is not a completed extraction.

## 4. Apply the higher bar for a service

Prefer a library when the mechanism can run safely within each consumer. A hosted service adds
network and operational coupling; justify it with a requirement a library cannot meet, such as
shared authoritative state or a centrally operated capability. Two consumers alone do not earn
a service, and easier distribution alone does not establish an operational case.

Before choosing a service, record its contract and how the products behave when it fails:

- Availability and latency needs, timeouts, retries, backoff, idempotency and failure isolation.
- Authentication/authorization, tenant isolation, data classification, retention and privacy.
- Interface/version compatibility and rollout coordination across consumers.
- Operator, monitoring, incident response, recovery and capacity expectations.
- Hosting, maintenance and usage costs under the deployment's spend contract.
- Exit: export or portability, replacing the service, and consumer recovery during retirement.

Resolve these requirements with the named owner and authority. If required access, operating
ownership, budget or failure behavior is unknown, retain an explicit blocker and a workable
local/library option where available. A survey or product decision does not authorize repository
creation, credentials, deployment, billable tests or spend; follow the consumer's existing gates.

## 5. Extract without changing behavior

Track the library implementation and each actual consumer adoption as separate bounded work.
Keep behavior changes out of the extraction. Capture existing behavior and run the consumers'
tests before moving code; if coverage is insufficient, add coverage in a separate change first.

Retain the original source tests **unchanged** as the behavior oracle. Add library contract tests
and consumer integration tests where needed; additive adapters can preserve the old interface.
If the proposed extraction requires rewriting that oracle or changing caller expectations, split
out the behavior/API change and obtain its own evidence and review. Moving tests into a library
and running them there alone does not prove that the consumers still work.

Exercise each caller against the library through its supported build/release path outside the
library's source tree. Check errors and compatibility as well as the happy path. Record the
exact package version and consumer revision used, and run each product's required checks.

For a service, additionally exercise consumer-visible network failure and recovery against the
authorized environment. Local fixtures and mocks can establish bounded behavior; label them as
such and do not substitute them for a named real service path or authorize a paid environment.

## 6. Deliver and prove adoption

Normal current-head CI, substantive review, issue/roadmap reconciliation and merge protections
apply to every implementation and consumer PR. Evidence from another head or a source-only test
cannot clear the current consumer. Respect dependency order: publish the library first where
consumers need its release, then merge their independently verified updates.

After merge, verify the actual merged version from each consumer's normal installed or deployed
path. Distinguish the completed decision, library publication, merged consumer change and observed
adoption. Do not close a migration or claim portfolio convergence while required consumer proof
is missing. Keep that missing evidence as a named blocker with an owner and recovery step.

Define recovery before changing callers: retain a compatible adapter or known-good pin where
appropriate, and establish how to revert a consumer without breaking another one. For a service,
include data and availability recovery. Do not delete the old path until the declared consumers
and their recovery requirements are satisfied.

## Illustrative decisions — not a completed inventory

| Observation | Defensible decision |
|---|---|
| Three scripts in one repository share an index reader | Keep a local helper; there is one product, even with several callers |
| Two release scripts both call the GitHub API but select releases differently | Reuse the existing API client; keep each product's release policy local |
| Two products already use a public Go package in a CLI module | Assess its supported API and measured module coupling before proposing a split |
| Two products need a proven common parser with a compatible supported library | Reuse that library and verify each real caller |
| Two products need shared authoritative state with documented runtime requirements | Evaluate a service only after the library option and operating/failure/exit case |

These examples explain how to decide. They do not prove that any portfolio candidate has been
surveyed, extracted, released, adopted or exercised against a real service.
