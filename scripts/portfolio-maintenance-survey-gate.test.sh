#!/usr/bin/env bash
# Contract test for the portfolio-maintenance survey dispatch decision.
# A fresh direct preemption result already fixes the selection rung, so durable
# carry-forward must not be a second, unrelated prerequisite for skipping the
# expensive broad survey. Stale discovery evidence still forces that survey.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

freshness_contract="fresh means the last full survey is still within the consuming deployment's staleness bound."
selection_contract="higher-rung result means the complete direct preemption checks establish either the next action or a live stop condition that forbids descending below breakage and trusted-pr work."
carry_forward_contract="a carry-forward may narrow the direct read, but it is neither evidence of current ownership nor a prerequisite to skipping the survey."
unknown_contract="an empty, incomplete, or query-unknown direct preemption result is not a higher-rung result and therefore dispatches the full survey."
advance_contract="advance-level work by itself is not a higher-rung result."
expected_table='fresh:higher-rung result=full survey
yes:yes=skip
yes:no=dispatch
no:either=dispatch'

normalize() {
  LC_ALL=C tr '\n' ' ' <"$1" |
    LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C tr -d '*' |
    LC_ALL=C sed -E 's/[[:space:]]+/ /g'
}

decision_block() { # skill
  local begin_n end_n begin_at end_at
  begin_n="$(grep -c '^<!-- survey-dispatch-gate:begin -->' "$1" || true)"
  end_n="$(grep -c '^<!-- survey-dispatch-gate:end -->' "$1" || true)"
  [ "$begin_n" -eq 1 ] && [ "$end_n" -eq 1 ] || return 1
  begin_at="$(grep -n '^<!-- survey-dispatch-gate:begin -->' "$1" | cut -d: -f1)"
  end_at="$(grep -n '^<!-- survey-dispatch-gate:end -->' "$1" | cut -d: -f1)"
  [ "$begin_at" -lt "$end_at" ] || return 1
  awk '/^<!-- survey-dispatch-gate:begin -->/{inblock=1; next} /^<!-- survey-dispatch-gate:end -->/{inblock=0} inblock' "$1"
}

decision_table() { # skill
  decision_block "$1" |
    awk -F '|' '
      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return tolower(value)
      }
      /^\|/ {
        fresh=trim($2)
        result=trim($3)
        decision=trim($4)
        if (fresh == "---" || fresh == "") next
        print fresh ":" result "=" decision
      }
    '
}

check_gate_contract() { # skill
  local block flat actual_table
  block="$(mktemp)"
  decision_block "$1" >"$block" || { rm -f "$block"; return 1; }
  [ -s "$block" ] || { rm -f "$block"; return 1; }
  flat="$(normalize "$block")"
  actual_table="$(decision_table "$1")"
  rm -f "$block"
  grep -Fq "$freshness_contract" <<<"$flat" &&
    grep -Fq "$selection_contract" <<<"$flat" &&
    grep -Fq "$carry_forward_contract" <<<"$flat" &&
    grep -Fq "$unknown_contract" <<<"$flat" &&
    grep -Fq "$advance_contract" <<<"$flat" &&
    [ "$actual_table" = "$expected_table" ]
}

fail=0
skill_file="$repo_root/portfolio-maintenance/SKILL.md"
if check_gate_contract "$skill_file"; then
  printf '  ✅ fresh higher-rung work skips the broad survey without carry-forward\n'
else
  printf '  ❌ survey dispatch still depends on carry-forward or lacks a safety branch\n' >&2
  fail=1
fi

complete_fixture="$tmp/complete.md"
printf '<!-- survey-dispatch-gate:begin -->\n%s\n%s\n%s\n%s\n%s\n\n| Fresh | Higher-rung result | Full survey |\n| --- | --- | --- |\n| Yes | Yes | Skip |\n| Yes | No | Dispatch |\n| No | Either | Dispatch |\n<!-- survey-dispatch-gate:end -->\n' \
  "$freshness_contract" "$selection_contract" "$carry_forward_contract" \
  "$unknown_contract" "$advance_contract" >"$complete_fixture"
if check_gate_contract "$complete_fixture"; then
  printf '  ✅ complete dispatch table passes\n'
else
  printf '  ❌ complete dispatch table unexpectedly fails\n' >&2
  fail=1
fi

carry_forward_required_fixture="$tmp/carry-forward-required.md"
sed 's/nor a prerequisite to skipping the survey/and is required to skip the survey/' \
  "$complete_fixture" >"$carry_forward_required_fixture"
if check_gate_contract "$carry_forward_required_fixture"; then
  printf '  ❌ carry-forward-required regression unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ carry-forward-required regression fails closed\n'
fi

stale_skip_fixture="$tmp/stale-skip.md"
sed 's/| No | Either | Dispatch |/| No | Either | Skip |/' \
  "$complete_fixture" >"$stale_skip_fixture"
if check_gate_contract "$stale_skip_fixture"; then
  printf '  ❌ stale discovery evidence can unexpectedly skip the survey\n' >&2
  fail=1
else
  printf '  ✅ stale discovery evidence still forces the survey\n'
fi

empty_result_skip_fixture="$tmp/empty-result-skip.md"
sed 's/| Yes | No | Dispatch |/| Yes | No | Skip |/' \
  "$complete_fixture" >"$empty_result_skip_fixture"
if check_gate_contract "$empty_result_skip_fixture"; then
  printf '  ❌ an empty direct result can unexpectedly skip discovery\n' >&2
  fail=1
else
  printf '  ✅ an empty direct result still forces discovery\n'
fi

unknown_result_fixture="$tmp/unknown-result.md"
sed '/empty, incomplete, or query-unknown/d' "$complete_fixture" >"$unknown_result_fixture"
if check_gate_contract "$unknown_result_fixture"; then
  printf '  ❌ QUERY-UNKNOWN preemption can unexpectedly count as complete\n' >&2
  fail=1
else
  printf '  ✅ QUERY-UNKNOWN preemption fails closed to full discovery\n'
fi

advance_only_fixture="$tmp/advance-only.md"
sed '/advance-level work by itself/d' "$complete_fixture" >"$advance_only_fixture"
if check_gate_contract "$advance_only_fixture"; then
  printf '  ❌ advance-only work can unexpectedly short-circuit discovery\n' >&2
  fail=1
else
  printf '  ✅ advance-only work still forces discovery\n'
fi

unterminated_fixture="$tmp/unterminated.md"
sed '/survey-dispatch-gate:end/d' "$complete_fixture" >"$unterminated_fixture"
if check_gate_contract "$unterminated_fixture"; then
  printf '  ❌ unterminated dispatch gate unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ unterminated dispatch gate fails closed\n'
fi

if [ "$fail" -ne 0 ]; then
  printf '❌ portfolio-maintenance survey gate test failed\n' >&2
  exit 1
fi

printf '✅ portfolio-maintenance survey gate test passed\n'
