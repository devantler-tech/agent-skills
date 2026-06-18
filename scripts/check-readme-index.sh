#!/usr/bin/env bash
#
# Verify the README skill index stays in lockstep with every consumer that
# parses it. `install.sh --list` parses the README index (no gh/network needed),
# so this proves the load-bearing lockstep between the curated index and every
# consumer install path. The same checks run as the `lint-scripts` CI gate, so
# running this locally before a PR catches drift before CI does.
#
# Checks, in order:
#   1. The parser extracts a non-empty list (the README tables + parser still work).
#   2. The parsed entry count equals the number of Skills-table rows — a mismatch
#      means a row's `gh skill install` command is malformed (and so silently
#      dropped from every consumer install path) or duplicated.
#   3. Every in-house skill (a directory with a SKILL.md) appears in the index, or
#      it would be silently dropped from the publish/install path.
#   4. Every in-house index entry (`devantler-tech/agent-skills <skill>`) resolves to a
#      real on-disk skill directory — the reverse of check 3. A self-pointer row
#      whose `<skill>` slug is typo'd or stale would otherwise pass count-lockstep
#      and only fail at `gh skill install` time for every consumer. (Upstream rows
#      point at other repos and can't be resolved offline; this guards the in-house
#      subset, which can — closing the index→disk half of the lockstep.)
#   5. Cross-column consistency: in every row the Install command must agree with
#      the Skill name and the Upstream link (install owner/repo == link owner/repo
#      == URL owner/repo; install slug == skill name == URL trailing segment).
#      Checks 1-4 and the scheduled upstream check each parse only one column, so a
#      row whose columns DISAGREE (e.g. a typo'd install repo/slug) ships a broken
#      install command to every consumer while passing both. Offline/deterministic.
#
# Usage: ./scripts/check-readme-index.sh   (run from anywhere; resolves the repo root)
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

# 1. Non-empty parse.
entries=$("$script_dir/install.sh" --list)
count=$(printf '%s\n' "$entries" | grep -c . || true)
echo "Parsed $count skill entries from the README index:"
printf '%s\n' "$entries" | sed 's/^/  /'
if [ "$count" -eq 0 ]; then
  echo "::error::README index parsed to zero entries — the Skills tables or the parser drifted."
  exit 1
fi

# 2. Parsed count must equal the number of Skills-table rows.
rows=$(awk '/^## Skills[[:space:]]*$/{in_skills=1; next} /^## /{in_skills=0} in_skills' README.md | grep -cE '^\| `' || true)
if [ "$count" -ne "$rows" ]; then
  echo "::error::README index drift: parsed $count install entries but the Skills tables have $rows row(s) — a row's \`gh skill install\` command is malformed or duplicated."
  exit 1
fi

# 3. Every in-house skill MUST appear in the index. (Derive the directory with
# `dirname` rather than `find -printf`, which is GNU-only — this keeps the check
# working when run locally on macOS/BSD as well as in CI.)
missing=0
while IFS= read -r skill_md; do
  dir=$(dirname "$skill_md")
  dir=${dir#./}
  [ -n "$dir" ] || continue
  if ! grep -qxF "devantler-tech/agent-skills $dir" <<<"$entries"; then
    echo "::error::in-house skill '$dir' is missing from the README index."
    missing=1
  fi
done < <(find . -mindepth 2 -maxdepth 2 -name SKILL.md)

# 4. Every in-house index entry must resolve to a real on-disk skill directory
# (index -> disk; the reverse of check 3). Upstream pointers name other repos and
# can't be resolved without network/auth, so only the `devantler-tech/agent-skills`
# self-pointers are checked here — a typo'd or stale in-house slug would otherwise
# pass count-lockstep and only fail at `gh skill install` time for every consumer.
unresolved=0
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  repo=${entry%% *}
  skill=${entry##* }
  [ "$repo" = "devantler-tech/agent-skills" ] || continue
  if [ ! -f "$skill/SKILL.md" ]; then
    echo "::error::in-house index entry '$repo $skill' does not resolve — no '$skill/SKILL.md' on disk."
    unresolved=1
  fi
done <<<"$entries"

# 5. Cross-column consistency: within every Skills-table row, the Install command
# must agree with the Skill name and the Upstream link. Checks 1-4 and the
# scheduled upstream-resolution gate (check-upstream-skills.sh) each parse only
# ONE column — the Install command (column 3) and the Upstream URL (column 2)
# respectively — so neither catches a row whose columns DISAGREE: e.g. an Upstream
# link to `owner/repo` but an `gh skill install owner/typo` command, or an install
# slug that doesn't match the named skill. Such a desync passes count-lockstep AND
# upstream resolution (which validates the correct column-2 URL) yet ships a broken
# install command to every consumer. Assert, per row: install owner/repo ==
# Upstream-link owner/repo == Upstream-URL owner/repo, and install slug ==
# Skill name == Upstream-URL trailing path segment. String comparison only (no
# network), so it gates PRs alongside checks 1-4.
inconsistent=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  # Strip the markdown code-span backticks up front so the field patterns below
  # never need a literal backtick (which shellcheck flags as SC2016); they carry
  # no meaning for the extraction.
  row=$(printf '%s' "$row" | tr -d '`')
  IFS='|' read -r _ c_skill c_up c_inst _ <<<"$row"
  skill_name=$(printf '%s' "$c_skill" | tr -d ' ')
  link_repo=$(printf '%s' "$c_up" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
  url=$(printf '%s' "$c_up" | sed -n 's#.*](\(https://github\.com/[^)]*\)).*#\1#p')
  url_repo=$(printf '%s' "$url" | sed -n 's#https://github\.com/\([^/][^/]*/[^/][^/]*\)/tree/.*#\1#p')
  url_tail=${url##*/}
  inst=$(printf '%s' "$c_inst" | sed -n 's/.*gh skill install \(.*\)/\1/p')
  # Intentional word-splitting: `gh skill install <repo> <skill> [flags]`.
  # shellcheck disable=SC2086
  set -- $inst
  inst_repo=${1:-}
  inst_skill=${2:-}
  if [ -z "$skill_name" ] || [ -z "$link_repo" ] || [ -z "$url_repo" ] || [ -z "$inst_repo" ] || [ -z "$inst_skill" ]; then
    echo "::error::README row could not be parsed into Skill/Upstream/Install cells: $row"
    inconsistent=1
    continue
  fi
  if [ "$link_repo" != "$url_repo" ]; then
    echo "::error::Upstream column mismatch for '$skill_name': link text \`$link_repo\` != URL repo '$url_repo'."
    inconsistent=1
  fi
  if [ "$inst_repo" != "$link_repo" ]; then
    echo "::error::Install/Upstream repo mismatch for '$skill_name': \`gh skill install $inst_repo …\` != Upstream \`$link_repo\` — a consumer would install from the wrong repo."
    inconsistent=1
  fi
  if [ "$inst_skill" != "$skill_name" ]; then
    echo "::error::Install slug mismatch: row names skill '$skill_name' but installs '$inst_skill'."
    inconsistent=1
  fi
  if [ "$url_tail" != "$skill_name" ]; then
    echo "::error::Upstream URL for '$skill_name' points at trailing segment '$url_tail' — it must equal the skill name."
    inconsistent=1
  fi
done < <(awk '/^## Skills[[:space:]]*$/{in_skills=1; next} /^## /{in_skills=0} in_skills' README.md | grep -E '^\| `')

[ "$missing" -eq 0 ] && [ "$unresolved" -eq 0 ] && [ "$inconsistent" -eq 0 ]
