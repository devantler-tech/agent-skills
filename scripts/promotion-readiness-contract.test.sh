#!/usr/bin/env bash
# Contract test for the three autonomous-engineering skills' promotion gate.
# Each skill can be installed independently, so each must carry the complete
# readiness definition and revalidate at both mutation boundaries instead of
# reusing an earlier observation. The portfolio's existing-PR path must also
# revalidate directly at its merge decision.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

readiness_contract="genuine readiness means the consuming deployment's complete promotion gate: an own or trusted author, programmatic validation with all required ci and pre-merge quality checks green, zero unresolved thread and non-thread review findings, no merge conflict, a green review at the current head, and tried and evaluated as a user."
session_contract="immediately before self-promotion, re-read the current head and revalidate genuine readiness; immediately before merge, re-read the head and revalidate genuine readiness again."
trusted_merge_contract="immediately before every merge in this path, re-read the current head and revalidate genuine readiness; abort if any condition changed."
partial_shorthand="genuine readiness (programmatically tested + green review at the current head + tried and evaluated as a user)"

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

check_no_partial_shorthand() { # skill
  local flat
  flat="$(normalize "$1")"
  ! grep -Fq "$partial_shorthand" <<<"$flat"
}

check_session_contract() { # skill
  local flat
  flat="$(normalize "$1")"
  grep -Fq "$session_contract" <<<"$flat"
}

check_trusted_merge_contract() { # skill
  local flat
  flat="$(normalize "$1")"
  grep -Fq "$trusted_merge_contract" <<<"$flat"
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
  if check_no_partial_shorthand "$skill_file"; then
    printf '  ✅ %s has no competing partial shorthand\n' "$skill"
  else
    printf '  ❌ %s retains a competing partial shorthand\n' "$skill" >&2
    fail=1
  fi
  if check_session_contract "$skill_file"; then
    printf '  ✅ %s revalidates both promotion and merge\n' "$skill"
  else
    printf '  ❌ %s can reuse stale readiness\n' "$skill" >&2
    fail=1
  fi
done

if check_trusted_merge_contract "$repo_root/portfolio-maintenance/SKILL.md"; then
  printf '  ✅ existing-PR path revalidates directly before merge\n'
else
  printf '  ❌ existing-PR path can merge on stale readiness\n' >&2
  fail=1
fi

complete_fixture="$tmp/complete.md"
printf '%s\n%s\n%s\n' "$readiness_contract" "$session_contract" "$trusted_merge_contract" >"$complete_fixture"
if check_readiness_contract "$complete_fixture" &&
  check_no_partial_shorthand "$complete_fixture" &&
  check_session_contract "$complete_fixture" &&
  check_trusted_merge_contract "$complete_fixture"; then
  printf '  ✅ complete fixture passes\n'
else
  printf '  ❌ complete fixture unexpectedly fails\n' >&2
  fail=1
fi

missing_clause_fixture="$tmp/missing-clause.md"
sed 's/, no merge conflict//' "$complete_fixture" >"$missing_clause_fixture"
if check_readiness_contract "$missing_clause_fixture"; then
  printf '  ❌ missing readiness clause unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing readiness clause fails closed\n'
fi

contradictory_fixture="$tmp/contradictory-shorthand.md"
printf '%s\n%s\n' "$readiness_contract" "$partial_shorthand" >"$contradictory_fixture"
if check_no_partial_shorthand "$contradictory_fixture"; then
  printf '  ❌ contradictory shorthand unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ contradictory shorthand fails closed\n'
fi

missing_boundary_fixture="$tmp/missing-boundary.md"
printf '%s\n' "$readiness_contract" >"$missing_boundary_fixture"
if check_session_contract "$missing_boundary_fixture"; then
  printf '  ❌ missing mutation-boundary rule unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing mutation-boundary rule fails closed\n'
fi

missing_trusted_merge_fixture="$tmp/missing-trusted-merge.md"
printf '%s\n%s\n' "$readiness_contract" "$session_contract" >"$missing_trusted_merge_fixture"
if check_trusted_merge_contract "$missing_trusted_merge_fixture"; then
  printf '  ❌ missing existing-PR merge rule unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing existing-PR merge rule fails closed\n'
fi

if [ "$fail" -ne 0 ]; then
  printf '❌ promotion readiness contract test failed\n' >&2
  exit 1
fi

printf '✅ promotion readiness contract test passed\n'
