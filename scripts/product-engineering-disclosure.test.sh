#!/usr/bin/env bash
# Keep the installed skill's conditional code-quality guidance reachable.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
finished=0
# Remove only this test's private fixture and preserve failures, including Bash 3.2 aborts.
cleanup() {
  local rc=$?
  rm -rf "$tmp"
  if [[ "$finished" != 1 && "$rc" == 0 ]]; then rc=1; fi
  exit "$rc"
}
trap cleanup EXIT

# Verify one installable package's entrypoint route and adjacent conditional references.
check() {
  local skill=$1 reference target
  reference="$skill/references/code-quality.md"
  [[ -s "$skill/SKILL.md" && -s "$reference" ]] || return 1
  grep -Fq '(references/code-quality.md)' "$skill/SKILL.md" || return 1
  for target in tool-maturation shared-code; do
    [[ -s "$skill/references/$target.md" ]] || return 1
    grep -Fq "($target.md)" "$reference" || return 1
  done
}

check "$root/product-engineering" || {
  printf 'FAIL: conditional code-quality guidance is not reachable from the installed skill\n' >&2
  exit 1
}

# Copy only the installable package; no repository scripts resolve its references.
cp -R "$root/product-engineering" "$tmp/installed"
check "$tmp/installed"
cp "$tmp/installed/SKILL.md" "$tmp/entrypoint"
cp "$tmp/installed/references/code-quality.md" "$tmp/reference"

sed '/(references\/code-quality.md)/d' "$tmp/entrypoint" >"$tmp/installed/SKILL.md"
if check "$tmp/installed"; then
  printf 'FAIL: disconnected code-quality guidance was accepted\n' >&2
  exit 1
fi
cp "$tmp/entrypoint" "$tmp/installed/SKILL.md"
: >"$tmp/installed/references/code-quality.md"
if check "$tmp/installed"; then
  printf 'FAIL: empty code-quality reference was accepted\n' >&2
  exit 1
fi
cp "$tmp/reference" "$tmp/installed/references/code-quality.md"
for target in tool-maturation shared-code; do
  mv "$tmp/installed/references/$target.md" "$tmp/$target.md"
  if check "$tmp/installed"; then
    printf 'FAIL: missing %s procedure was accepted\n' "$target" >&2
    exit 1
  fi
  mv "$tmp/$target.md" "$tmp/installed/references/$target.md"
done
check "$tmp/installed"
printf 'PASS: installed reference route and four broken-package controls\n'
finished=1
