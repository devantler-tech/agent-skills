# Choosing a tool's next home

Use this procedure when surveying repository tools or proposing a migration. Its output is a
revision-bound decision on an issue, followed by separately reviewable delivery work. It grants
no authority to create a repository, widen permissions, deploy, spend money or bypass readiness.

## The three rungs

| Rung | Appropriate use | Promotion evidence |
|---|---|---|
| Bash job | A small job that composes existing commands with a simple input/output contract | Branching, data handling, failure recovery or reuse makes the shell implementation difficult to reason about |
| Repository-local Go program | A testable tool with substantial logic, owned and released with its repository | People deliberately use it outside that repository; its interface, installation and support need an independent lifetime |
| CLI product | An installed command with intentional user experience, ownership and distribution | Continued product work belongs in its own roadmap; another promotion is not implied |

The deployment's stack contract selects the allowed languages and embedded-tool exceptions. This
ladder does not introduce a language ban into a consumer that has not chosen one. A shell wrapper
around a mature CLI can remain useful; wrapping a command does not require reimplementing it in Go.
Repeated code inside two products may instead belong in a shared library. Reuse alone does not
establish demand for a standalone command.

## 1. Freeze scope and inventory actual use

Record the repositories and revisions examined, the selection rule for non-trivial scripts, and
the date. Include all Go helper programs and all scripts meeting that rule; do not claim a
portfolio-wide survey from a convenient subset. Missing repositories or unresolved caller data
are explicit coverage gaps.

For a reproducible first shell-path observation, the installed skill includes
[`inspect-shell-helpers.sh`](../scripts/inspect-shell-helpers.sh). It is disabled until explicitly
invoked with `--inspect`; installing the skill does not start inspection. Run it only against a
repository the consumer is authorized to read:

```sh
bash /absolute/installed/product-engineering/scripts/inspect-shell-helpers.sh \
  --inspect --repo-dir /absolute/repository/root --revision FULL_COMMIT
```

