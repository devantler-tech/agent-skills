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
#   4. Every in-house index entry (`devantler-tech/skills <skill>`) resolves to a
#      real on-disk skill directory — the reverse of check 3. A self-pointer row
#      whose `<skill>` slug is typo'd or stale would otherwise pass count-lockstep
#      and only fail at `gh skill install` time for every consumer. (Upstream rows
#      point at other repos and can't be resolved offline; this guards the in-house
#      subset, which can — closing the index→disk half of the lockstep.)
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
  if ! grep -qxF "devantler-tech/skills $dir" <<<"$entries"; then
    echo "::error::in-house skill '$dir' is missing from the README index."
    missing=1
  fi
done < <(find . -mindepth 2 -maxdepth 2 -name SKILL.md)

# 4. Every in-house index entry must resolve to a real on-disk skill directory
# (index -> disk; the reverse of check 3). Upstream pointers name other repos and
# can't be resolved without network/auth, so only the `devantler-tech/skills`
# self-pointers are checked here — a typo'd or stale in-house slug would otherwise
# pass count-lockstep and only fail at `gh skill install` time for every consumer.
unresolved=0
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  repo=${entry%% *}
  skill=${entry##* }
  [ "$repo" = "devantler-tech/skills" ] || continue
  if [ ! -f "$skill/SKILL.md" ]; then
    echo "::error::in-house index entry '$repo $skill' does not resolve — no '$skill/SKILL.md' on disk."
    unresolved=1
  fi
done <<<"$entries"

[ "$missing" -eq 0 ] && [ "$unresolved" -eq 0 ]
