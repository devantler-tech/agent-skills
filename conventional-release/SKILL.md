---
name: conventional-release
description: >-
  Ship changes through a squash-merge + Conventional Commits release pipeline
  where the PR title becomes the release note and the commit type drives the
  next semantic version. Use when writing a PR title or commit message that
  feeds an automated release, choosing the version bump for a change, setting up
  or reasoning about semantic-release / release-please / github-tag-action /
  Changesets, or avoiding a title that corrupts the changelog.
license: Apache-2.0
---

# Conventional Release

A widely-used release pattern: every PR is **squash-merged**, its **title is a
[Conventional Commit](https://www.conventionalcommits.org/)**, and an automated tool on the default
branch reads the commit type to calculate the next [SemVer](https://semver.org/) tag, cut a release,
and generate the changelog. No human writes a version number or a changelog entry by hand — the merge
title *is* the release note, and the type *is* the bump.

Use this skill whenever you open or merge a PR into a repository that releases this way, or when you
need to decide which version a change should produce.

## How to tell a repo uses this pattern

Look for any one of:

- A release tool wired to run on push to the default branch:
  [`semantic-release`](https://github.com/semantic-release/semantic-release),
  [`release-please`](https://github.com/googleapis/release-please),
  [`mathieudutour/github-tag-action`](https://github.com/mathieudutour/github-tag-action), or
  [Changesets](https://github.com/changesets/changesets).
- Branch protection that **only allows squash merging** (so the PR title is the sole commit message
  that reaches the default branch).
- A `CHANGELOG.md` that is generated, or release notes grouped by `Features` / `Bug Fixes`.
- A `commitlint`/`commitizen` config, or CI that lints the PR title against the Conventional Commits
  spec.

If the repo squash-merges but releases manually, the title still matters for history and review — keep
writing Conventional Commit titles, but the version step is the maintainer's.

## The non-negotiable: the squash title is the only message that survives

With squash merging, GitHub collapses every commit on the branch into **one** commit on the default
branch, and that commit's message defaults to the **PR title**. The release tool reads *that* message.
So:

- **The individual commits on your branch do not drive the release** — only the final squash message
  does. Tidy WIP commits are fine; the PR title is what counts.
- **The PR title MUST be a single valid Conventional Commit line.** A title like `[fix] thing` or
  `WIP: thing` or `Update README` either yields no release, the wrong bump, or a corrupted changelog
  entry.
- **Never put a bracketed prefix, ticket id, or label in the title** (`[infra]`, `JIRA-123:`,
  `(wip)`). Attribution belongs in **labels** and the **branch name**, never the title — a prefix
  before the type breaks the parser and pollutes the release notes.

## Anatomy of the title

```text
<type>(<optional scope>): <imperative summary>
```

- `<type>` — one of the types below; it selects the version bump.
- `(<scope>)` — optional, a noun for the area touched: `feat(api):`, `fix(parser):`. Keep it short and
  consistent with the repo's existing scopes.
- `<summary>` — imperative mood (`add`, not `added`/`adds`), lower-case start, no trailing period,
  kept under ~72 chars. Describe the change from the *user's* perspective, because it becomes their
  changelog line.

## Type → version bump

The default mapping (Angular/Conventional Commits preset, used by all four tools above):

| Type | Meaning | Bump |
|------|---------|------|
| `feat` | a new user-facing capability | **minor** (`x.Y.0`) |
| `fix` | a bug fix | **patch** (`x.y.Z`) |
| `perf` | a performance improvement | patch (often) |
| `docs` | documentation only | **none** by default |
| `refactor` | behaviour-preserving code change | none by default |
| `test` | adding or fixing tests | none by default |
| `build` / `ci` | build system or pipeline | none by default |
| `chore` | maintenance, deps, tooling | none by default |
| `style` | formatting only | none by default |
| `revert` | revert a prior change | patch (often) |

A push that contains **only** no-bump types yields **no release** — a deliberate, green "nothing to
ship" outcome, not a failure. Do not invent a `feat:` to force a tag.

### Breaking changes → major

A breaking change is a **major** bump (`X.0.0`), signalled either way:

- a `!` after the type/scope: `feat(api)!: drop the v1 endpoint`, **or**
- a `BREAKING CHANGE:` footer in the body:

  ```text
  feat(api): replace the auth header

  BREAKING CHANGE: clients must send `Authorization: Bearer` instead of `X-Token`.
  ```

Pre-1.0 (`0.y.z`) repos may map breaking changes to a **minor** bump instead — check the repo's release
config (`semantic-release` and `release-please` honour SemVer's 0.x rules). When unsure, state the
breaking nature explicitly and let the tool decide the number.

## Choosing the bump deliberately

Pick the type from the **effect on the consumer**, not the size of the diff:

- A one-line change that alters output a user depends on is a `fix` (or a breaking `feat!`), not a
  `chore`.
- A 500-line internal refactor that changes no behaviour is `refactor` — **none** — even though it is
  large.
- Bumping a dependency that changes runtime behaviour the user sees is a `fix`/`feat`; a dev-only or
  pinned-tooling bump is `chore`.
- Splitting unrelated changes across PRs lets each get its correct type and its own release note —
  prefer that over one mixed PR with a vague title.

## Writing the body

The body is optional for simple changes and flows into the release notes under the title. Use it to:

- explain **why**, not just what (reviewers and the changelog reader both benefit);
- add a `BREAKING CHANGE:` footer for majors (see above);
- reference issues with `Fixes #123` / `Closes #123` so the merge closes them;
- credit co-authors with `Co-authored-by:` trailers.

Keep wrap at ~72 columns; the first body line must be blank (separating it from the title).

## Pitfalls

- **Title fixed *after* approval but *before* merge.** Reviewers may approve a draft title; always
  re-read the final title at merge time — it is what ships. Many UIs pre-fill the squash message from
  the first commit, **not** the PR title; confirm the squash message equals the intended title before
  confirming the merge.
- **Multiple logical changes, one PR.** The single title can only carry one type. Either split the PR
  or pick the highest-impact type and enumerate the rest in the body.
- **No-bump type when you meant to release.** `chore: add retry to the client` ships nothing; if users
  get the retry, it is a `fix`/`feat`.
- **Reverting a release.** Use `revert:` (or the tool's revert convention) so the changelog records the
  rollback rather than a silent gap.
- **Scope sprawl.** Inconsistent scopes (`api`, `API`, `apis`) fragment the changelog; reuse the scopes
  already present in the history.

## Verify before merging

1. The PR title parses as `<type>(<scope>)?: <summary>` with a real type — no bracket/prefix, no
   trailing period, imperative mood.
2. The chosen type produces the **intended** bump (or an intended *no* release).
3. Any breaking change carries `!` or a `BREAKING CHANGE:` footer.
4. The squash-merge message the platform will use **equals** that title (re-check at the merge dialog).
5. If the repo lints commits/titles in CI, that check is green — fix the title, never bypass the lint.

## Related skills

- `git-commit` — compose a Conventional Commit *message* from a working-tree diff (the local-author
  side of the same convention).
- `ways-of-working` — the broader issue → plan → implement → test → review flow these releases sit in.