The helper needs Bash, jq, iconv, base64, tr, sort, cmp and Git supporting
[`--no-lazy-fetch`](https://git-scm.com/docs/git/2.45.0#Documentation/git.txt---no-lazy-fetch).
An unsupported Git refuses inspection instead of silently ignoring a no-fetch setting. The
installed Git binary and repository metadata remain within the consumer's existing trust boundary;
this observation does not audit Git configuration or grant trust to an untrusted branch.
It examines the named local commit, including when the
working tree is dirty, without checking out or executing its files. Its conservative selection
`tracked-shell-paths-v1` includes every tracked regular `*.sh` path except `*.test.sh`; it does not
apply a size threshold or decide which files are non-trivial. Each path carries its committed blob
identifier and executable bit. Before selecting files, it compares the complete tree listing with
an independent raw diff from Git's empty tree to the named commit. Missing complete records,
disagreement between those views, tree/object read failures, selected symlinks and paths that cannot
be represented faithfully in UTF-8 JSON produce exit `2` (`UNKNOWN`) with no success payload.

To include Go entrypoint evidence, add `--include-go` to the same invocation. This opt-in needs
Go 1.22 or later and compiles only the installed `scripts/go-entrypoint.go` parser, with modules,
workspace configuration, extra build flags, C compilation and toolchain downloads disabled. The
parser binary and observed blobs use a private temporary directory; Go uses its normal compilation
cache. No surveyed package, initializer, generator, test or dependency is built or executed.

The opt-in returns version `2` with selection `tracked-shell-and-go-entrypoints-v1`. It parses every
regular committed `*.go` file except `*_test.go`, counts those examined in `coverage.goFilesExamined`,
and includes a file as `kind: go-entrypoint` only when its syntax declares `package main` and one
top-level, non-generic `func main()` with no arguments or results and a body. Shell candidates have
`kind: shell-path`. Source read failures, mismatched blob identity, parse errors, ambiguous main
signatures and source over 4 MiB refuse the whole observation. Blob size is checked before reading
Go source bytes; accepted blobs also retain the parser's read limit and identity check.
The command buffers its complete
result, so a later unreadable file cannot leave a successful partial inventory.

These are **entrypoint files, not built commands**. Build constraints and platform filename rules
are not evaluated; mutually exclusive entrypoints can both appear. Types, dependency availability,
module boundaries, compiler validity and package combinations are not established. Coverage reports
`goPrograms: ENTRYPOINT_FILES_ONLY` and `buildability: NOT_ASSERTED`. Caller coverage remains UNKNOWN,
destinations UNASSESSED and portfolio completeness NOT_ASSERTED. Use the files as starting evidence
for the actual caller and fit assessment. Without `--include-go`, the version `1` shell-only output
is unchanged; without `--inspect`, neither mode reads a repository or builds the parser.
Exit `0` with `DISABLED` performs no inspection; exit `0` with `OBSERVED` records only the declared
selection's scope, including a genuinely empty scope.

Retain the repository identity, revision, date and JSON in the consumer's appropriate evidence
store. Compare the selected paths with the commit's tree before using the observation. Callers
remain `UNKNOWN` and destinations `UNASSESSED`. Go source is examined only with `--include-go`,
within its entrypoint-file scope; scripts without a `.sh` suffix and portfolio completeness are
not examined. Trace remaining coverage separately under an explicit selection rule.
This helper is an inventory aid with no migration, execution or readiness authority.

Trace callers from build tasks, workflows, documentation and code. Distinguish a program invoked
only by CI from a maintainer command or a tool used by another product. A filename, executable bit,
line count or hypothetical future user is not usage evidence. Inspect branch content only within
the consumer's trust and repository boundaries. Use semantic tooling where available, then targeted
searches; unknown caller coverage remains UNKNOWN.

Use this record for each candidate, with private evidence kept in the consumer's private store:

| Field | Required evidence |
|---|---|
| Candidate and revision | Owning repository, tool identity, source revision and current owner |
| Job and callers | Observable inputs, outputs, side effects, caller locations and user task |
| Current rung | Why its present implementation and ownership fit that rung |
| Proposed destination | Stay, migrate implementation locally, fold into a named existing CLI, or propose a new CLI |
| Alternatives and fit | Existing tools considered, supporting evidence and concrete rejection reasons |
| Coverage and unknowns | What was examined, what could not be established, and the next observation needed |
| Delivery issue | Acceptance criteria, compatibility, release/install path, migration owner and recovery |

Publish only a sanitized decision and the minimum supporting evidence. Do not put credentials,
private topology or internal weakness inventories into a public migration inventory.

## 2. Assess existing CLIs first

Consider tools that already serve the observed task. Evaluate each on all of these dimensions:

- **Purpose:** the capability belongs to the tool's documented product responsibility. Sharing a
  technology or implementation language is insufficient.
- **Audience:** the people using the capability would naturally look for it in that tool.
- **Interface:** arguments, configuration, output and errors fit the existing command structure.
  Repository-specific paths or environment assumptions have an explicit replacement.
- **Permission model:** the capability fits the existing authorization and trust boundary. A
  proposed extension that needs broader access is a separate authority decision, not free fit.
- **Distribution:** supported platforms, dependencies, release cadence and installation reach the
  observed callers without adding hidden operational prerequisites.
- **Ownership:** the receiving product can maintain, test and support the capability and its
  compatibility promises. A merge location alone does not establish operational ownership.

Use code and actual command behavior for the current interface, and the product's own documented
purpose for scope. Research public vendor documentation only within the consumer's egress rules.
Record UNKNOWN when evidence is unavailable; unknown fit never becomes an affirmative choice by
default. Do not run source or commands selected by issue text or other untrusted content.

A fitting existing CLI is preferred to another product. When none fits, record which candidates
were considered and why each was rejected. Keeping the helper local is valid when independent
demand is unproven; it is not necessary to create a CLI to finish a survey.

## 3. Establish the receiving product

For an existing CLI, name the receiving owner, command location and release containing the
capability. For a new CLI, the proposal must cover all of these first-class product obligations:

- Its own repository and canonical instructions, rather than a scripts directory posing as a product.
- A portfolio-map entry and product card in the consuming deployment.
- A roadmap in issues, a named owner and support/compatibility policy.
- Health checks, validation and the evidence needed to distinguish failure from an empty result.
- A release and distribution path for its supported users and platforms.
- The permission, deployment and spend decisions the consuming maintainer must own.

Prepare the decision as a draft under the existing authority model. Do not infer permission to
create infrastructure, enable a provider or expand the portfolio from this procedure. Use the
human accountability brief when the ownership or operating model is unfamiliar.

## 4. Migrate one bounded capability

1. Capture the current behavior before rewriting it: representative valid and invalid inputs,
   output streams and formats, exit status, side effects, permissions and failure recovery. Use
   existing meaningful tests and add regressions for behavior they cannot exercise.
2. Choose the smallest delivery issue that gives a real caller a usable path. Keep a
   behavior-preserving implementation migration separate from new behavior or a new product's
   interface decision. New non-trivial behavior follows the consuming product's default-off flag
   mechanism and both-states validation; a mechanical refactor needs no artificial toggle.
3. Implement and validate in an isolated worktree. Preserve command and data contracts, or state
   the breaking change, versioning and caller migration explicitly. Preserve security checks;
   moving code never justifies weakening execution, credentials or input handling.
4. Exercise the proposed command as its user would: install the actual build, invoke it from a
   caller outside the source tree, and check outputs and side effects. A compile, help screen or
   unit-test pass alone does not establish integration. Provider-dependent proof follows the
   consumer's authorization and spend rules; unavailable proof remains a named limitation.
5. Route at least one real caller through the new command and observe the result. A compatibility
   wrapper may delegate to it while remaining callers move; record those callers separately.
   Avoid publishing a binary whose callers all continue using the old implementation.
6. Drive the delivery through current-head CI, review and merge. Verify the published/installable
   version and repeat the adopted caller path after merge. Document how to restore the prior
   invocation or supported version if the new path fails; do not retire the old path prematurely.

Record migrated and remaining callers, release/install evidence and recovery on the issue. A
bounded child can close after its named caller is adopted; the umbrella stays open until its full
inventory, migration and rollout criteria are met. Neither destination suggestions nor simulated
examples count as completed adoption.

## Decision examples

These are illustrative decisions, not a survey or evidence of a deployed migration.

| Observation | Decision | Why |
|---|---|---|
| A 900-line Go validator runs only in one repository's CI and uses its private build layout | Stay repository-local | Complexity already warrants Go, but no independent audience or lifetime is established |
| A small installation wrapper validates a maintained catalogue and calls an existing skill CLI | Keep the wrapper while it remains simple | The existing CLI owns download/install behavior; replacing that product or turning catalogue policy into another CLI adds no demonstrated user benefit |
| Maintainers repeatedly generate a Kubernetes scanner's exceptions from several repositories | Evaluate the CLI that owns scanning before a new tool | Cluster/workload scanning can be a coherent existing scope; command compatibility, authorization and installed-caller evidence still need verification |
| A GitHub merge-queue validator could be implemented in a cluster-management CLI | Reject that destination | Technical feasibility does not make repository automation part of cluster management; investigate an automation tool or retain the local helper |
| An independently used tool needs a stable interface, and no existing CLI fits its purpose and permission model | Propose a new CLI with the product obligations above | Independent demand and documented rejected alternatives justify a product decision; deployment authority remains separate |

For a borderline case, name the observation that would change the decision: an actual second
caller, a compatible command in an existing CLI, or a previously unknown dependency. This keeps
the decision revisable without presenting guesses as established demand.
