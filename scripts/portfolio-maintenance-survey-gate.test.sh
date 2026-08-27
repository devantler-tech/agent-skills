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
breakage_contract="every breakage signal, not just the default branch"
pentad_contract="the complete hygiene pentad, not an abbreviation of it: failing required checks, unresolved review threads, non-thread review findings, a conflict with or lag behind the base, any pre-merge quality checks the review tooling publishes separately from ci, and a missing or stale current-head green review."
control_contract="a scan of the maintainer control channel across the prs and issues this run can verify it created"
ownership_contract="re-verifying the resumed artifact against live state"
renewal_contract="renew the token on the same beat as the work — immediately before each mutation, and again after any pause the run did not control — and condition that mutation on the renewal succeeding."
completion_contract="a full survey completes only when every mandatory survey query and the closing exact-head recheck succeed; skipped, failed, incomplete, or query-unknown survey evidence does not advance the timestamp, and a missing or malformed timestamp is stale."

# ONE registry of the operative preemption checks, in `label|contract` form.
# Validation, fixture construction and mutation-case generation all read this
# list, so a fifth check cannot be added to one site and silently omitted from
# another — which would leave the fixture suite passing over a check nothing
# asserts. (Repo principle: never hand-maintain a parallel list.)
preemption_checks=(
	"breakage|$breakage_contract"
	"pentad|$pentad_contract"
	"control channel|$control_contract"
	"live ownership|$ownership_contract"
)
expected_table='fresh:higher-rung result=full survey
yes:yes=skip
yes:no=dispatch
no:either=dispatch'

normalize() {
  LC_ALL=C awk '{
    line=tolower($0)
    gsub(/\*/, "", line)
    gsub(/[[:space:]]+/, " ", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    if (line != "") printf "%s ", line
  }' "$1"
}

bounded_block() { # file, begin pattern, end pattern
  local file="$1" begin="$2" end="$3"
  LC_ALL=C awk -v begin="$begin" -v end="$end" '
    $0 ~ begin {
      begin_n++
      if (begin_n == 1) {
        begin_at=NR
        in_block=1
      }
      next
    }
    $0 ~ end {
      end_n++
      if (end_n == 1) {
        end_at=NR
        in_block=0
      }
      next
    }
    in_block { block=block $0 ORS }
    END {
      if (begin_n != 1 || end_n != 1 || begin_at >= end_at || block == "") exit 1
      printf "%s", block
    }
  ' "$file"
}

decision_block() { # skill
  bounded_block "$1" '^### Survey dispatch decision$' '^### Survey dispatch procedure$'
}

preemption_block() { # skill
  bounded_block "$1" '^<!-- resume-preemption:begin -->$' '^<!-- resume-preemption:end -->$'
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

check_preemption_contract() { # skill
  local block flat
  block="$(mktemp)"
  preemption_block "$1" >"$block" || { rm -f "$block"; return 1; }
  [ -s "$block" ] || { rm -f "$block"; return 1; }
  flat="$(normalize "$block")"
  rm -f "$block"
  local spec
  for spec in "${preemption_checks[@]}"; do
    grep -Fq "${spec#*|}" <<<"$flat" || return 1
  done
  return 0
}

check_gate_contract() { # skill
  local block flat actual_table skill_flat
  block="$(mktemp)"
  decision_block "$1" >"$block" || { rm -f "$block"; return 1; }
  [ -s "$block" ] || { rm -f "$block"; return 1; }
  flat="$(normalize "$block")"
  actual_table="$(decision_table "$1")"
  rm -f "$block"
  skill_flat="$(normalize "$1")"
  grep -Fq "$freshness_contract" <<<"$flat" &&
    grep -Fq "$selection_contract" <<<"$flat" &&
    grep -Fq "$carry_forward_contract" <<<"$flat" &&
    grep -Fq "$unknown_contract" <<<"$flat" &&
    grep -Fq "$advance_contract" <<<"$flat" &&
    [ "$actual_table" = "$expected_table" ] &&
    check_preemption_contract "$1" &&
    grep -Fq "$renewal_contract" <<<"$skill_flat" &&
    grep -Fq "$completion_contract" <<<"$skill_flat"
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
# The preemption body is GENERATED from the registry rather than restated, so a
# check added there appears in the fixture without a second edit.
preemption_body=""
for check_spec in "${preemption_checks[@]}"; do
	preemption_body+="${check_spec#*|}"$'\n'
done
printf '### Survey dispatch decision\n%s\n%s\n%s\n%s\n%s\n\n| Fresh | Higher-rung result | Full survey |\n| --- | --- | --- |\n| Yes | Yes | Skip |\n| Yes | No | Dispatch |\n| No | Either | Dispatch |\n### Survey dispatch procedure\n%s\n%s\n<!-- resume-preemption:begin -->\n%s<!-- resume-preemption:end -->\n' \
  "$freshness_contract" "$selection_contract" "$carry_forward_contract" \
  "$unknown_contract" "$advance_contract" "$renewal_contract" "$completion_contract" \
  "$preemption_body" >"$complete_fixture"
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
sed '/^### Survey dispatch procedure$/d' "$complete_fixture" >"$unterminated_fixture"
if check_gate_contract "$unterminated_fixture"; then
  printf '  ❌ unterminated dispatch gate unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ unterminated dispatch gate fails closed\n'
fi

for check_spec in "${preemption_checks[@]}"; do
  check_name="${check_spec%%|*}"
  check_text="${check_spec#*|}"
  missing_preemption_check_fixture="$tmp/missing-preemption-${check_name// /-}.md"
  LC_ALL=C awk -v check_text="$check_text" '$0 != check_text' \
    "$complete_fixture" >"$missing_preemption_check_fixture"
  if check_gate_contract "$missing_preemption_check_fixture"; then
    printf '  ❌ missing operative %s check unexpectedly passes\n' "$check_name" >&2
    fail=1
  else
    printf '  ✅ missing operative %s check fails closed\n' "$check_name"
  fi
done

missing_preemption_marker_fixture="$tmp/missing-preemption-marker.md"
sed '/^<!-- resume-preemption:begin -->$/d' "$complete_fixture" \
  >"$missing_preemption_marker_fixture"
if check_gate_contract "$missing_preemption_marker_fixture"; then
  printf '  ❌ missing preemption marker unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing preemption marker fails closed\n'
fi

missing_renewal_fixture="$tmp/missing-renewal.md"
sed "/renew the token on the same beat/d" "$complete_fixture" >"$missing_renewal_fixture"
if check_gate_contract "$missing_renewal_fixture"; then
  printf '  ❌ missing per-mutation ownership renewal unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing per-mutation ownership renewal fails closed\n'
fi

missing_completion_fixture="$tmp/missing-survey-completion.md"
LC_ALL=C awk -v completion="$completion_contract" '$0 != completion' \
  "$complete_fixture" >"$missing_completion_fixture"
if check_gate_contract "$missing_completion_fixture"; then
  printf '  ❌ incomplete survey evidence can unexpectedly refresh the cursor\n' >&2
  fail=1
else
  printf '  ✅ incomplete survey evidence cannot refresh the cursor\n'
fi

if [ "$fail" -ne 0 ]; then
  printf '❌ portfolio-maintenance survey gate test failed\n' >&2
  exit 1
fi

printf '✅ portfolio-maintenance survey gate test passed\n'
