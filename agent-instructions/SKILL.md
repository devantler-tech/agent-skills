---
name: agent-instructions
description: >-
  Architect a repository's AI-agent instruction files so one canonical source
  drives every tool without drift — AGENTS.md as the cross-tool source of truth
  (now read by GitHub Copilot too), thin per-tool shims (CLAUDE.md, GEMINI.md)
  that include it, and optional path-scoped .github/instructions/ rules. Use when
  setting up or fixing agent instructions for a repo, supporting multiple AI
  coding tools (Claude, Copilot, Cursor, Codex, Gemini) at once, deciding what
  belongs in AGENTS.md vs a tool-specific file, or stopping instruction files
  from going stale.
license: Apache-2.0
---

# Agent Instructions

Most AI coding tools read project guidance from a file in the repo — historically each looked in a
*different* place (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, …). Copy the same
guidance into each one and the copies **drift**: a command changes in one file and the others keep
telling agents the old way. The fix is one **canonical** source plus thin tool-specific **shims**
(which include the canonical file). Give each durable rule one canonical home: the root core,
a linked topic guide, or a nested instruction file. Keep genuine tool-specific quirks in a tool's own file.

The good news: `AGENTS.md` is now read by nearly every major tool — **including GitHub Copilot** — so
shared guidance can have one maintained source without a per-tool copy.

## The canonical file: `AGENTS.md`

`AGENTS.md` is the cross-tool standard — a plain-Markdown file at the repo root, read natively by a
growing set of agents and editors (Codex, Cursor, Gemini CLI, and GitHub Copilot). Make it the
**entrypoint** for durable, tool-neutral guidance:

- **What the project is** — one-paragraph purpose, the stack, where the important code lives.
- **How to build, test, validate, and run** — the exact commands an agent should use (and which
  one gates a PR). Be specific; agents run these verbatim.
- **Conventions** — code style, naming, commit/PR format, branch model, "definition of done".
- **Do / don't** — guardrails (never hand-edit generated files, never push to `main`, secret
  handling) and the project's non-obvious gotchas.
- **Pointers** — links to deeper docs rather than inlining them.

Write it **tool-neutral**: no "when you are Claude…" assumptions. Anything true only for one tool
goes in that tool's file, not here. Keep it readable and scoped: always-loaded guidance consumes
context even when most of it is unrelated to the task.

**Nested `AGENTS.md`.** In a monorepo or a large sub-package, drop an `AGENTS.md` in the subdirectory:
tools that support the standard read the nearest one and let it **take precedence** over the root on
conflicts. Reach for this before a path-scoped tool-specific file when the guidance is itself
tool-neutral.

## Keep the always-on file small

