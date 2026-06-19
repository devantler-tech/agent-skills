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
(which include the canonical file). Keep all durable guidance in the canonical file; keep only
genuine tool-specific quirks in a tool's own file.

The good news: `AGENTS.md` is now read by nearly every major tool — **including GitHub Copilot** — so
the "one canonical file" ideal is finally achievable without a per-tool copy.

## The canonical file: `AGENTS.md`

`AGENTS.md` is the cross-tool standard — a plain-Markdown file at the repo root, read natively by a
growing set of agents and editors (Codex, Cursor, Gemini CLI, and GitHub Copilot). Make it the
**single source of truth** for everything durable and tool-neutral:

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

**Nested `AGENTS.md`.** In a monorepo or a large sub-package, drop an `AGENTS.md` in the subdirectory:
tools that support the standard read the nearest one and let it **take precedence** over the root on
conflicts. Reach for this before a path-scoped tool-specific file when the guidance is itself
tool-neutral.

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
  keep it, make it a **concise subset** — short imperative rules, *not* a copy of `AGENTS.md`. Copilot
  code review also truncates long instruction files (~first 4000 chars), so brevity matters.
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
surest way never to go stale is a single `AGENTS.md` with no hand-maintained copies.

## Recipe: wire up a repo

1. **Write `AGENTS.md`** — the canonical, tool-neutral guidance (sections above). This is the bulk
   of the work; everything else points back to it. Codex, Cursor, Gemini, and Copilot read it directly.
2. **Add shims** for include-capable tools you support:
   - `CLAUDE.md` → a single line: `@AGENTS.md`
   - `GEMINI.md` → include `AGENTS.md` the same way.
3. **(Optional) `.github/copilot-instructions.md`** — only if you want a few always-on rules weighted
   highest for Copilot's coding agent; keep it a concise (≤ ~4000 char) subset, not a dump of `AGENTS.md`.
4. **(Optional) `.github/instructions/<area>.instructions.md`** with `applyTo:` globs for rules that
   apply to only part of the tree (tests, infra, a sub-package).
5. **Record the sync rule** in `AGENTS.md` if you kept any hand-maintained second file.

## Pitfalls checklist

- ❌ Duplicating full `AGENTS.md` content into `CLAUDE.md`/`GEMINI.md` — use a one-line include
  instead so there is a single source.
- ❌ Keeping a `.github/copilot-instructions.md` that just **duplicates** `AGENTS.md` — now that
  Copilot reads `AGENTS.md`, a full copy is pure drift risk; drop it, or trim it to a small focused subset.
- ❌ Putting *new* canonical guidance in a kept `copilot-instructions.md` — durable rules belong in
  `AGENTS.md`; a subset only re-emphasises a few of them.
- ❌ Letting any kept `.github/copilot-instructions.md` grow past ~4000 chars — Copilot review silently
  drops the overflow; split path-specific rules into `.instructions.md` files.
- ❌ Putting tool-specific assumptions in `AGENTS.md` — keep it neutral; quirks go in that tool's file.
- ❌ Changing a command/path/convention in `AGENTS.md` without updating any kept subset in the same
  PR — that is how the files go stale.
