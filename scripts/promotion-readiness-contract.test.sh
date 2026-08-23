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
resume_pentad_contract="the complete hygiene pentad, not an abbreviation of it: failing required checks, unresolved review threads, non-thread review findings, a conflict with or lag behind the base, any pre-merge quality checks the review tooling publishes separately from ci, and a missing or stale current-head green review."

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

# The resume gate skips the survey, so its PR enumeration is the only thing that
# surfaces hygiene work on a resumed run. An abbreviated list silently drops the
# pentad members that a red/merge-ready reading cannot see -- a draft with green
# checks, no threads and no findings can still be conflicted or simply unreviewed
# at its current head, and is then neither red nor merge-ready.
# The sentence must sit INSIDE the resume preemption block, not merely somewhere in
# the file: if a later edit moved it into explanatory prose and dropped the operative
# check, a whole-file search would still pass and the contract would be satisfied by
# text that no longer governs anything.
#
# DELIMIT THE PREEMPTION LIST ITSELF, NOT THE WHOLE SECTION. Bounding this by the
# `## 1. Survey` .. `## 2. Select` headings spanned the full-survey prose as well, so
# moving the sentence out of the operative checks and into that half still matched --
# the regression this helper exists to catch would have passed it. Explicit markers
# make the region the document actually enacts, and a rename of either heading can no
# longer silently widen it.
#
# AN UNTERMINATED BLOCK IS NOT AN OPEN BLOCK, IT IS A BROKEN ONE. Streaming from the
# begin marker to EOF would make every later line count as operative -- exactly the
# whole-file search this helper replaced, reachable by deleting one marker. Require
# EXACTLY ONE ordered pair and fail closed otherwise, so a dropped, duplicated or
# swapped marker is a contract failure rather than a silently widened region.
resume_block() { # skill
  local begin_n end_n
  begin_n="$(grep -c '^<!-- resume-preemption:begin -->' "$1" || true)"
  end_n="$(grep -c '^<!-- resume-preemption:end -->' "$1" || true)"
  [ "$begin_n" -eq 1 ] && [ "$end_n" -eq 1 ] || return 1
  # Ordered: a file whose end marker precedes its begin marker has one of each and no
  # region at all.
  local begin_at end_at
  begin_at="$(grep -n '^<!-- resume-preemption:begin -->' "$1" | cut -d: -f1)"
  end_at="$(grep -n '^<!-- resume-preemption:end -->' "$1" | cut -d: -f1)"
  [ "$begin_at" -lt "$end_at" ] || return 1
  awk '/^<!-- resume-preemption:begin -->/{inblock=1; next} /^<!-- resume-preemption:end -->/{inblock=0} inblock' "$1"
}

