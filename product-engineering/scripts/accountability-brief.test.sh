#!/usr/bin/env bash
# Exercise the installed accountability entrypoint in both machine and human output modes.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
example="$script_dir/../references/accountability-product.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$script_dir/accountability-brief.sh" --mode check "$example" > "$work/result.json"
jq -e '
  .status == "STRUCTURALLY_VALID"
  and .semanticReview == "REQUIRED"
  and .authority == "none"
  and .synthetic == true
  and .decisionId == "search-preview"
' "$work/result.json" >/dev/null

bash "$script_dir/accountability-brief.sh" --mode render "$example" > "$work/render.md"
grep -Fq 'Synthetic example' "$work/render.md"
grep -Fq 'Human semantic review is required.' "$work/render.md"

printf '{"broken":' > "$work/malformed.json"
rc=0
bash "$script_dir/accountability-brief.sh" --mode check "$work/malformed.json" > "$work/out" 2> "$work/err" || rc=$?
[[ $rc -eq 2 && ! -s $work/out && -s $work/err ]]

printf 'accountability-brief entrypoint: PASS\n'
