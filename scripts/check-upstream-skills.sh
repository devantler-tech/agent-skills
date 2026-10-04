#!/usr/bin/env bash
#
# Verify every UPSTREAM skill row in the README index still resolves to a real
# skill on its source repo. This is the network half of the index→source
# lockstep: `check-readme-index.sh` proves the in-house `devantler-tech/agent-skills`
# self-pointers resolve on disk (offline), but it explicitly CANNOT verify that
# each upstream `gh skill install <owner/repo> <skill>` target still exists —
# that needs network + auth. A typo'd, renamed, or upstream-deleted repo/skill
# slug passes the offline count-lockstep gate and only fails at *consume* time,
# rippling across every consumer — the highest-blast-radius failure for this
# shared library — so it is worth catching proactively.
#
# For each non-in-house `## Skills` row it parses the `Upstream` tree URL
# (https://github.com/<owner>/<repo>/tree/<ref>/<path>) and confirms via the
# GitHub API that <path>/SKILL.md exists on <ref> — i.e. the skill that
# `gh skill install` would fetch is still present at the pointer the index
# advertises.
#
# Because it depends on third-party availability, this is intentionally NOT part
# of the PR-blocking `lint-scripts`/`CI - Required Checks` gate (an upstream
# outage must never flake an unrelated contributor PR). It runs on a schedule
# (see .github/workflows/check-upstream-skills.yaml) and fails visibly on real
# drift. To keep a transient GitHub blip from reporting *false* drift, network /
# rate-limit / 5xx errors are retried and, if still failing, downgraded to a
# ::warning:: (non-fatal). HTTP 404 is hard drift; a successful response that
# does not identify the requested file is a separate hard verification failure.
#
# Assumes upstream tree URLs pin a single-segment ref (e.g. `main`), which every
# current index row does; the ref is the first path segment after `/tree/`.
#
# Usage: ./scripts/check-upstream-skills.sh   (requires gh auth / GH_TOKEN)
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/.." && pwd)
cd "$repo_root"

if ! command -v gh >/dev/null 2>&1; then
  echo "::error::'gh' is required to resolve upstream skill targets." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "::error::'jq' is required to validate upstream skill file responses." >&2
  exit 1
fi

# Backoff command between transient-failure retries. Defaults to the real `sleep`
# (production behaviour unchanged); the offline self-test overrides it to a no-op so
# the persistent-transient → warning path runs without real backoff.
UPSTREAM_RETRY_SLEEP=${UPSTREAM_RETRY_SLEEP:-sleep}

# Keep repeated JSON paths visible before decoding a response into one identity.
unambiguous_object() {
  jq -es 'length==1 and (.[0]|type=="object")' >/dev/null <<< "$1" &&
    jq --stream -es '
      reduce .[] as $event ({complete:{}, valid:true};
        if ($event|length)==2 then
          .complete as $complete | $event[0] as $path |
          .valid = (.valid and (any(range(0;($path|length)+1);
            $complete[($path[0:.]|tojson)]==true)|not)) |
          .complete[($path|tojson)] = true
        else .complete[($event[0][0:-1]|tojson)] = true end) | .valid
    ' >/dev/null <<< "$1"
}

# Verify a file target or resolve a source revision when kind is commit.
# Commit success prints its immutable SHA; file success prints nothing. A definitive
# miss returns 1 (hard drift), persistent transport failure returns 2 (warn), and
# an invalid successful response returns 3 (verification failure).
resolve_target() {
  local owner=$1 repo=$2 ref=$3 path=$4 kind=${5:-file}
  local attempt err api_status http_status body endpoint pin
  endpoint="repos/$owner/$repo/contents/$path/SKILL.md?ref=$ref"
  [ "$kind" != commit ] || endpoint="repos/$owner/$repo/commits/$ref"
  for attempt in 1 2 3; do
    api_status=0
    gh api "$endpoint" --include > "$response_dir/response" 2> "$response_dir/error" || api_status=$?
    # This function is called in a conditional, so errexit cannot protect reads.
    # Partial output from a failed parser is not an observation of the response.
    http_status=$(awk 'NR==1 && /^HTTP\/[0-9.]+ [0-9][0-9][0-9] / {print $2}' "$response_dir/response") || return 3
    body=$(awk 'body {print; next} {sub(/\r$/, "")} /^$/ {body=1}' "$response_dir/response") || return 3
    err=$(cat "$response_dir/error") || return 3
    # Native cancellation/authentication errors may have no HTTP response.
    # Only general transport failure is eligible for the statusless retry path.
    case "$api_status" in 0|1) ;; *) return 3 ;; esac
    # Identity, absence and API-message classifications need an unambiguous body.
    # Transient HTTP status alone authorizes only bounded retries, never success.
    case "$http_status" in
      ''|408|429|5[0-9][0-9]) ;;
      *) unambiguous_object "$body" || return 3 ;;
    esac
    if [ "$http_status" = 200 ] && [ "$api_status" -eq 0 ]; then
      if [ "$kind" = commit ]; then
        pin=$(jq -esr 'if length==1 and (.[0].sha | type=="string" and test("\\A[0-9a-f]{40}\\z")) then .[0].sha else error("invalid commit") end' <<<"$body") || return 3
        if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]] && [ "$(printf '%s' "$ref" | LC_ALL=C tr '[:upper:]' '[:lower:]')" != "$pin" ]; then return 3; fi
        printf '%s' "$pin"
        return 0
      fi
      # Validate after the API call so a directory or malformed payload cannot be
      # mistaken for a transport error and downgraded to a transient warning.
      if printf '%s' "$body" | jq -es --arg path "$path/SKILL.md" '
        length == 1 and (.[0] | type == "object"
          and .type == "file" and .name == "SKILL.md" and .path == $path)
      ' >/dev/null 2>&1; then
        return 0
      fi
      return 3
    fi
    # One complete response establishes absence; diagnostic prose is never status.
    if [ "$http_status" = 404 ] && [ "$api_status" -eq 1 ]; then
      if printf '%s' "$body" | jq -es 'length==1 and (.[0] | type=="object" and (.message | type=="string"))' >/dev/null 2>&1; then return 1; fi
      return 3
    fi
    case "$http_status" in
      403)
        # The actual API message identifies rate limiting, not unrelated stderr.
        printf '%s' "$body" | jq -es 'length==1 and (.[0].message | type=="string" and test("^(API rate limit exceeded|You have exceeded a secondary rate limit|You have triggered an abuse detection mechanism)";"i"))' >/dev/null 2>&1 || return 3
        ;;
      408|429|5[0-9][0-9]) ;;
      '') [ "$api_status" -ne 0 ] || return 3 ;;
      *) return 3 ;;
    esac
    # Transport, server and explicit rate-limit failures retain bounded retries.
    "$UPSTREAM_RETRY_SLEEP" $((attempt * 2)) || return 3
  done
  printf '%s' "$err"
  return 2
}

