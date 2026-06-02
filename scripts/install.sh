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
#   ./scripts/install.sh --list                # print the parsed index and exit (no gh needed)
#
# Requires gh >= 2.90.0 (with `gh skill`). See `gh skill install --help`.
# (`--list` only parses the README, so it needs neither gh nor network access.)
set -euo pipefail

# --list/-l: parse the README index and print the "<owner/repo> <skill>" entries,
# then exit — without requiring gh, network, or auth. This lets CI smoke-test the
# README parser (the load-bearing lockstep between the index and every consumer).
list_only=false
if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
  list_only=true
  shift
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readme="$script_dir/../README.md"

if [ ! -f "$readme" ]; then
  echo "error: could not find README index at $readme" >&2
  exit 1
fi

# Extract "<owner/repo> <skill>" from every `gh skill install <owner/repo> <skill>`
# occurrence in the curated index, ignoring any trailing flags, and de-duplicate.
# Scope the scan to the "## Skills" section (up to the next "## " heading) so
# example commands elsewhere in the README — e.g. under "## Installing" — are
# never picked up as installable entries. Parse before the gh check so `--list`
# can validate the index on its own.
entries=()
while IFS= read -r entry; do
  [ -n "$entry" ] && entries+=("$entry")
done < <(
  awk '/^## Skills[[:space:]]*$/{in_skills=1; next} /^## /{in_skills=0} in_skills' "$readme" \
    | grep -oE 'gh skill install [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+ [A-Za-z0-9_.-]+' \
    | awk '{print $4, $5}' \
    | sort -u
)

if [ ${#entries[@]} -eq 0 ]; then
  echo "error: no skills found in $readme" >&2
  exit 1
fi

if [ "$list_only" = true ]; then
  printf '%s\n' "${entries[@]}"
  exit 0
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

echo "Installing ${#entries[@]} skill(s) for agent(s): ${agents[*]} (scope=user)"
echo

fail=0
for agent in "${agents[@]}"; do
  for entry in "${entries[@]}"; do
    repo=${entry%% *}
    skill=${entry##* }
    # Capture output so the success path stays quiet but a failure can surface
    # the actual error (auth, network, missing skill, …) instead of swallowing it.
    if out=$(gh skill install "$repo" "$skill" \
        --agent "$agent" --scope user --force --allow-hidden-dirs 2>&1); then
      echo "  ok   [$agent] $repo $skill"
    else
      echo "  FAIL [$agent] $repo $skill" >&2
      printf '%s\n' "$out" | sed 's/^/         /' >&2
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
