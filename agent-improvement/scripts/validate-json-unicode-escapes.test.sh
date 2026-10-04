#!/usr/bin/env bash
# Prove the raw-byte boundary distinguishes valid pairs and literal text from lone surrogates.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
validator="$script_dir/validate-json-unicode-escapes.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

printf '%s\n' '{"value":"\ud83d\ude00"}' > "$work/paired.json"
printf '%s\n' '{"value":"\\ud800"}' > "$work/literal.json"
printf '%s\n' '{"value":"\ud800"}' > "$work/high.json"
printf '%s\n' '{"value":"\udc00"}' > "$work/low.json"

bash "$validator" "$work/paired.json"
bash "$validator" "$work/literal.json"
if bash "$validator" "$work/high.json"; then
  printf 'FAIL accepted a lone high surrogate\n' >&2
  exit 1
fi
if bash "$validator" "$work/low.json"; then
  printf 'FAIL accepted a lone low surrogate\n' >&2
  exit 1
fi

printf 'JSON Unicode escape boundary: PASS\n'
