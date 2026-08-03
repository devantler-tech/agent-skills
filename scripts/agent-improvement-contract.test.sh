#!/usr/bin/env bash
#
# Contract test for the agent-improvement skill's evidence gates. Rate-based
# metrics need comparable baselines, post-change time and observation-volume
# floors, and an uncontaminated observation window before a success/failure
# verdict is meaningful; coordination verdicts need distinct-writer provenance.
# State checks may be decisive from one live inspection.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="${1:-$repo_root/agent-improvement/SKILL.md}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check_contract() { # skill
  local flat
  flat="$(tr '\n' ' ' <"$1" | sed -E 's/[[:space:]]+/ /g')"

  grep -Eqi 'rate-based metric.{0,240}baseline (observation volume|numerator.{0,80}denominator)' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}UTC verification-window start' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}UTC not-before timestamp' <<<"$flat" || return 1
  grep -Eqi 'rate-based metric.{0,240}minimum post-change observation volume' <<<"$flat" || return 1
  grep -Eqi 'minimum post-change observation volume.{0,240}(sessions|dispatches|requests|artifacts)' <<<"$flat" || return 1
  grep -Eqi 'evidence generated at or after.{0,120}verification-window start' <<<"$flat" || return 1
  grep -Eqi 'if either floor is unmet.{0,240}NOT-YET-DUE' <<<"$flat" || return 1
  grep -Eqi 'NOT-YET-DUE.{0,240}(no verdict|without applying a verdict)' <<<"$flat" || return 1
  grep -Eqi 'hypothesis.{0,240}continue only.{0,240}cannot affect.{0,160}(signature|metric)' <<<"$flat" || return 1
  grep -Eqi 'state metric.{0,240}(single|one) live inspection.{0,240}(omit|without).{0,120}volume floor' <<<"$flat" || return 1
}

check_coordination_contract() { # skill
  local flat
  flat="$(LC_ALL=C tr '\n' ' ' <"$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[[:space:]]+/ /g')"

  case "$flat" in
    *"cross-instance collision or two-writer race requires evidence identifying at least two distinct writers or instances and the artifact"*"or shared state"*) ;;
    *) return 1 ;;
  esac
  case "$flat" in
    *"absent that distinct-writer provenance, a single session's stale edit"*"reliability or local-state evidence, not a coordination verdict"*) ;;
    *) return 1 ;;
  esac
  case "$flat" in
    *"absent that distinct-writer provenance, a single session's"*"dirty local merge"*"reliability or local-state evidence, not a coordination verdict"*) ;;
    *) return 1 ;;
  esac
  case "$flat" in
    *"second-writer provenance is unavailable"*"unknown"*"do not count it as a collision"* | \
      *"second-writer provenance is unavailable"*"candidate"*"do not count it as a collision"*) ;;
    *) return 1 ;;
  esac
}

fail=0

if check_contract "$skill"; then
  printf '  ✅ live skill defines the hypothesis evidence floor\n'
else
  printf '  ❌ live skill permits an underpowered hypothesis verdict\n' >&2
  fail=1
fi

if check_coordination_contract "$skill"; then
  printf '  ✅ live skill requires two-writer collision evidence\n'
else
  printf '  ❌ live skill permits a single-session collision verdict\n' >&2
  fail=1
fi

coordination_good="$tmp/coordination-good.md"
cat >"$coordination_good" <<'EOF'
A cross-instance collision or two-writer race requires evidence identifying at least two distinct writers
or instances and the artifact or shared state on which they conflicted.
Absent that distinct-writer provenance, a single session's stale edit is reliability or local-state
evidence, not a coordination verdict.
Absent that distinct-writer provenance, a single session's dirty local merge is reliability or
local-state evidence, not a coordination verdict.
When second-writer provenance is unavailable, keep the signal UNKNOWN or candidate-only pending
investigation; do not count it as a collision.
EOF

if check_coordination_contract "$coordination_good"; then
  printf '  ✅ complete coordination evidence contract passes\n'
