#!/usr/bin/env bash
#
# Install every skill listed in the README index for one or more agents at user
# scope, so they are available everywhere (e.g. ~/.copilot/skills and
# ~/.claude/skills). The skill list is parsed straight out of ../README.md, so
# this script never drifts from the curated index.
#
# Usage:
#   ./scripts/install.sh                       # github-copilot + claude-code (default)
#   ./scripts/install.sh claude-code           # a single agent
#   ./scripts/install.sh github-copilot cursor # any gh skill agents
#   AGENTS="github-copilot claude-code" ./scripts/install.sh
#
# Requires gh >= 2.90.0 (with `gh skill`). See `gh skill install --help`.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readme="$script_dir/../README.md"

if [ ! -f "$readme" ]; then
  echo "error: could not find README index at $readme" >&2
  exit 1
fi

if ! gh skill --help >/dev/null 2>&1; then
  echo "error: 'gh skill' is unavailable. Install gh >= 2.90.0 first." >&2
  exit 1
fi

# Agents: positional args win, else $AGENTS, else both Copilot and Claude Code.
if [ "$#" -gt 0 ]; then
  agents=("$@")
else
  # shellcheck disable=SC2206
  agents=(${AGENTS:-github-copilot claude-code})
fi

# Extract "<owner/repo> <skill>" from every `gh skill install <owner/repo> <skill>`
# occurrence in the README, ignoring any trailing flags, and de-duplicate.
entries=()
while IFS= read -r entry; do
  [ -n "$entry" ] && entries+=("$entry")
done < <(
  grep -oE 'gh skill install [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+ [A-Za-z0-9_.-]+' "$readme" \
    | awk '{print $4, $5}' \
    | sort -u
)

if [ ${#entries[@]} -eq 0 ]; then
  echo "error: no skills found in $readme" >&2
  exit 1
fi

echo "Installing ${#entries[@]} skill(s) for agent(s): ${agents[*]} (scope=user)"
echo

fail=0
for agent in "${agents[@]}"; do
  for entry in "${entries[@]}"; do
    repo=${entry%% *}
    skill=${entry##* }
    if gh skill install "$repo" "$skill" \
        --agent "$agent" --scope user --force --allow-hidden-dirs >/dev/null 2>&1; then
      echo "  ok   [$agent] $repo $skill"
    else
      echo "  FAIL [$agent] $repo $skill" >&2
      fail=$((fail + 1))
    fi
  done
done

echo
if [ "$fail" -ne 0 ]; then
  echo "Done with $fail failure(s)." >&2
  exit 1
fi
echo "Done — all skills installed for: ${agents[*]}"
