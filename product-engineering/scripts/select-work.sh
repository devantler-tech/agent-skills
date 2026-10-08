#!/usr/bin/env bash
# Assessment only: no forge writes, claims, execution or readiness clearance.
set -euo pipefail
refuse() { printf '%s\n' "$*" >&2; exit 2; }
[[ $# == 3 && $1 == --now && $2 =~ ^[0-9]+$ ]] || refuse 'usage: select-work.sh --now UNIX_SECONDS INPUT.json'
now=$2 input=$3
[[ $input == /* ]] || input="./$input"
[[ -f $input && -r $input ]] || refuse 'input must be a readable regular file'
command -v jq >/dev/null || refuse 'missing dependency: jq'
command -v iconv >/dev/null || refuse 'missing dependency: iconv'
umask 077
work=$(mktemp -d) || refuse 'input snapshot unavailable'
trap 'rm -rf "$work"' EXIT
cat -- "$input" > "$work/input" || refuse 'input read failed'
iconv -f UTF-8 -t UTF-16BE "$work/input" |
  iconv -f UTF-16BE -t UTF-8 > "$work/validated" 2>/dev/null || refuse 'invalid UTF-8'
cmp -s "$work/input" "$work/validated" || refuse 'invalid UTF-8'
case ${BASH_SOURCE[0]} in */*) parent=${BASH_SOURCE[0]%/*} ;; *) parent=. ;; esac
directory=$(cd "$parent" && pwd -P && printf '.') || refuse 'installed directory unavailable'
directory=${directory%$'\n.'}
bash "$directory/validate-json-unicode-escapes.sh" "$work/input" || refuse 'invalid Unicode escape'
jq --stream -e -s --argjson now "$now" -f "$directory/select-work.jq" "$work/input" > "$work/result" || refuse 'selection evidence invalid'
cat "$work/result"
