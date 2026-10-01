#!/usr/bin/env bash
# Validate all catalogue rows before emitting any install entries or targets.
# Default: <repository> <skill>; --targets: <repository> <ref> <path> <skill>.
# --row-count counts validated rows before de-duplication for the CI index guard.
# No GitHub calls; every field is data, never a shell expression.
set -euo pipefail
mode=install
case "$#:${1:-}" in
  0:) ;;
  1:--targets) mode=targets ;;
  1:--row-count) mode=rows ;;
  *) echo 'error: usage: readme-index.sh [--targets|--row-count]' >&2; exit 2 ;;
esac
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readme="$script_dir/../README.md"
[ -f "$readme" ] || { echo "error: could not find README index at $readme" >&2; exit 1; }
# Capture first: a late invalid row must not leak a usable partial catalogue.
entries=$(LC_ALL=C awk -v mode="$mode" -f "$script_dir/readme-index.awk" "$readme")
printf '%s\n' "$entries" | LC_ALL=C sort -u
