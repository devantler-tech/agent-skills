# Contributing skills

Suggest a skill by opening an issue, or add it to the [catalogue](../README.md#skills) in a pull request. For a skill maintained elsewhere, link to its original repository. Add a local skill directory only for skills maintained by devantler-tech.

The catalogue drives automated installation, so every row must keep its skill name, source link,
and install command consistent. No cluster, cloud credentials, or publishing permissions are
needed for a first catalogue contribution.

Report sensitive vulnerabilities through [GitHub's private vulnerability reporting](https://github.com/devantler-tech/agent-skills/security/advisories/new),
not a public issue or pull request. Follow the [shared code of conduct](https://github.com/devantler-tech/.github/blob/main/.github/CODE_OF_CONDUCT.md).

## Make your first catalogue contribution

You need Git, Bash, and standard Unix command-line tools. The offline catalogue checks work on
macOS and Linux. Fork this repository on GitHub, then clone your fork and create a branch:

```sh
git clone https://github.com/YOUR-USERNAME/agent-skills.git
cd agent-skills
git switch -c docs/add-skill
```

Replace `YOUR-USERNAME` with your GitHub login. From this repository root, add a row under the
best-fitting category in `README.md`'s `## Skills` section. For an upstream skill, use its exact
skill name, a link to its source directory, and the matching `gh skill install` command. Check
the [inclusion criteria](#inclusion-criteria) before choosing a source.

Run these from the repository root:

```sh
./scripts/install.sh --list
./scripts/check-readme-index.sh
```

The first command lists every indexed source and skill without installing anything or contacting
GitHub. The second must finish successfully with no index errors. It checks row consistency and
that every local skill is indexed; it does not prove an external source is available.

These are starting checks, not the full pre-PR gate. Before opening a PR, run the relevant
[validation commands](../AGENTS.md#validation), including skill format/specification validation
and script checks. That section names the exact tools and pinned validator revision.

For any catalogue edit, also install [GitHub CLI](https://cli.github.com/) and `jq`, sign in with
`gh auth login`, and run `./scripts/check-upstream-skills.sh`. This makes read-only network requests;
an outage warning is not proof that a source exists. Resolve reported drift before submitting.

## Adding an original skill

Add a root-level directory named after the skill, containing `SKILL.md` with valid `name`,
`description`, and `license` frontmatter. Index it in the README as well. Keep the instructions
short, reusable, and agent-neutral. A `SKILL.md` may be at most 500 lines and 20,000 bytes; put
detail an agent needs only at one step in a `references/` file and link it from that step.
`scripts/check-skill-size.sh` enforces the budget recorded in `.github/skill-size-budget.tsv`.
Try the instructions on a realistic task and record where a first-time reader needs unstated
knowledge; format validation alone does not prove the instructions work.

With GitHub CLI 2.90.0 or newer, run this from the repository root:

```sh
gh skill publish --dry-run
```

This validates the skills without publishing a release. CI also runs the pinned Agent Skills
specification validator and script checks. See [AGENTS.md's validation section](../AGENTS.md#validation)
for those exact checks, including the validator revision; use it when changing scripts or supporting
resources instead of copying a second check matrix here.

## Submit and respond to review

Open an issue before a substantial change. After validation, commit and push your example catalogue
change from the repository root:

```sh
git add README.md
git commit -m "docs: add a useful catalogue entry"
git push --set-upstream origin docs/add-skill
```

For another kind of change, stage only the files you intentionally changed and use a matching
commit message. Open a pull request on GitHub from your fork's branch into
`devantler-tech/agent-skills`'s `main` branch. Use the repository's pull request template and a
Conventional Commit title, such as `docs: add a useful catalogue entry` or `feat: add a new skill`.
Explain the reader problem, the source choice, and how you tried the change. Open work as a draft
until its validation and current-head review are complete. Never commit credentials or private
examples, and do not publish skills yourself as part of a contribution.

Respond to review on the PR, update your branch, and rerun the checks relevant to the change.
Maintainers handle merge and release; [AGENTS.md](../AGENTS.md) documents the full validation and
release contract. Follow the [organization contribution guidelines](https://github.com/devantler-tech/.github/blob/main/.github/CONTRIBUTING.md)
for shared templates and contribution requirements.

The [tool ownership assessment](tool-ownership.md) records the source helpers' callers, existing
CLI and library reuse, and the boundary between repository maintenance and installed skill resources.
Consult it before proposing a helper migration or a new shared tool.

## Inclusion criteria

Before adding a row, check the skill clears the bar this index is curated to. These criteria are
already applied in review — they are written here so every contributor (and the autonomous
assistant) applies the same bar:

- **Generic & reusable.** Index a skill only if it is useful **beyond a single project or person** —
  a general capability (a framework, a workflow, a language toolchain, an engineering practice).
  Project- or repo-specific knowledge belongs in *that* project, not here.
- **Upstream pointer by default.** Prefer a row that installs **directly from the skill's canonical
  upstream** (`gh skill install <owner/repo> <skill>`) so `gh skill update --all` tracks the true
  source — no fork, no copy. Add an in-house directory **only** for skills devantler-tech genuinely
  authors and maintains (e.g. `ways-of-working`).
- **Spec-conformant & agent-neutral.** The skill's `SKILL.md` must follow the
  [`agentskills.io`](https://agentskills.io) spec and stay **tool-neutral** — no Copilot/Claude-only
  assumptions — so it works across every agent `gh skill` supports.
- **Quality upstream.** Point only at an **actively-maintained, good-quality** source with a precise
  `description` (the field agents match on to trigger the skill). Avoid abandoned or low-signal
  upstreams.
- **Naming & category.** The row's skill slug matches the upstream skill name; place it under the
  best-fitting `## Skills` category, adding a new category only when a skill clearly fits none of the
  existing ones. Each skill name identifies one source repository across the catalogue: two
  upstreams with the same name would replace each other during batch installation, so the index
  check rejects that collision. Choose one canonical source rather than listing both.
- **Lockstep.** Every change updates the README `## Skills` tables — the **single source of truth**
  that `install.sh` and the `setup-`/`update-agent-skills` consumers parse. Never hand-maintain a
  parallel list; run [`./scripts/check-readme-index.sh`](../scripts/check-readme-index.sh) — the same gate CI enforces — before
  opening a PR.

See the [devantler-tech organization guidelines](https://github.com/devantler-tech/.github) for PR/issue templates and general contribution rules.
