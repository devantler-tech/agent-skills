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
#   ./scripts/install.sh --help                # show usage without reading the index
#
# Requires jq, iconv and gh >= 2.90.0 (with `gh skill`). See `gh skill install --help`.
# (`--list` only parses the README, so it needs neither gh nor network access.)
set -euo pipefail

# Print command modes, agent selection and prerequisites to standard output.
# This standalone help path reads no catalogue and performs no forge requests.
usage() {
  cat <<'EOF'
Usage: install.sh [AGENT ...]
       install.sh --list | -l
       install.sh --help | -h

Install every README-listed skill at user scope for the selected agents.
Catalogue sources are on github.com; installation overrides GH_HOST accordingly.
Positional agents override the whitespace-separated AGENTS environment variable.
Unset or empty AGENTS defaults to: github-copilot claude-code.

--list, -l  Print the sorted skill index without installing (no gh needed).
--help, -h  Show this help without reading the index or calling gh.
Help and listing are standalone modes; do not combine them with agent arguments.

Installation requires jq, iconv and gh >= 2.90.0 with gh skill support. Every catalogue
source is resolved to an immutable commit before any skill is installed.
Agent names are passed
to gh skill install; run gh skill install --help for supported agents.
EOF
}

# Report the supplied argument error and usage on standard error, then exit 2.
# Argument rejection completes before any catalogue resolution or installation.
usage_error() {
  printf 'error: %s\n' "$1" >&2
  usage >&2
  exit 2
}

# Inspect the whole invocation before gh or any installation can run.
list_only=false
case "${1:-}" in
  --help|-h)
    [ "$#" -eq 1 ] || usage_error 'help must be used alone'
    usage
    exit 0
    ;;
  --list|-l)
    [ "$#" -eq 1 ] || usage_error 'listing must be used alone'
    list_only=true
    ;;
esac

if [ "$list_only" = false ]; then
  agents=()
  if [ "$#" -gt 0 ]; then
    agents=("$@")
  else
    # read splits on whitespace without pathname expansion, including each line
    # of a multiline value. No catalogue of agent names is duplicated here.
    while IFS=$' \t' read -r -a line_agents; do
      if [ "${#line_agents[@]}" -gt 0 ]; then
        agents+=("${line_agents[@]}")
      fi
    done <<< "${AGENTS:-github-copilot claude-code}"
  fi
  [ "${#agents[@]}" -gt 0 ] || usage_error 'select at least one agent'
  for agent in "${agents[@]}"; do
    case "$agent" in
      ''|-*|*[[:space:]]*) usage_error "invalid agent argument: '$agent'" ;;
    esac
  done
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readme="$script_dir/../README.md"

if [ ! -f "$readme" ]; then
  echo "error: could not find README index at $readme" >&2
  exit 1
fi

# Validate the complete table before listing or invoking gh. A failed parser
# must not be hidden in process substitution or leave a partial install list.
if [ "$list_only" = true ]; then
  catalogue=$(bash "$script_dir/readme-index.sh")
else
  catalogue=$(bash "$script_dir/readme-index.sh" --targets)
fi
entries=()
while IFS= read -r entry; do
  [ -n "$entry" ] && entries+=("$entry")
done <<<"$catalogue"

