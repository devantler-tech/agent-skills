#!/usr/bin/env bash
# Validate retained raw evidence bytes before any JSON decoding or output.
set -euo pipefail
refuse() { printf '%s\n' "$*" >&2; exit 2; }
[[ $# == 3 && $1 == --mode && ( $2 == check || $2 == render ) ]] || refuse 'usage: accountability-brief.sh --mode check|render INPUT.json'
mode=$2 input=$3
[[ -f $input && -r $input ]] || refuse 'input must be a readable regular file'
command -v jq >/dev/null || refuse 'missing dependency: jq'
command -v iconv >/dev/null || refuse 'missing dependency: iconv'
umask 077
work=$(mktemp -d) || refuse 'temporary input snapshot unavailable'
trap 'rm -rf "$work"' EXIT
# Evaluate exactly the privately retained bytes that passed strict decoding.
cat -- "$input" > "$work/input" || refuse 'input snapshot could not be read'
iconv -f UTF-8 -t UTF-8 "$work/input" >/dev/null 2>&1 || refuse 'input is not valid UTF-8'
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P && printf '.') || refuse 'installed tool directory unavailable'
script_dir=${script_dir%$'\n.'}
jq --stream -s --arg mode "$mode" -f "$script_dir/accountability-brief.jq" "$work/input" > "$work/result" || refuse 'brief evaluation failed'
if [[ $mode == render ]]; then jq -r . "$work/result" > "$work/render" || refuse 'brief rendering failed'; cat "$work/render"; exit 0; fi
cat "$work/result"
