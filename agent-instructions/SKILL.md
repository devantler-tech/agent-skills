---
name: agent-instructions
description: >-
  Architect a repository's AI-agent instruction files so one canonical source
  drives every tool without drift — AGENTS.md as the cross-tool source of truth,
  thin per-tool shims (CLAUDE.md, GEMINI.md) that include it, and a concise
  review-focused .github/copilot-instructions.md subset. Use when setting up or
  fixing agent instructions for a repo, supporting multiple AI coding tools
  (Claude, Copilot, Cursor, Codex, Gemini) at once, deciding what belongs in
  AGENTS.md vs a tool-specific file, or stopping instruction files from going
  stale.
license: Apache-2.0
---

# Agent Instructions

Most AI coding tools read project guidance from a file in the repo — but each looks in a
*different* place (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, …). Copy the same
guidance into each one and the copies **drift**: a command changes in one file and the others keep
telling agents the old way. The fix is one **canonical** source plus thin tool-specific **shims**
(which include the canonical file) and the occasional deliberate **subset** (for a tool that can't
read the canonical file). Keep all durable guidance in the canonical file; keep only genuine
tool-specific quirks in a tool's own file.

## The canonical file: `AGENTS.md`

`AGENTS.md` is the emerging cross-tool standard — a plain-Markdown file at the repo root, read
natively by a growing set of agents and editors (e.g. Codex and Cursor). Make it the **single
source of truth** for everything durable and tool-neutral:

- **What the project is** — one-paragraph purpose, the stack, where the important code lives.
- **How to build, test, validate, and run** — the exact commands an agent should use (and which
  one gates a PR). Be specific; agents run these verbatim.
- **Conventions** — code style, naming, commit/PR format, branch model, "definition of done".
- **Do / don't** — guardrails (never hand-edit generated files, never push to `main`, secret
  handling) and the project's non-obvious gotchas.
- **Pointers** — links to deeper docs rather than inlining them.

Write it **tool-neutral**: no "when you are Claude…" assumptions. Anything true only for one tool
goes in that tool's file, not here. Keep it readable and scoped — an agent re-reads it every turn,
so length is a cost.

## Map each tool to its file

| Tool | File it reads | How to wire it |
|---|---|---|
| Codex / Cursor / generic | `AGENTS.md` | Read natively — no shim needed. |
| Claude Code | `CLAUDE.md` | One-line **shim**: a single `@AGENTS.md` line (Claude expands `@`-includes), so there is one source, not two. |
| Gemini CLI | `GEMINI.md` | Same shim approach — include `AGENTS.md` rather than duplicating it. |
| GitHub Copilot — coding agent / chat | `.github/copilot-instructions.md` (repo-wide) + `.github/instructions/**/*.instructions.md` (path-scoped via `applyTo:` globs) | Concise **subset** (see below). |
| GitHub Copilot — code review | `.github/copilot-instructions.md` + `.instructions.md` **only** | Same subset — and it does **not** read `AGENTS.md`. |

**Shim vs. subset.** A *shim* (`CLAUDE.md`, `GEMINI.md`) just includes the canonical file, so it
never drifts and needs no upkeep. A *subset* (`.github/copilot-instructions.md`) is deliberately
*different* content because the consuming tool cannot read `AGENTS.md` — so it carries its own
maintenance burden (see *Keep them in sync*).

## The Copilot gotcha

GitHub Copilot is the case that breaks the "one canonical file" ideal, and it has **two distinct
consumers** with the same files but different limits:

- Copilot **does not read `AGENTS.md`** — neither the coding agent nor code review. It reads
  `.github/copilot-instructions.md` (repo-wide) and `.github/instructions/**/*.instructions.md`
  (path-specific).
- Copilot **code review** in particular **truncates** the instructions past roughly **4000
  characters** — guidance beyond that point is silently ignored during review.

So `.github/copilot-instructions.md` must be a **concise, review-focused subset** — short
imperative rules a reviewer applies (the bugs and conventions you most want caught), **not** a copy
of `AGENTS.md`. Keep it well under the limit. Use path-specific `.instructions.md` files (with an
`applyTo:` frontmatter glob) for rules that only apply to part of the tree, so each stays small.

> **Anti-pattern:** consolidating `copilot-instructions.md` *into* `AGENTS.md` and deleting it to
> "remove duplication". Because Copilot can't read `AGENTS.md`, this silently removes all per-repo
> guidance from Copilot review and the coding agent. The duplication is the price of Copilot not
> supporting the standard — manage it (below), don't eliminate it.

## Keep them in sync (definition of done)

Shims (`CLAUDE.md`/`GEMINI.md` that `@`-include) never drift — that's their point. The Copilot
**subset** does drift, because it is hand-maintained separate content. So make it part of *done*:

> A change that touches a command, flag, path, label, generated-file list, validation step, or
> convention updates **every** instruction file that referenced it **in the same PR** — the
> `AGENTS.md` canonical text *and* the `copilot-instructions.md` / `.instructions.md` subset.

Never let the canonical file and the Copilot subset describe the project differently. A stale
instruction file is worse than none: it actively misleads every future agent and reviewer.

## Recipe: wire up a repo

1. **Write `AGENTS.md`** — the canonical, tool-neutral guidance (sections above). This is the bulk
   of the work; everything else points back to it.
2. **Add shims** for include-capable tools you support:
   - `CLAUDE.md` → a single line: `@AGENTS.md`
   - `GEMINI.md` → include `AGENTS.md` the same way.
   Codex and Cursor need nothing — they read `AGENTS.md` directly.
3. **Add `.github/copilot-instructions.md`** — a concise (≤ ~4000 char) review-focused subset of the
   most important, checkable rules. Short imperative bullets, not prose; not a dump of `AGENTS.md`.
4. **(Optional) Add path-specific `.github/instructions/<area>.instructions.md`** with `applyTo:`
   globs for rules that apply to only part of the tree (e.g. tests, infra, a sub-package).
5. **Record the sync rule** in `AGENTS.md` itself so future changes keep the subset current.

## Pitfalls checklist

- ❌ Duplicating full `AGENTS.md` content into `CLAUDE.md`/`GEMINI.md` — use a one-line include
  instead so there is a single source.
- ❌ Treating `copilot-instructions.md` as a copy of `AGENTS.md` — it is a focused subset; a copy
  drifts and (for review) gets truncated.
- ❌ Letting `.github/copilot-instructions.md` grow past ~4000 chars — Copilot review silently drops
  the overflow; split path-specific rules into `.instructions.md` files.
- ❌ Putting tool-specific assumptions in `AGENTS.md` — keep it neutral; quirks go in that tool's
  file.
- ❌ Changing a command/path/convention in `AGENTS.md` without updating the Copilot subset in the
  same PR — that is how the files go stale.
