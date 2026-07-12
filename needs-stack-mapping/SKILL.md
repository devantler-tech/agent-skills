---
name: needs-stack-mapping
description: >-
  Translate a non-technical person's plain-language product needs (an outcome,
  an audience, a workflow) into the deployment's technical building blocks
  behind the scenes, keeping the conversation entirely in the user's
  vocabulary. Reads the consuming deployment's "## Stack map" section to learn
  what each building block is good for, selects and applies the deployment's
  conventions without discussing them, and hands the boundary decision to the
  allowed-stack-guardrail skill. Use when assisting a vibe coder — someone
  building a product conversationally with no technical prerequisite.
license: Apache-2.0
---

# Needs → stack mapping

The person you are assisting describes what they want in the vocabulary of their product — an
outcome ("people should be able to book a session"), an audience ("my newsletter readers"), a
workflow ("when someone pays, send them the files"). Your job is to translate that into the
deployment's technical building blocks *behind the scenes*: the mapping happens in your reasoning,
never in the conversation. Conducted in the register of the `jargon-free-voice` skill.

## Where the building blocks come from

The allowed building blocks are **deployment-owned configuration, not part of this skill**: the
consuming deployment's canonical instructions file (`AGENTS.md`, reaching you through your tool's
native mechanism) carries a **`## Stack map`** section — a table whose rows each name a
**Building block** (its plain-language name), what it is **Good for** (the needs it serves, in the
user's vocabulary), and its **Owning repo**. That table is your entire menu:

- **Match needs against the *Good for* column.** It is written as a matching surface — compare the
  user's stated outcome/audience/workflow against each row's purposes semantically, in plain
  language.
- **Never reach outside the map.** Whether an unmatched need may be built at all is not your call —
  that boundary (including the conservative-match rule and the fail-closed behaviour when the map
  is missing or malformed) belongs to the `allowed-stack-guardrail` skill, which runs before
  anything is built. This skill only ever *selects from* the map.

## The procedure

1. **Elicit needs, not technologies.** Draw out the outcome, the audience, and the workflow with
   questions the user can answer without technical vocabulary. If the user *does* name a
   technology, translate it back to the need behind it ("what should that let your visitors do?")
   rather than adopting it as a requirement.
2. **Map behind the scenes.** Select the building block(s) whose *Good for* purposes cover the
   need. Prefer the smallest set of blocks that serves the whole workflow; note (internally) which
   rows you matched so the guardrail check and any later redirect are grounded in the same rows.
3. **Confirm behaviour, not design.** Play the plan back as product behaviour ("here's what your
   visitors will experience …") and get a plain-language yes before building. The user approves
   *described behaviour*, never an architecture.
4. **Apply conventions silently.** Build the deployment's way — its scaffolds, its quality gates,
   its delivery process — without discussing any of it. Conventions are *applied*, not *taught*;
   they surface in conversation only if the user asks how things work (glossary indirection).
5. **Report outcomes.** Progress and completion are reported as product outcomes in the user's
   vocabulary, per the voice skill.

## Boundaries

- The conversation's vocabulary is the user's; the mapping's vocabulary is the map's. Never let
  the two mix in a reply.
- A need that spans mapped and unmapped parts is split: proceed with the mapped part only after
  the guardrail has dispositioned the unmapped part (decline + suggested issue), and say plainly
  which part of the outcome will arrive now and which is on the wish list.
- The map can change between conversations (the deployment owns it) — read it fresh each session;
  never rely on a remembered menu.
