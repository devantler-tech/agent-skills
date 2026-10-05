# Installing skills

A skill is a set of instructions your coding assistant loads for a particular task. Choose an installer below, then copy the command for the skill you want from the [catalogue](../README.md#skills). Skills whose source is `devantler-tech/agent-skills` are maintained here; other rows point to the repositories that maintain them.

| CLI | Reaches | Best for |
|-----|---------|----------|
| [`gh skill`](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/) | Every catalogue entry, using its listed command | Records the source so `gh skill update --all` can fetch updates. Copy the command from the catalogue. |
| [`npx skills`](https://github.com/vercel-labs/skills) | Skills hosted in the repository you name | Choose several skills or agents interactively. For a skill maintained elsewhere, name its source repository (for example, `npx skills add fluxcd/agent-skills`). |

> [!NOTE]
> There is no registry to sign up for and no package to publish — both CLIs resolve `owner/repo` straight from GitHub.

## With `npx skills`

[`npx skills`](https://github.com/vercel-labs/skills) needs no install of its own and prompts for which skills and which agents you want. Pointed at this repo it offers the skills maintained here; for other catalogue entries, name the skill's source repository.

> [!NOTE]
> Requires **Node.js ≥ 22.20.0** (the `skills` package's declared `engines.node`). On an older Node this fails before any skill is fetched. `gh skill` has no Node dependency.

```sh
# Browse what's on offer without installing anything
npx skills add devantler-tech/agent-skills --list

# Install specific skills for specific agents
npx skills add devantler-tech/agent-skills --skill ways-of-working --agent claude-code

# Install every in-house skill, for EVERY supported agent, no prompts.
# Note --all is not scoped to agents you have installed — pass --agent to limit it.
npx skills add devantler-tech/agent-skills --all
```

Add `-g` to install to your user directory instead of the current project.

The [skills.sh](https://skills.sh) directory has no submission step — it lists a repo off **anonymous install telemetry** from this CLI. That telemetry is opt-out (`DISABLE_TELEMETRY` or `DO_NOT_TRACK`) and is disabled automatically in CI, so only telemetry-enabled installs contribute to a listing.

## With `gh skill`

Each `gh skill install` accepts `--agent <name>`, `--scope user|project`, and `--pin <ref>` (or an `@ref` suffix on the skill name) — see `gh skill install --help` for the full list of supported agents.

The install commands in the [catalogue tables](../README.md#skills) use the default agent (GitHub Copilot) at project scope. To install for **Claude Code** instead, or for **both agents at once at user scope** (so the skill is available everywhere), add `--agent` / `--scope`:

```sh
# GitHub Copilot, user scope -> ~/.copilot/skills/<skill>/
gh skill install devantler-tech/agent-skills ways-of-working --agent github-copilot --scope user

# Claude Code, user scope -> ~/.claude/skills/<skill>/
gh skill install devantler-tech/agent-skills ways-of-working --agent claude-code --scope user
```

## Install everything for both Copilot and Claude

[`scripts/install.sh`](../scripts/install.sh) installs every skill listed in the [catalogue](../README.md#skills) for the agents you name (default: `github-copilot` and `claude-code`) at user scope:

Run these commands from a clone of this repository:

```sh
./scripts/install.sh --help                   # usage, without reading the catalogue or calling gh
./scripts/install.sh --list                   # preview the catalogue without installing
./scripts/install.sh                          # both Copilot + Claude Code (user scope)
./scripts/install.sh claude-code              # just Claude Code
AGENTS="github-copilot claude-code cursor" ./scripts/install.sh   # any gh skill agents
```

The script validates the complete README catalogue before printing a preview or starting an
installation. Every table row must have an install command matching its skill name and source
link. A malformed or contradictory row exits 1 without installing anything or printing a partial
preview. Table rows may omit either outer pipe. Rendered peer and parent headings end
the Skills section; deeper category headings remain inside it. Prose commands, fenced examples,
HTML comments and raw HTML blocks are excluded.
A backtick fence opener whose info string contains a backtick is treated as ordinary Markdown.
Installation, the offline index check,
and upstream target checking share this interpretation; the offline check also verifies maintained
skill directories and rejects duplicate rows.
Unterminated comments and reference titles are rejected before installation.

`--help` (`-h`) and
`--list` (`-l`) are standalone modes and need no authentication or network access. Do not combine
them with agent names.

All catalogue sources are on github.com. The script sets `GH_HOST=github.com` for
its GitHub CLI calls, so an enterprise host in your environment does not redirect
these installations. For a catalogue command run directly, prefix it with
`GH_HOST=github.com` if your default host is an enterprise instance.
The upstream target checker also uses github.com independently of that default.

Each installed skill name must identify one source repository. If the catalogue
lists the same name from different repositories, installation and `--list` exit 1
and name both sources before calling GitHub CLI. Repeated entries for the same
repository and skill, including repository casing aliases, are installed once.
Each repository and source ref resolves once before installation. Skills sharing that source use
the same frozen commit even if its branch moves during the run; different refs remain separate.
Installation selects the exact source directory from the catalogue link, with a `SKILL.md` suffix.
Another skill with the same name elsewhere in that repository cannot replace that selection.
Before writing user scope, the batch command stages every pinned source in a separate private
directory using GitHub CLI. Its actual installed name must match the advertised skill, so a
different frontmatter name cannot overwrite another entry. Failed or incomplete staging stops
the batch before any user skill is replaced. Final installs keep the original remote provenance.
Catalogue commands support literal `--agent`, `--scope`, `--dir`, `--pin`, `--force` (`-f`) and
`--allow-hidden-dirs` options. Value options also accept `--option=value`. Each option occurs once;
an explicit pin must match the link's source ref. Unsupported options, missing values and extra
arguments refuse the whole catalogue before installation. The batch command chooses its own agents
and user scope; those documented options describe commands run directly.
Source responses must contain one unambiguous commit identity. When a catalogue link names
a full commit, the returned identity must match it. Installation requires `jq` and `iconv` and
validates the original response bytes as UTF-8 JSON before decoding the commit. Raw NULs,
malformed UTF-8, repeated declarations and failed API reads refuse before private staging.
A conflicting or incomplete response stops
the complete installation before any skill is replaced. The upstream target checker also refuses
repeated file declarations instead of selecting one interpretation.
It resolves each repository/ref once and checks all sibling files at that immutable revision;
a moving branch cannot supply a successful catalogue from files that never coexisted.

The offline index guard compares two independent inventories in the exact physical checkout,
including hidden directories and checkout names ending in newlines. A partial listing cannot
establish that every maintained skill is indexed.

Positional agent names override `AGENTS`. An unset or empty `AGENTS` uses the two default agents;
otherwise, spaces, tabs, and newlines separate names without expanding wildcard characters into
filenames. Unknown options, empty names, and whitespace-only `AGENTS` values fail with usage and
exit code 2 before any installation starts. Supported agent names come from `gh skill install --help`.

Installation uses user scope and replaces existing copies with `--force`. If an individual skill
fails, the script prints its error, attempts the remaining installations, and exits 1 with the total
failure count. A successful installation or preview exits 0.

## Automated installation and updates

To adopt these skills in another repository:

- [`devantler-tech/actions/setup-agent-skills`](https://github.com/devantler-tech/actions/tree/main/setup-agent-skills) — composite action that installs a newline list of `<owner/repo> <skill>[@pin]` entries, for one or more agents.
- [`devantler-tech/actions/update-agent-skills`](https://github.com/devantler-tech/actions/tree/main/update-agent-skills) — composite action that runs `gh skill update --all` against the checked-in skills.
- [`devantler-tech/actions/.github/workflows/update-agent-skills.yaml`](https://github.com/devantler-tech/actions/blob/main/.github/workflows/update-agent-skills.yaml) — reusable workflow that opens a PR when any skill's upstream has drifted.

All three rely on the `github-*` metadata that `gh skill install` injects into each `SKILL.md`, so no lockfile or external manifest is required.
