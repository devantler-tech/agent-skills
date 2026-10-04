#!/usr/bin/env bash
# Exercise the installed flow entrypoint against real retained-evidence bytes.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
example="$script_dir/../references/flow-example.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$script_dir/measure-flow.sh" "$example" > "$work/result.json"
jq -e '
  .version == 1
  and .run.id == "synthetic-run"
  and .artifactMix == {
    complete: true,
    unique: 2,
    easy: 1,
    substantive: 1,
    unknown: 0,
    revisits: 1,
    easyShare: 0.5
  }
' "$work/result.json" >/dev/null

printf '{"broken":' > "$work/malformed.json"
rc=0
bash "$script_dir/measure-flow.sh" "$work/malformed.json" > "$work/out" 2> "$work/err" || rc=$?
[[ $rc -eq 2 && ! -s $work/out && -s $work/err ]]

printf 'measure-flow entrypoint: PASS\n'