if [ ${#entries[@]} -eq 0 ]; then
  echo "error: no skills found in $readme" >&2
  exit 1
fi

if [ "$list_only" = true ]; then
  printf '%s\n' "${entries[@]}"
  exit 0
fi

# The curated index names github.com repositories, independent of the user's
# default GitHub host. Keep both the preflight and every install on that host.
export GH_HOST=github.com

if ! gh skill --help >/dev/null 2>&1; then
  echo "error: 'gh skill' is unavailable. Install gh >= 2.90.0 first." >&2
  exit 1
fi

for tool in jq iconv; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: installation requires $tool to verify source commits." >&2
    exit 1
  fi
done

# Keep the original API bytes private until their encoding and identity have
# been verified. Bash strings discard NULs and jq can repair malformed UTF-8.
stage_root=$(mktemp -d "${TMPDIR:-/tmp}/skill-install-preflight.XXXXXX")
trap 'rm -rf "$stage_root"' EXIT
response="$stage_root/commit.json"

# Validate one raw UTF-8 JSON file as a single object without repeated paths.
# Return success without output only for an unambiguous object; invalid or
# concatenated responses return nonzero before they can establish provenance.
unambiguous_object() {
  LC_ALL=C tr -d '\000' < "$1" > "$stage_root/no-nul" &&
    cmp -s "$1" "$stage_root/no-nul" &&
    iconv -f UTF-8 -t UTF-16BE < "$1" > "$stage_root/utf16" &&
    iconv -f UTF-16BE -t UTF-8 < "$stage_root/utf16" > "$stage_root/utf8" &&
    cmp -s "$1" "$stage_root/utf8" &&
    jq -es 'length==1 and (.[0]|type=="object")' "$1" >/dev/null &&
    jq --stream -es '
      reduce .[] as $event ({complete:{}, valid:true};
        if ($event|length)==2 then
          .complete as $complete | $event[0] as $path |
          .valid = (.valid and (any(range(0;($path|length)+1);
            $complete[($path[0:.]|tojson)]==true)|not)) |
          .complete[($path|tojson)] = true
        else .complete[($event[0][0:-1]|tojson)] = true end) | .valid
    ' "$1" >/dev/null
}
pins=()
sources=()
source_pins=()
for entry in "${entries[@]}"; do
  read -r repo ref _ skill <<<"$entry"
  source="$(printf '%s' "$repo" | LC_ALL=C tr '[:upper:]' '[:lower:]')/$ref"
  pin=''
  for i in "${!sources[@]}"; do
    if [ "${sources[$i]}" = "$source" ]; then pin=${source_pins[$i]}; break; fi
  done
  if [ -n "$pin" ]; then pins+=("$pin"); continue; fi
  if ! gh api --hostname github.com "repos/$repo/commits/$ref" > "$response"; then
    echo "error: could not resolve $repo at $ref; no skills installed." >&2
    exit 1
  fi
  if ! unambiguous_object "$response" || ! pin=$(jq -esr '
      if length == 1 and (.[0] | type == "object") and
         (.[0].sha | type == "string" and test("\\A[0-9a-f]{40}\\z"))
      then .[0].sha else error("expected one full commit SHA") end
    ' "$response"); then
    echo "error: invalid source commit for $repo at $ref; no skills installed." >&2
    exit 1
  fi
  if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] && [ "$(printf '%s' "$ref" | LC_ALL=C tr '[:upper:]' '[:lower:]')" != "$pin" ]; then
    echo "error: source commit differs from the requested literal commit for $repo; no skills installed." >&2
    exit 1
  fi
  pins+=("$pin")
  sources+=("$source")
  source_pins+=("$pin")
done

# Observe the native CLI's actual destination identity in an isolated directory
# per source. A successful source resolution alone says nothing about the name
# in SKILL.md, which the CLI uses when --force places files in the user's home.
shopt -s nullglob dotglob
for i in "${!entries[@]}"; do
  read -r repo _ref path skill <<<"${entries[$i]}"
  stage="$stage_root/$i"
  mkdir "$stage"
  if ! out=$(gh skill install "$repo" "$path/SKILL.md" --pin "${pins[$i]}" \
      --dir "$stage" --force 2>&1); then
    echo "error: could not stage $repo $skill; no skills installed." >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  destinations=("$stage"/*)
  if [ "${#destinations[@]}" -ne 1 ] || [ "${destinations[0]}" != "$stage/$skill" ] ||
     [ ! -d "$stage/$skill" ] || [ -L "$stage/$skill" ] ||
     [ ! -f "$stage/$skill/SKILL.md" ] || [ -L "$stage/$skill/SKILL.md" ]; then
    echo "error: native destination for $repo $skill differs from its advertised identity; no skills installed." >&2
    exit 1
  fi
done

echo "Installing ${#entries[@]} skill(s) for agent(s): ${agents[*]} (scope=user)"
echo

fail=0
for agent in "${agents[@]}"; do
  for i in "${!entries[@]}"; do
    read -r repo _ path skill <<<"${entries[$i]}"
    # Capture output so the success path stays quiet but a failure can surface
    # the actual error (auth, network, missing skill, …) instead of swallowing it.
    if out=$(gh skill install "$repo" "$path/SKILL.md" --pin "${pins[$i]}" \
        --agent "$agent" --scope user --force 2>&1); then
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