check_resume_pentad_contract() { # skill
  local block flat
  block="$(mktemp)"
  resume_block "$1" >"$block" || { rm -f "$block"; return 1; }
  # An empty region means the headings moved; fail closed rather than report a pass
  # from a search over nothing.
  [ -s "$block" ] || { rm -f "$block"; return 1; }
  flat="$(normalize "$block")"
  rm -f "$block"
  grep -Fq "$resume_pentad_contract" <<<"$flat"
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

if check_resume_pentad_contract "$repo_root/portfolio-maintenance/SKILL.md"; then
  printf '  ✅ resume gate enumerates the complete hygiene pentad\n'
else
  printf '  ❌ resume gate enumerates an abbreviated pentad\n' >&2
  fail=1
fi

complete_fixture="$tmp/complete.md"
# The pentad sentence is placed inside the resume block, because that is where the
# contract requires it -- the fixture models the real document structure.
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:begin -->\n%s\n<!-- resume-preemption:end -->\n## 2. Select\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$complete_fixture"
if check_readiness_contract "$complete_fixture" &&
  check_no_partial_shorthand "$complete_fixture" &&
  check_session_contract "$complete_fixture" &&
  check_resume_pentad_contract "$complete_fixture" &&
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

misplaced_pentad_fixture="$tmp/misplaced-pentad.md"
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:begin -->\n<!-- resume-preemption:end -->\n## 2. Select\n%s\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$misplaced_pentad_fixture"
if check_resume_pentad_contract "$misplaced_pentad_fixture"; then
  printf '  ❌ pentad sentence outside the resume block unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ pentad sentence outside the resume block fails closed\n'
fi

# THE REGRESSION THIS HELPER NAMES: the sentence demoted out of the operative checks
# and into the full-survey prose, still inside `## 1. Survey`. A heading-bounded region
# matched it and reported a pass over a contract that no longer governed anything.
full_survey_half_fixture="$tmp/pentad-in-full-survey-half.md"
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:begin -->\n- preemption checks\n<!-- resume-preemption:end -->\nFor reference, the full survey reports %s\n## 2. Select\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$full_survey_half_fixture"
if check_resume_pentad_contract "$full_survey_half_fixture"; then
  printf '  ❌ pentad sentence demoted to the full-survey half unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ pentad sentence demoted to the full-survey half fails closed\n'
fi

# An UNTERMINATED block must fail closed too: streaming from the begin marker to EOF
# would restore the whole-file search by deleting a single line.
unterminated_fixture="$tmp/pentad-unterminated.md"
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:begin -->\n- preemption checks\n## 2. Select\n%s\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$unterminated_fixture"
if check_resume_pentad_contract "$unterminated_fixture"; then
  printf '  ❌ unterminated preemption block unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ unterminated preemption block fails closed\n'
fi

# Two begin markers are ambiguous about which region governs; reject rather than pick.
duplicate_marker_fixture="$tmp/pentad-duplicate-marker.md"
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:begin -->\n- preemption checks\n<!-- resume-preemption:end -->\n<!-- resume-preemption:begin -->\n%s\n<!-- resume-preemption:end -->\n## 2. Select\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$duplicate_marker_fixture"
if check_resume_pentad_contract "$duplicate_marker_fixture"; then
  printf '  ❌ duplicated preemption markers unexpectedly pass\n' >&2
  fail=1
else
  printf '  ✅ duplicated preemption markers fail closed\n'
fi

# A pair in the wrong ORDER bounds no region at all.
swapped_marker_fixture="$tmp/pentad-swapped-markers.md"
printf '%s\n%s\n%s\n## 1. Survey\n<!-- resume-preemption:end -->\n%s\n<!-- resume-preemption:begin -->\n## 2. Select\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$swapped_marker_fixture"
if check_resume_pentad_contract "$swapped_marker_fixture"; then
  printf '  ❌ swapped preemption markers unexpectedly pass\n' >&2
  fail=1
else
  printf '  ✅ swapped preemption markers fail closed\n'
fi

# A missing marker pair must fail closed rather than search the whole file.
unmarked_fixture="$tmp/pentad-unmarked.md"
printf '%s\n%s\n%s\n## 1. Survey\n%s\n## 2. Select\n' \
  "$readiness_contract" "$session_contract" "$trusted_merge_contract" "$resume_pentad_contract" >"$unmarked_fixture"
if check_resume_pentad_contract "$unmarked_fixture"; then
  printf '  ❌ pentad sentence with no preemption markers unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ missing preemption markers fail closed\n'
fi

abbreviated_pentad_fixture="$tmp/abbreviated-pentad.md"
sed 's/, a conflict with or lag behind the base//' "$complete_fixture" >"$abbreviated_pentad_fixture"
if check_resume_pentad_contract "$abbreviated_pentad_fixture"; then
  printf '  ❌ abbreviated pentad unexpectedly passes\n' >&2
  fail=1
else
  printf '  ✅ abbreviated pentad fails closed\n'
fi

if [ "$fail" -ne 0 ]; then
  printf '❌ promotion readiness contract test failed\n' >&2
  exit 1
fi

printf '✅ promotion readiness contract test passed\n'
