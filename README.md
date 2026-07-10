# devantler-tech/agent-skills

A curated index of generic [agent skills](https://agentskills.io) installable with the [`gh skill`](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/) CLI (v2.90.0+).

These skills are **agent-neutral**: every `SKILL.md` follows the [`agentskills.io`](https://agentskills.io) spec, so the same skill works in **GitHub Copilot, Claude Code, Cursor, Codex, Gemini CLI**, and the other agents `gh skill` supports — pick the target with `--agent`. See [Installing](#installing) to install for one agent or several at once.

This repo is a **pointer list** and publisher of in-house skills. Each row below is either an in-house skill or installs directly from its original upstream so `gh skill` records the true source in the skill's `SKILL.md` frontmatter (`metadata.github-repo`, `github-path`, `github-ref`, `github-tree-sha`) and `gh skill update --all` works natively — no lockfile, no sync bot, no custom metadata.

## Skills

<details open>
<summary>GitOps &amp; Kubernetes</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `gitops-cluster-debug` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-cluster-debug) | `gh skill install fluxcd/agent-skills gitops-cluster-debug` |
| `gitops-knowledge` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-knowledge) | `gh skill install fluxcd/agent-skills gitops-knowledge` |
| `gitops-repo-audit` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-repo-audit) | `gh skill install fluxcd/agent-skills gitops-repo-audit` |
| `gitops-tenant-onboarding` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/gitops-tenant-onboarding) | `gh skill install devantler-tech/agent-skills gitops-tenant-onboarding` |
| `siderolabs` | [`siderolabs/docs`](https://github.com/siderolabs/docs/tree/main/skills/siderolabs) | `gh skill install siderolabs/docs siderolabs` |

</details>

<details open>
<summary>GitHub</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `gh-stack` | [`github/gh-stack`](https://github.com/github/gh-stack/tree/main/skills/gh-stack) | `gh skill install github/gh-stack gh-stack` |
| `github-actions-docs` | [`xixu-me/skills`](https://github.com/xixu-me/skills/tree/main/skills/github-actions-docs) | `gh skill install xixu-me/skills github-actions-docs` |
| `github-issues` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/github-issues) | `gh skill install github/awesome-copilot github-issues` |

</details>

<details open>
<summary>Copilot</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `copilot-instructions-blueprint-generator` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/copilot-instructions-blueprint-generator) | `gh skill install github/awesome-copilot copilot-instructions-blueprint-generator` |
| `copilot-sdk` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/copilot-sdk) | `gh skill install github/awesome-copilot copilot-sdk` |
| `find-skills` | [`vercel-labs/skills`](https://github.com/vercel-labs/skills/tree/main/skills/find-skills) | `gh skill install vercel-labs/skills find-skills` |

</details>

<details open>
<summary>Go</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `bubbletea` | [`ggprompts/tfe`](https://github.com/ggprompts/tfe/tree/main/.claude/skills/bubbletea) | `gh skill install ggprompts/tfe bubbletea --allow-hidden-dirs` |
| `golang-pro` | [`Jeffallan/claude-skills`](https://github.com/Jeffallan/claude-skills/tree/main/skills/golang-pro) | `gh skill install Jeffallan/claude-skills golang-pro` |

</details>

<details open>
<summary>Git</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `git-commit` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/git-commit) | `gh skill install github/awesome-copilot git-commit` |

</details>

<details open>
<summary>Engineering Practices</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `agent-instructions` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/agent-instructions) | `gh skill install devantler-tech/agent-skills agent-instructions` |
| `conventional-release` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/conventional-release) | `gh skill install devantler-tech/agent-skills conventional-release` |
| `refactor` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/refactor) | `gh skill install github/awesome-copilot refactor` |
| `test-driven-development` | [`obra/superpowers`](https://github.com/obra/superpowers/tree/main/skills/test-driven-development) | `gh skill install obra/superpowers test-driven-development` |
| `ways-of-working` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/ways-of-working) | `gh skill install devantler-tech/agent-skills ways-of-working` |

</details>

