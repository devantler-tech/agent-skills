#!/usr/bin/env bash
# Contract test for the three autonomous-engineering skills' promotion gate.
# Each skill can be installed independently, so each must carry the complete
# readiness definition; the portfolio loop must also revalidate at both
# mutation boundaries instead of reusing an earlier observation.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

readiness_contract="genuine readiness means the consuming deployment's complete promotion gate: an own or trusted author, programmatic validation with all required ci and pre-merge quality checks green, zero unresolved thread and non-thread review findings, no merge conflict, a green review at the current head, and tried and evaluated as a user."
session_contract="immediately before self-promotion, re-read the current head and revalidate genuine readiness; immediately before merge, re-read the head and revalidate genuine readiness again."

normalize() {
  LC_ALL=C tr '\n' ' ' <"$1" |
    LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C tr -d '*' |
    LC_ALL=C sed -E 's/[[:space:]]+/ /g'
}

check_readiness_contract() { # skill
  local flat
  flat="$(normalize "$1")"
  grep -Fq "$readiness_contract" <<<"$flat"
}

fail=0
for skill in portfolio-maintenance product-engineering self-improvement; do
  skill_file="$repo_root/$skill/SKILL.md"
  if check_readiness_contract "$skill_file"; then
    printf '  ✅ %s carries the complete readiness contract\n' "$skill"
  else
    printf '  ❌ %s carries a partial readiness contract\n' "$skill" >&2
    fail=1
  fi
done

portfolio_flat="$(normalize "$repo_root/portfolio-maintenance/SKILL.md")"
if grep -Fq "$session_contract" <<<"$portfolio_flat"; then
  printf '  ✅ portfolio loop revalidates both promotion and merge\n'
else
  printf '  ❌ portfolio loop can reuse stale readiness\n' >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  printf '❌ promotion readiness contract test failed\n' >&2
  exit 1
fi

printf '✅ promotion readiness contract test passed\n'