else
  printf '  ❌ complete coordination evidence contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in positive_requirement distinct_writer positive_conflicted_state conflicted_state provenance_qualification stale_edit dirty_merge local_classification provenance_missing unknown_verdict non_collision; do
  fixture="$tmp/coordination-$missing.md"
  case "$missing" in
    positive_requirement) sed 's/race requires evidence/race does not require evidence/' "$coordination_good" >"$fixture" ;;
    distinct_writer) sed 's/two distinct writers/two writers/' "$coordination_good" >"$fixture" ;;
    positive_conflicted_state) sed 's/instances and the artifact/instances but does not require the artifact/' "$coordination_good" >"$fixture" ;;
    conflicted_state) sed 's/ and the artifact or shared state//' "$coordination_good" >"$fixture" ;;
    provenance_qualification) sed 's/Absent that distinct-writer provenance, //' "$coordination_good" >"$fixture" ;;
    stale_edit) sed '/stale edit/d' "$coordination_good" >"$fixture" ;;
    dirty_merge) sed '/dirty local merge/d' "$coordination_good" >"$fixture" ;;
    local_classification) sed 's/reliability/ordinary/g' "$coordination_good" >"$fixture" ;;
    provenance_missing) sed 's/provenance is unavailable/provenance is observed/' "$coordination_good" >"$fixture" ;;
    unknown_verdict) sed 's/UNKNOWN or candidate-only/a collision/' "$coordination_good" >"$fixture" ;;
    non_collision) sed 's/do not count it as a collision/count it as a collision/' "$coordination_good" >"$fixture" ;;
  esac
  if check_coordination_contract "$fixture"; then
    printf '  ❌ missing coordination %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing coordination %s fails closed\n' "$missing"
  fi
done

good="$tmp/good.md"
cat >"$good" <<'EOF'
For a rate-based metric, record the baseline observation volume, a UTC verification-window start,
a UTC not-before timestamp, and a minimum post-change observation volume in sessions, dispatches,
requests, or artifacts. Count only evidence generated at or after the verification-window start.
If either floor is unmet, record NOT-YET-DUE without applying a verdict. While the hypothesis is
pending, continue only with work that cannot affect its tracked signature or metric. A state metric
that is decisive from one live inspection may omit the volume floor.
EOF

if check_contract "$good"; then
  printf '  ✅ complete eligibility contract passes\n'
else
  printf '  ❌ complete eligibility contract unexpectedly fails\n' >&2
  fail=1
fi

for missing in baseline timestamp verification_start volume post_change polarity no_verdict confounding state_carveout; do
  fixture="$tmp/$missing.md"
  case "$missing" in
    baseline) sed 's/baseline observation volume/baseline count/' "$good" >"$fixture" ;;
    timestamp) sed 's/UTC not-before timestamp/calendar date/' "$good" >"$fixture" ;;
    verification_start) sed 's/UTC verification-window start/change date/' "$good" >"$fixture" ;;
    volume) sed 's/minimum post-change observation volume/minimum wait/' "$good" >"$fixture" ;;
    post_change) sed 's/evidence generated at or after the verification-window start/evidence from the rolling window/' "$good" >"$fixture" ;;
    polarity) sed 's/If either floor is unmet/If either floor is met/' "$good" >"$fixture" ;;
    no_verdict) sed 's/without applying a verdict/and apply the unchanged verdict/' "$good" >"$fixture" ;;
    confounding) sed 's/continue only with work that cannot affect its tracked signature or metric/continue with other authorised work/' "$good" >"$fixture" ;;
    state_carveout) sed 's/A state metric.*//' "$good" >"$fixture" ;;
  esac
  if check_contract "$fixture"; then
    printf '  ❌ missing %s unexpectedly passed\n' "$missing" >&2
    fail=1
  else
    printf '  ✅ missing %s fails closed\n' "$missing"
  fi
done

if [ "$fail" -ne 0 ]; then
  printf '❌ agent-improvement contract test failed\n' >&2
  exit 1
fi

printf '✅ agent-improvement contract test passed\n'
