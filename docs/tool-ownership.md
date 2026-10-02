# Skill tool ownership and callers

This assessment records the tools at source revision
[`5d61a1157328fd1f84218d2509b085cff64ecd52`](https://github.com/devantler-tech/agent-skills/tree/5d61a1157328fd1f84218d2509b085cff64ecd52),
examined on 2026-10-02 for
[the tool-maturation roadmap](https://github.com/devantler-tech/agent-plugins/issues/102).
It records repository callers and declared installed interfaces, rather than asserting complete
operational usage across the portfolio. Decisions apply to these observed contracts.

## Scope and evidence

The installed product-engineering inventory inspected the exact committed tree, independently
compared its leaf census with Git's raw diff, and selected all six regular non-test `*.sh` files.
A separate complete tree listing selected both Go files: one non-test entrypoint and its test.
The non-test file was read as source; no surveyed package was built or executed for this assessment.
Targeted searches traced each candidate through workflows, scripts and documentation. Tests provide
validation evidence, not independent production consumers. Source reads and documentation alone
do not prove that an installed caller has run.

The assessment also includes the three installed jq programs and the catalogue's AWK companion.
Shell tests, Go tests, workflow inline commands and example JSON are validation or calling surfaces,
not separately promoted products. Other portfolio repositories and runtime telemetry are outside
this scope. Dynamic or undeclared external callers remain UNKNOWN. A complete path census does not
turn those unknowns into a complete caller census.

## Decisions for the selected tools

Paths below are relative to this repository. All retained tools keep this repository as their
source owner; none receives a separate command product or release lifecycle.

| Candidate | Observed caller and job | Decision and rationale |
|---|---|---|
| [`scripts/install.sh`](../scripts/install.sh) | [Installation guide](installation.md): install the README catalogue for selected agents through `gh skill install` | Keep the Bash catalogue wrapper. GitHub CLI owns installation and provenance; the repository owns catalogue selection and early validation. Replacing the installer duplicates an existing CLI's task. |
| [`scripts/check-readme-index.sh`](../scripts/check-readme-index.sh) | [CI](../.github/workflows/ci.yaml), and the [contribution guide](contributing.md): check catalogue rows against source skill directories | Keep repository-local Bash policy using the shared index reader. Another product's catalogue is not an observed compatible caller. |
| [`scripts/check-upstream-skills.sh`](../scripts/check-upstream-skills.sh) | [Upstream-target workflow](../.github/workflows/check-upstream-skills.yaml): resolve declared catalogue targets and classify transport failure separately from drift | Keep the Bash wrapper and GitHub CLI transport. Catalogue-specific identity and outage policy remain here; a generic GitHub API client does not own that verdict. |
| [`scripts/publish-skills-release.sh`](../scripts/publish-skills-release.sh) | [CD](../.github/workflows/cd.yaml): bind the tag and release to a clean expected source commit, validate with `gh skill publish --dry-run`, then create and verify the release through GitHub CLI | Keep repository-local release orchestration. Reuse GitHub CLI publication, retain source/tag checks and recovery policy here. Marketplace publication is a different contract. |
| [`scripts/readme-index.sh`](../scripts/readme-index.sh) | The installer and both index guards invoke the reader in their required modes | Keep local sharing. Three callers in one product justify one reader, not a new library product. Its AWK companion implements the same catalogue contract. |
| [`product-engineering/scripts/inspect-shell-helpers.sh`](../product-engineering/scripts/inspect-shell-helpers.sh) | The installed [tool-maturation procedure](../product-engineering/references/tool-maturation.md) explicitly invokes an exact-revision, read-only observation | Keep the installed skill helper, distributed with its owning skill. Git owns object reads; the helper owns bounded census evidence. An installation outside the source tree does not by itself demand an independently supported CLI. |
| [`product-engineering/scripts/go-entrypoint.go`](../product-engineering/scripts/go-entrypoint.go) | The inventory wrapper's explicit `--include-go` mode builds this installed parser, then sends retained source blobs to it | Keep the Go syntax mechanism beside the skill wrapper. Use the standard library parser; no inspected Go package or dependency runs. Its boolean entrypoint verdict is not the marketplace decoder's text-extraction contract. |

## Companion programs and shared-code fit

| Companion | Actual contract and owner |
|---|---|
| [`scripts/readme-index.awk`](../scripts/readme-index.awk) | Invoked by the local index reader; validates and emits modes from the maintained README Skills tables. Keep this repository's catalogue grammar local. |
| [`agent-improvement/scripts/measure-flow.jq`](../agent-improvement/scripts/measure-flow.jq) | The installed [flow procedure](../agent-improvement/references/prioritization-flow.md) evaluates reported run evidence. Keep with agent-improvement; its inputs do not authenticate the runtime or authorize action. |
| [`product-engineering/scripts/check-evidence.jq`](../product-engineering/scripts/check-evidence.jq) | The installed [evidence procedure](../product-engineering/references/evidence-bundle.md) evaluates a preregistered evidence bundle. Keep its decision policy with product-engineering. |
| [`product-engineering/scripts/accountability-brief.jq`](../product-engineering/scripts/accountability-brief.jq) | The installed [accountability procedure](../product-engineering/references/accountability-brief.md) checks and renders human-readable briefs. Keep its schema and rendering contract with the skill. A render is not evidence that a maintainer understood it. |

The entrypoint parser uses `go/parser`, `go/ast` and `go/token`. The separately examined
[Agent Plugins guidance decoder at its frozen revision](https://github.com/devantler-tech/agent-plugins/blob/00519de5b7836402c087e99c3e498e8e3ab97ed2/scripts/gh-json-go/main.go)
uses the same standard library; it is a tool in that other repository, not a consumer of this parser.
Their policies differ: one classifies entrypoint declarations; the other decodes bounded comments,
string literals and command-argument guidance. Reuse the existing syntax library and retain those
policies locally. Neither similar AST traversal nor these distinct tools establishes extraction demand.

Bundled copies in Agent Plugins are a distribution path for the same skill source, not a second
independent product requirement. Neither copied helper files nor extra test invocations satisfy
the two-product demand bar for extracting a shared library. No service requirement or shared
authoritative state is established by these callers.

## Existing CLI alternatives and delivery boundaries

Git and GitHub CLI already own object reads, authenticated forge access and skill installation.
This repository's helpers compose those interfaces with skill catalogue or evidence policy.
KSail's cluster-management purpose does not fit these jobs. A new maintenance CLI would add a
distribution and compatibility obligation without an observed task that the existing owners
cannot serve. Keep the current owners; reassess if a real independent caller requires a stable
interface outside the owning skill or repository lifecycle.

The installed census was exercised against both scoped repositories during this assessment;
optional Go execution was not repeated because the host disk guard prohibited local builds.
Existing source CI separately validates the Go parser and its wrapper. This evidence establishes
the selected paths and supported call structure, not portfolio-wide migration or runtime adoption.

Changing one of these decisions requires a delivery issue with the real caller, compatibility,
failure behavior, installation and recovery requirements. A source implementation change must
publish through the source release and normal marketplace sync; a bundled copy is never hand-edited.
Until a replacement is actually released and adopted, retain the existing interfaces. Source-release
publication uses the CD workflow's publisher from a clean repository-root checkout at the full
release commit, with `origin` identifying this repository:

```bash
./scripts/publish-skills-release.sh --tag "$tag" \
  --repo devantler-tech/agent-skills --expected-commit "$release_commit"
```

A reserved tag without a matching non-draft release is a partial failure; rerunning this command
alone will refuse it. An authorized release operator must first freshly verify that the tag still
resolves to the intended release commit and that the release is absent, revalidate that clean checkout
with `gh skill publish --dry-run`, and complete the missing non-draft GitHub release for that verified
tag and commit using the existing publication permissions. Then rerun the publisher above to verify
both remote facts. Unreadable state, a different tag target or a conflicting release remains a hold;
do not automatically delete or move the reserved tag. The umbrella roadmap remains open for its
unsurveyed repositories and migration requirements.
