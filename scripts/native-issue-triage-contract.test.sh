#!/usr/bin/env bash
# Definition-drift controls, not a model-behavior evaluation.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
finished=0
# Remove only this fixture and preserve failures, including Bash 3.2 aborts.
cleanup() {
  local rc=$?
  rm -rf "$tmp"
  if [[ "$finished" != 1 && "$rc" == 0 ]]; then rc=1; fi
  exit "$rc"
}
trap cleanup EXIT

# Check the operative strategy and triage sections, without searching later examples.
check() {
  local file=$1 strategy triage
  [[ -s "$file" ]] || return 1
  strategy=$(awk '/^## 1\. Strategy & roadmaps$/{selected=1;next} /^## 2\./{exit} selected{print}' "$file" | tr '\n' ' ' | tr -s '[:space:]')
  triage=$(awk '/^## 2\. Issue triage & capture$/{selected=1;next} /^## 3\./{exit} selected{print}' "$file" | tr '\n' ' ' | tr -s '[:space:]')
  [[ "$strategy" == *'Prefer native issue types when supported'* ]] || return 1
  [[ "$strategy" == *"consumer's definitions for epics and actionable children"* ]] || return 1
  [[ "$strategy" == *'Retain cross-cutting labels'* ]] || return 1
  [[ "$strategy" == *'classification labels are a fallback only where native types are unavailable'* ]] || return 1
  [[ "$triage" == *'Optional label absence alone is not incomplete triage'* ]] || return 1
  [[ "$triage" == *'Incomplete metadata reads remain UNKNOWN'* ]] || return 1
  [[ "$triage" == *'PR metadata comes from the consumer contract, not issue types'* ]] || return 1
  [[ "$strategy" != *"Epic/theme-level items carry a \`roadmap\` label"* ]] || return 1
}

source_file="$root/product-engineering/SKILL.md"
check "$source_file" || {
  printf 'FAIL: product strategy/triage still assumes duplicate classification labels\n' >&2
  exit 1
}
passed=0
for clause in \
  'Prefer native issue types when supported' \
  "consumer's definitions for epics and actionable children" \
  'Retain cross-cutting labels' \
  'classification labels are a fallback only where native types are unavailable' \
  'Optional label absence alone is not incomplete triage' \
  'Incomplete metadata reads remain UNKNOWN' \
  'PR metadata comes from the consumer contract, not issue types'; do
  awk -v clause="$clause" 'index($0,clause)==0' "$source_file" >"$tmp/removed.md"
  if check "$tmp/removed.md"; then
    printf 'FAIL: removed obligation accepted: %s\n' "$clause" >&2
    exit 1
  fi
  passed=$((passed + 1))
done
awk '{print} /^## 1\. Strategy & roadmaps$/{print "Epic/theme-level items carry a `roadmap` label."}' "$source_file" >"$tmp/contradiction.md"
if check "$tmp/contradiction.md"; then
  printf 'FAIL: obsolete classification instruction accepted\n' >&2
  exit 1
fi
passed=$((passed + 1))
printf 'PASS: operative native triage definition and %s mutation controls\n' "$passed"
finished=1