**Measure bytes as well as lines.** Codex's `project_doc_max_bytes` defaults to **32 KiB (32768
bytes)** for the combined project instruction chain. Excess guidance is truncated or omitted;
do not rely on an agent noticing missing rules. Leave room for nested files instead of filling
the root to the cap. Check the effective configuration and loaded chain in each supported runtime.
[Codex instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

Claude Code recommends **under about 200 lines per `CLAUDE.md`**, a readability target rather
than the Codex byte limit. `@` imports load with their referring file, so splitting the core
into imported guides does not save context.
[Claude Code memory guidance](https://code.claude.com/docs/en/memory).

Use three scopes, preserving each rule's authority and its trigger:

- **Always-on core:** the project map, essential commands, universal constraints, and a guide index.
- **On-demand guides:** detailed procedures needed only for a particular task. Link them normally;
  each index entry says when to read it, before taking the action it governs.
- **Nested `AGENTS.md`:** rules for one directory or product, linked from the core's project map.

For example, the core can contain:

```markdown
Read each guide before doing the work its row names.

| Guide | Read before |
| --- | --- |
| [Release guide](docs/agent-guides/releases.md) | Preparing or publishing a release |
| [API instructions](src/api/AGENTS.md) | Changing API code |
```

With Claude Code's default instruction setting, a root `CLAUDE.md` suppresses native discovery of
nested `AGENTS.md` files. Put a `CLAUDE.md` containing `@AGENTS.md` beside each nested file in that
layout. Current Claude versions can read `AGENTS.md` directly when no project `CLAUDE.md` or
`CLAUDE.local.md` takes precedence; verify the configured behavior before removing shims.
[Claude discovery and imports](https://code.claude.com/docs/en/memory#when-claude-code-reads-agentsmd).

Run `wc -c AGENTS.md` and `wc -l AGENTS.md` as a quick root-file check. For larger repositories,
add a small CI check for the chosen budget, the combined supported instruction chains, and missing
guide/shim targets. Exercise a representative nested task in each supported tool to confirm it
loads the applicable rules. A passing size check alone does not prove discovery or adherence.

## Map each tool to its file

| Tool | File it reads | How to wire it |
|---|---|---|
| Codex / Cursor / Gemini / generic | `AGENTS.md` | Read natively — no shim needed. |
| Claude Code | `CLAUDE.md` | One-line **shim**: a single `@AGENTS.md` line (Claude expands `@`-includes), so there is one source, not two. |
| Gemini CLI | `GEMINI.md` | Same shim approach — include `AGENTS.md` rather than duplicating it. |
| GitHub Copilot — code review | `AGENTS.md` | Read natively ([since 2026-06-18](https://github.blog/changelog/2026-06-18-copilot-code-review-agents-md-support-and-ui-improvements/)) — no separate file needed. |
| GitHub Copilot — coding agent / chat | `AGENTS.md` **plus** optional `.github/copilot-instructions.md` + `.github/instructions/**/*.instructions.md` | Reads `AGENTS.md`; an optional `copilot-instructions.md` adds always-on emphasis (see below). |

**Shims need no upkeep.** A *shim* (`CLAUDE.md`, `GEMINI.md`) just includes the canonical file, so it
never drifts. Everything else reads `AGENTS.md` directly.

## Copilot now reads `AGENTS.md`

GitHub Copilot used to be the exception that forced a second file — it couldn't read `AGENTS.md`, so
you maintained a `.github/copilot-instructions.md`. **That is no longer true:**

- Copilot **code review** reads `AGENTS.md` from the repo root
  ([changelog, 2026-06-18](https://github.blog/changelog/2026-06-18-copilot-code-review-agents-md-support-and-ui-improvements/)).
- Copilot **coding agent** reads `AGENTS.md` too (root + nested, nearest-wins).

So `AGENTS.md` alone now covers Copilot, and a separate `.github/copilot-instructions.md` is
**optional**, not required:

- **Most repos can drop it** and rely on `AGENTS.md` — one canonical file, no subset to keep in sync.
  Consolidating an existing `copilot-instructions.md` *into* `AGENTS.md` and deleting it is now a
  legitimate simplification. (It used to silently strip Copilot's guidance, because Copilot couldn't
  read `AGENTS.md`; that risk is gone.)
- **Keep one only for a concrete reason.** Copilot's coding agent treats `.github/copilot-instructions.md`
  as always-on context, so a short file there can pin the few rules you want weighted highest. If you
  keep it, make it a **concise subset** — short imperative rules, *not* a copy of `AGENTS.md`. Brevity
  is what makes the emphasis work; a long always-on file dilutes it. (Copilot code review's old
  ~4000-char instruction truncation was
  [removed on 2026-06-12](https://github.blog/changelog/2026-06-12-copilot-code-review-new-configurations-and-controls/),
  so length is an emphasis concern now, not a hard limit.)
- **Path-scoped rules** live in `.github/instructions/<area>.instructions.md` (with an `applyTo:`
  frontmatter glob) — guidance for only part of the tree (tests, infra, a sub-package). Useful with or
  without a `copilot-instructions.md`; `excludeAgent: "code-review"` / `"copilot-coding-agent"` targets
  one consumer.

## Keep them in sync (definition of done)

Shims (`CLAUDE.md`/`GEMINI.md` that `@`-include) never drift — that's their point. If you keep **any**
hand-maintained second file (a Copilot subset, or a path-scoped `.instructions.md`), it *can* drift,
so make sync part of *done*:

> A change that touches a command, flag, path, label, generated-file list, validation step, or
> convention updates **every** instruction file that referenced it **in the same PR** — the
> `AGENTS.md` canonical text *and* any subset / path-scoped file.

A stale instruction file is worse than none: it actively misleads every future agent and reviewer. The
surest way never to go stale is one canonical home per rule, with no hand-maintained copies.

## Recipe: wire up a repo

1. **Write `AGENTS.md`** — the small, tool-neutral core and guide index (sections above). Put detailed
   procedures in linked guides and directory-specific rules in nested instruction files.
2. **Add shims** for include-capable tools you support:
   - `CLAUDE.md` → a single line: `@AGENTS.md`; include nested shims where that layout requires them.
   - `GEMINI.md` → include `AGENTS.md` the same way.
3. **(Optional) `.github/copilot-instructions.md`** — only if you want a few always-on rules weighted
   highest for Copilot's coding agent; keep it a concise subset, not a dump of `AGENTS.md`.
4. **(Optional) `.github/instructions/<area>.instructions.md`** with `applyTo:` globs for rules that
   apply to only part of the tree (tests, infra, a sub-package).
5. **Record the sync rule** in `AGENTS.md` if you kept any hand-maintained second file.
6. **Check size and discovery** for the root and representative nested instruction chains.

## Pitfalls checklist

- ❌ Letting one always-loaded file grow beyond a tool's read limit — measure the combined chain,
  keep the core small, and route conditional detail through guides with explicit read-before triggers.
- ❌ Importing every guide with `@` and calling it on-demand — imports still load eagerly.
- ❌ Assuming a nested `AGENTS.md` is visible to Claude when a root `CLAUDE.md` takes precedence —
  add the nested shim and verify discovery in the supported runtime.
- ❌ Duplicating full `AGENTS.md` content into `CLAUDE.md`/`GEMINI.md` — use a one-line include
  instead so there is a single source.
- ❌ Keeping a `.github/copilot-instructions.md` that just **duplicates** `AGENTS.md` — now that
  Copilot reads `AGENTS.md`, a full copy is pure drift risk; drop it, or trim it to a small focused subset.
- ❌ Putting *new* canonical guidance in a kept `copilot-instructions.md` — durable rules belong in
  `AGENTS.md`; a subset only re-emphasises a few of them.
- ❌ Letting any kept `.github/copilot-instructions.md` grow into a parallel rulebook — the old
  ~4000-char review truncation is gone, but a long always-on file dilutes the emphasis that justified
  keeping it; split path-specific rules into `.instructions.md` files.
- ❌ Putting tool-specific assumptions in `AGENTS.md` — keep it neutral; quirks go in that tool's file.
- ❌ Changing a command/path/convention in `AGENTS.md` without updating any kept subset in the same
  PR — that is how the files go stale.
