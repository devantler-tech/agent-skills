#!/usr/bin/env bash
# Exercise the installed evidence entrypoint and its fail-closed malformed-input path.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
example="$script_dir/../references/evidence-example.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$script_dir/check-evidence.sh" --now 2026-09-24T00:00:00Z "$example" > "$work/result.json"
jq -e '.decision == "ADOPT" and .reasons == []' "$work/result.json" >/dev/null

printf '{"broken":' > "$work/malformed.json"
rc=0
bash "$script_dir/check-evidence.sh" --now 2026-09-24T00:00:00Z "$work/malformed.json" > "$work/out" 2> "$work/err" || rc=$?
[[ $rc -eq 2 && ! -s $work/out && -s $work/err ]]

printf 'check-evidence entrypoint: PASS\n'
