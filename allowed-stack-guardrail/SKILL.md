---
name: allowed-stack-guardrail
description: >-
  Before agreeing to build anything for a non-technical user, check the need
  against the consuming deployment's "## Stack map" section: in-stack needs
  proceed; out-of-stack or unmatched needs get a friendly, jargon-free decline
  plus an offer to file a well-formed issue on the block's owning repo (or the
  map's default intake repo). Fails closed when the Stack map is absent or
  malformed — nothing is built best-effort outside the map. Use in a
  vibe-coding setting whenever a build request is about to be accepted.
license: Apache-2.0
---

# Allowed-stack guardrail

A deployment that lets people build conversationally still has a hard boundary: only the building
blocks the deployment actually operates are buildable. This skill is that boundary check. It runs
**before you agree to build anything**, and its verdict is binding: there is no best-effort path
around it. Declines are delivered in the register of the `jargon-free-voice` skill.

## The Stack map contract

The allowed stack is **deployment-owned configuration** — it never ships inside this skill. The
consuming deployment's canonical instructions file (`AGENTS.md`) defines it in a section titled
exactly **`## Stack map`**, containing:

- **A table** whose rows each carry three required fields:
  - **Building block** — the block's plain-language name;
  - **Good for** — the needs it serves, written in the user's vocabulary (this is the matching
    surface);
  - **Owning repo** — `owner/repo`, where a suggested issue for that block is filed.
- **A default intake repo** (required, once per map) — the catch-all `owner/repo` that receives
  the suggested issue for any need matching *no* row.

Read the section fresh each session; the deployment can change it at any time.

## The check

1. **Match conservatively.** Compare the user's stated need (outcome / audience / workflow — as
   elicited by the `needs-stack-mapping` skill) against each row's *Good for* purposes. Matching
   is semantic but **conservative**: only a confident match counts. Anything you cannot
   confidently place falls through to the unmatched path — never stretch a row to fit.
2. **In-stack → proceed.** A confidently matched need goes forward to be built with the matched
   block(s), the deployment's way.
3. **Out-of-stack or unmatched → decline and redirect.** In plain language: say what you can't
   build, in one friendly sentence, without technical vocabulary; then offer to put it on the
   deployment's wish list. With the user's consent, prepare a well-formed issue — the need as the
   user stated it, the outcome it serves, and why it fell outside the current building blocks.
   Routing follows the confidence of the match: a need that **confidently concerns a mapped
   block** yet is still out-of-stack (say, a capability that block doesn't have) is filed on that
   block's **owning repo**; **every non-confident or unmatched need goes to the default intake
   repo** — never to a merely "nearest" block, which would land out-of-stack work on an unrelated
   owner. The user consents to "adding it to the wish list", never to "filing an issue on a repo"
   — the redirect itself stays jargon-free.

## Fail closed

When the `## Stack map` section is **absent**, or **malformed** — no table, any row missing a
required field, or **no default intake repo** (it is required once per map; its absence makes the
whole map malformed even when every row parses) — treat **every** need as out-of-stack:

- Decline plainly: explain that your catalogue of what can be built here isn't available right
  now, so you can't safely agree to build anything yet.
- If a default intake repo *is* parseable, still offer the wish-list redirect there; otherwise,
  direct the user to whoever operates the deployment.
- Never infer, remember, or improvise an allowed stack, and never build "just this once" while
  the map is unavailable.

## Boundaries

- The guardrail gates *building*; it never gates *conversation*. Understanding the need, exploring
  what the user wants, and mapping it are always allowed — only the commitment to build is gated.
- A split need (partly in-stack, partly out) proceeds only with its in-stack part; the out-of-stack
  part gets the decline-and-redirect path explicitly, so nothing silently drops.
- The decline is a full answer, not an apology: what can't happen, why in one plain sentence
  ("that needs a kind of building block this setup doesn't have yet"), and what happens next
  (the wish list, and what the user can expect from it).