# Use the installer's validated table interpretation. Refuse a partial catalogue
# before resolving any source. In-house targets remain the offline guard's job.
catalogue=$(bash "$script_dir/readme-index.sh" --targets)
rows=$(printf '%s\n' "$catalogue" | LC_ALL=C awk 'tolower($1) != "devantler-tech/agent-skills"')

if [ -z "$rows" ]; then
  echo "::error::No upstream skill rows parsed from the README '## Skills' index — the tables or parser drifted."
  exit 1
fi

response_dir=$(mktemp -d)
trap 'rm -rf "$response_dir"' EXIT

checked=0
drift=0
warned=0
invalid=0
# Tree links explicitly name github.com regardless of the operator's default.
export GH_HOST=github.com
sources=() source_pins=() source_statuses=() source_details=()
while read -r source ref path _skill; do
  owner=${source%%/*}
  repo=${source#*/}

  checked=$((checked + 1))
  identity="$(printf '%s' "$source" | LC_ALL=C tr '[:upper:]' '[:lower:]')/$ref"
  index=-1
  for i in "${!sources[@]}"; do
    if [ "${sources[$i]}" = "$identity" ]; then index=$i; break; fi
  done
  if [ "$index" -eq -1 ]; then
    index=${#sources[@]}
    status=0
    detail=$(resolve_target "$owner" "$repo" "$ref" '' commit) || status=$?
    sources+=("$identity"); source_statuses+=("$status"); source_details+=("$detail")
    source_pins+=("$detail")
  fi
  status=${source_statuses[$index]}; detail=${source_details[$index]}
  if [ "$status" -eq 0 ]; then
    detail=$(resolve_target "$owner" "$repo" "${source_pins[$index]}" "$path") || status=$?
  fi
  if [ "$status" -eq 0 ]; then
    echo "  ok    $owner/$repo @ $ref :: $path/SKILL.md"
  else
    case "$status" in
      1)
        echo "::error::upstream skill target '$owner/$repo $path' (ref $ref) no longer resolves — no '$path/SKILL.md' on $ref. The README row points at a renamed/deleted upstream skill; every consumer's 'gh skill install' will fail."
        drift=1
        ;;
      3)
        echo "::error::could not establish upstream skill file '$owner/$repo $path/SKILL.md' (ref $ref): a permanent API error or successful response without the expected file prevented verification."
        invalid=$((invalid + 1))
        ;;
      2)
        echo "::warning::could not verify '$owner/$repo $path' (ref $ref) after retries — treating as transient (network/rate-limit), not drift. Last error: ${detail//$'\n'/ }"
        warned=$((warned + 1))
        ;;
      *)
        echo "::error::upstream verification could not complete for '$owner/$repo $path/SKILL.md' (ref $ref)."
        invalid=$((invalid + 1))
        ;;
    esac
  fi
done <<<"$rows"

echo
echo "Checked $checked upstream target(s); drift=$drift, transient-warnings=$warned, invalid-responses=$invalid."
if [ "$drift" -ne 0 ]; then
  echo "::error::Upstream skill drift detected — fix the broken README index row(s) above."
  exit 1
fi
if [ "$invalid" -ne 0 ]; then
  echo "::error::Upstream skill verification failed — inspect the invalid file responses above."
  exit 1
fi
