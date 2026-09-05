# Agent Skills

Reusable instructions that help AI coding assistants work with Kubernetes, GitHub, Go, web design, and software engineering. This catalogue is for developers using Codex, Claude Code, GitHub Copilot, Cursor, or another assistant that supports [Agent Skills](https://agentskills.io).

## Installing

With [GitHub CLI](https://cli.github.com/) 2.90.0 or newer, run this from your project to add our engineering workflow skill for Codex:

```sh
gh skill install devantler-tech/agent-skills ways-of-working --agent codex --scope project
```

Use `--agent claude-code`, `github-copilot`, `cursor`, or `gemini-cli` for another assistant. See the [installation guide](docs/installation.md) for other installers, updates, and installing several skills or agents together. Prefer a ready-made bundle? Browse [Agent Plugins](https://github.com/devantler-tech/agent-plugins).

## Skills

Expand a category and copy a skill’s install command. The source column names the repository that maintains it.

<details>
<summary>GitOps &amp; Kubernetes</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `gitops-cluster-debug` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-cluster-debug) | `gh skill install fluxcd/agent-skills gitops-cluster-debug` |
| `gitops-knowledge` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-knowledge) | `gh skill install fluxcd/agent-skills gitops-knowledge` |
| `gitops-repo-audit` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/gitops-repo-audit) | `gh skill install fluxcd/agent-skills gitops-repo-audit` |
| `gitops-tenant-onboarding` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/gitops-tenant-onboarding) | `gh skill install devantler-tech/agent-skills gitops-tenant-onboarding` |
| `siderolabs` | [`siderolabs/docs`](https://github.com/siderolabs/docs/tree/main/skills/siderolabs) | `gh skill install siderolabs/docs siderolabs` |

</details>

<details>
<summary>GitHub</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `gh-stack` | [`github/gh-stack`](https://github.com/github/gh-stack/tree/main/skills/gh-stack) | `gh skill install github/gh-stack gh-stack` |
| `github-issues` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/github-issues) | `gh skill install github/awesome-copilot github-issues` |

</details>

<details>
<summary>Copilot</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `copilot-instructions-blueprint-generator` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/copilot-instructions-blueprint-generator) | `gh skill install github/awesome-copilot copilot-instructions-blueprint-generator` |
| `copilot-sdk` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/copilot-sdk) | `gh skill install github/awesome-copilot copilot-sdk` |
| `find-skills` | [`vercel-labs/skills`](https://github.com/vercel-labs/skills/tree/main/skills/find-skills) | `gh skill install vercel-labs/skills find-skills` |

</details>

<details>
<summary>Go</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `bubbletea` | [`ggprompts/tfe`](https://github.com/ggprompts/tfe/tree/main/.claude/skills/bubbletea) | `gh skill install ggprompts/tfe bubbletea --allow-hidden-dirs` |
| `golang-pro` | [`Jeffallan/claude-skills`](https://github.com/Jeffallan/claude-skills/tree/main/skills/golang-pro) | `gh skill install Jeffallan/claude-skills golang-pro` |

</details>

<details>
<summary>Git</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `git-commit` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/git-commit) | `gh skill install github/awesome-copilot git-commit` |

</details>

<details>
<summary>Agentic Engineer</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `agent-improvement` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/agent-improvement) | `gh skill install devantler-tech/agent-skills agent-improvement` |
| `portfolio-maintenance` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/portfolio-maintenance) | `gh skill install devantler-tech/agent-skills portfolio-maintenance` |
| `product-engineering` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/product-engineering) | `gh skill install devantler-tech/agent-skills product-engineering` |
| `self-improvement` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/self-improvement) | `gh skill install devantler-tech/agent-skills self-improvement` |

</details>

<details>
<summary>Engineering Practices</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `agent-instructions` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/agent-instructions) | `gh skill install devantler-tech/agent-skills agent-instructions` |
| `conventional-release` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/conventional-release) | `gh skill install devantler-tech/agent-skills conventional-release` |
| `refactor` | [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/refactor) | `gh skill install github/awesome-copilot refactor` |
| `test-driven-development` | [`obra/superpowers`](https://github.com/obra/superpowers/tree/main/skills/test-driven-development) | `gh skill install obra/superpowers test-driven-development` |
| `ways-of-working` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/ways-of-working) | `gh skill install devantler-tech/agent-skills ways-of-working` |

</details>

<details>
<summary>Vibe Coding</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `allowed-stack-guardrail` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/allowed-stack-guardrail) | `gh skill install devantler-tech/agent-skills allowed-stack-guardrail` |
| `jargon-free-voice` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/jargon-free-voice) | `gh skill install devantler-tech/agent-skills jargon-free-voice` |
| `needs-stack-mapping` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/needs-stack-mapping) | `gh skill install devantler-tech/agent-skills needs-stack-mapping` |

</details>

<details>
<summary>Frontend &amp; Design</summary>

| Skill | Upstream | Install |
|-------|----------|---------|
| `astro` | [`astrolicious/agent-skills`](https://github.com/astrolicious/agent-skills/tree/main/skills/astro) | `gh skill install astrolicious/agent-skills astro` |
| `frontend-design` | [`anthropics/skills`](https://github.com/anthropics/skills/tree/main/skills/frontend-design) | `gh skill install anthropics/skills frontend-design` |
| `web-design-guidelines` | [`vercel-labs/agent-skills`](https://github.com/vercel-labs/agent-skills/tree/main/skills/web-design-guidelines) | `gh skill install vercel-labs/agent-skills web-design-guidelines` |

</details>

## Contributing

Have a useful skill to share? Read the [contribution guide](docs/contributing.md). For checks and release maintenance, see [AGENTS.md](AGENTS.md).

### Inclusion criteria

Skills must be reusable, follow the Agent Skills format, and come from a maintained source. The [full inclusion criteria](docs/contributing.md#inclusion-criteria) explain what to check before adding a catalogue entry.

## License

[Apache 2.0](LICENSE). Each linked upstream skill has its own license.