<details open>
<summary>Frontend &amp; Design</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `astro` | [`astrolicious/agent-skills`](https://github.com/astrolicious/agent-skills/tree/main/skills/astro) | `gh skill install astrolicious/agent-skills astro` |
| `frontend-design` | [`anthropics/skills`](https://github.com/anthropics/skills/tree/main/skills/frontend-design) | `gh skill install anthropics/skills frontend-design` |
| `web-design-guidelines` | [`vercel-labs/agent-skills`](https://github.com/vercel-labs/agent-skills/tree/main/skills/web-design-guidelines) | `gh skill install vercel-labs/agent-skills web-design-guidelines` |

</details>

## Installing

Each `gh skill install` accepts `--agent <name>`, `--scope user|project`, and `--pin <ref>` (or an `@ref` suffix on the skill name) — see `gh skill install --help` for the full list of supported agents.

The install commands in the tables above use the default agent (GitHub Copilot) at project scope. To install for **Claude Code** instead, or for **both agents at once at user scope** (so the skill is available everywhere), add `--agent` / `--scope`:

```sh
# GitHub Copilot, user scope -> ~/.copilot/skills/<skill>/
gh skill install devantler-tech/agent-skills ways-of-working --agent github-copilot --scope user

# Claude Code, user scope -> ~/.claude/skills/<skill>/
gh skill install devantler-tech/agent-skills ways-of-working --agent claude-code --scope user
```

### Install everything for both Copilot and Claude

[`scripts/install.sh`](scripts/install.sh) installs every skill listed above for the agents you name (default: `github-copilot` and `claude-code`) at user scope:

```sh
./scripts/install.sh                          # both Copilot + Claude Code (user scope)
./scripts/install.sh claude-code              # just Claude Code
AGENTS="github-copilot claude-code cursor" ./scripts/install.sh   # any gh skill agents
```

The script is the single source of truth's consumer — it reads the install commands straight out of this README, so it never drifts from the index.

## Automated installation and updates

To adopt these skills in another repository:

- [`devantler-tech/actions/setup-agent-skills`](https://github.com/devantler-tech/actions/tree/main/setup-agent-skills) — composite action that installs a newline list of `<owner/repo> <skill>[@pin]` entries, for one or more agents.
- [`devantler-tech/actions/update-agent-skills`](https://github.com/devantler-tech/actions/tree/main/update-agent-skills) — composite action that runs `gh skill update --all` against the checked-in skills.
- [`devantler-tech/actions/.github/workflows/update-agent-skills.yaml`](https://github.com/devantler-tech/actions/blob/main/.github/workflows/update-agent-skills.yaml) — reusable workflow that opens a PR when any skill's upstream has drifted.

All three rely on the `github-*` metadata that `gh skill install` injects into each `SKILL.md`, so no lockfile or external manifest is required.

## Contributing

This repository follows the [`agentskills.io`](https://agentskills.io) spec: skill directories live at the repository root and include a conformant `SKILL.md` at their root.

Every pull request runs the [`🧪 CI`](.github/workflows/ci.yaml) workflow, whose `CI - Required Checks` aggregator gates the merge on four jobs:

- **Publish dry-run** — `gh skill publish --dry-run` confirms the repo is publishable as a skill bundle.
- **Spec validation** — each in-house skill is validated against the [`agentskills.io`](https://agentskills.io) spec with `skills-ref validate`.
- **Script lint** — `shellcheck` over `scripts/*.sh`.
- **Index lockstep** — [`./scripts/check-readme-index.sh`](scripts/check-readme-index.sh) asserts the README `## Skills` tables stay in lockstep with every consumer: a non-empty parse, parsed install-count equal to the number of table rows, every in-house skill present in the index, every in-house entry resolving to an on-disk `SKILL.md`, and each row's Skill/Upstream/Install columns agreeing (so a typo'd repo or slug can't ship a broken install command).

A separate [`🔗 Upstream skill targets`](.github/workflows/check-upstream-skills.yaml) workflow verifies every *upstream* row still resolves to a real skill at its source. It runs weekly and on any PR that touches the index, but is **deliberately not** a required check — a third-party outage must never block a contributor PR, so transient errors downgrade to warnings and only definitive drift fails.

Releases are cut automatically on every push to `main` — [`release.yaml`](.github/workflows/release.yaml) uses [`mathieudutour/github-tag-action`](https://github.com/mathieudutour/github-tag-action) to derive the next version tag from [commit conventions](https://www.conventionalcommits.org/), and [`cd.yaml`](.github/workflows/cd.yaml) then runs `gh skill publish` against the resulting tag. The publish pipeline publishes in-house skills (e.g. `ways-of-working`) on each release.

### Inclusion criteria

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
  existing ones.
- **Lockstep.** Every change updates the README `## Skills` tables — the **single source of truth**
  that `install.sh` and the `setup-`/`update-agent-skills` consumers parse. Never hand-maintain a
  parallel list; run [`./scripts/check-readme-index.sh`](scripts/check-readme-index.sh) — the same gate CI enforces — before
  opening a PR.

See the [devantler-tech organization guidelines](https://github.com/devantler-tech/.github) for PR/issue templates and general contribution rules.

## License

Apache 2.0 — see [`LICENSE`](LICENSE).
