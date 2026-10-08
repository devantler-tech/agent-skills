#!/usr/bin/env bash
# Preserve the separate, quiet handoff for contributions to third-party projects.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
reference="portfolio-maintenance/references/upstream-contributions.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check_contract() {
  local root="$1" flat skill
  [[ -f "$root/$reference" ]] || return 1
  flat="$(tr '\n' ' ' <"$root/$reference" | tr -s '[:space:]')"
  for clause in \
    'Mark the current-head draft Ready for Review' \
    'Do not post internal reviews' \
    'Keep only the PR title and description up to date' \
    'Upstream approval is not a prerequisite for this handoff' \
    'Reply to received feedback in the contributor' \
    'Resolve a thread only after' \
    'Never merge or administer the upstream repository'; do
    [[ "$flat" == *"$clause"* ]] || return 1
  done
  for skill in portfolio-maintenance product-engineering self-improvement agent-improvement; do
    [[ -f "$root/$skill/SKILL.md" ]] || return 1
    grep -Fq 'references/upstream-contributions.md)' "$root/$skill/SKILL.md" || return 1
  done
}

if ! check_contract "$repo_root"; then
  printf 'FAIL: upstream contributions lack a reachable quiet Ready for Review handoff\n' >&2
  exit 1
fi

mkdir -p "$tmp/fixture"
for skill in portfolio-maintenance product-engineering self-improvement agent-improvement; do
  mkdir -p "$tmp/fixture/$skill"
  cp "$repo_root/$skill/SKILL.md" "$tmp/fixture/$skill/SKILL.md"
done
mkdir -p "$tmp/fixture/portfolio-maintenance/references"
cp "$repo_root/$reference" "$tmp/fixture/$reference"
check_contract "$tmp/fixture"

# Each regression loses a real obligation; explanatory text elsewhere cannot
# make a disconnected standalone skill inherit the procedure.
for clause in 'Mark the current-head draft Ready for Review' 'Do not post internal reviews' \
  'Upstream approval is not a prerequisite for this handoff' \
  'Reply to received feedback in the contributor'; do
  sed "/$clause/d" "$repo_root/$reference" >"$tmp/fixture/$reference"
  if check_contract "$tmp/fixture"; then
    printf 'FAIL: missing obligation was accepted: %s\n' "$clause" >&2
    exit 1
  fi
done
cp "$repo_root/$reference" "$tmp/fixture/$reference"
sed '/references\/upstream-contributions.md)/d' "$repo_root/product-engineering/SKILL.md" >"$tmp/fixture/product-engineering/SKILL.md"
if check_contract "$tmp/fixture"; then
  printf 'FAIL: disconnected standalone product-engineering skill was accepted\n' >&2
  exit 1
fi
printf 'PASS: quiet upstream handoff and received-feedback obligations remain reachable\n'
