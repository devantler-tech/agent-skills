#!/usr/bin/env bash
# Keep this consumer's documentation scan runnable, bounded, and required.
set -euo pipefail

root="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
yq -o=json '.' "$root/.github/workflows/ci.yaml" >"$work/ci.json"
if [[ -f "$root/.github/retired-repo-links.json" ]]; then
  cp "$root/.github/retired-repo-links.json" "$work/config.json"
else
  printf 'null\n' >"$work/config.json"
fi
jq -n --slurpfile ci "$work/ci.json" --slurpfile config "$work/config.json" \
  '{ci:$ci[0],config:$config[0]}' >"$work/bundle.json"

guard() {
  jq -e '
    def runnable: .if == null and (.["continue-on-error"] // false) == false;
    .ci as $ci | $ci.jobs["validate-retired-links"] as $job |
    if .config != {version:1,repositories:["devantler-tech/reusable-workflows"],paths:["README.md","AGENTS.md"],exceptions:[]}
    then error("consumer scope must be explicit and bounded")
    elif $ci.permissions != {} or $job == null or $job.permissions != {contents:"read"} or
      ($job | runnable | not) or $job.needs != null or
      ($job | tostring | test("secrets|github[.]token|create-github-app-token";"i"))
    then error("consumer scan must execute without write credentials")
    elif ([$job.steps[] | select(.id == "links") |
      select(runnable and .with.enabled == "true" and
        ((.uses // "") | test("^devantler-tech/[.]github/actions/validate-retired-repo-links@[0-9a-f]{40}$")))] | length) != 1
    then error("released consumer action must execute explicitly enabled")
    elif ([$job.steps[] | select(.name == "Require a complete scan") |
      select(runnable and .env.VALIDATED == "${{ steps.links.outputs.validated }}" and
        .run == "test \"$VALIDATED\" = true")] | length) != 1
    then error("consumer scan must prove complete validation")
    elif ($ci.jobs["ci-required-checks"].needs | index("validate-retired-links")) == null or
      ($ci.jobs["ci-required-checks"].steps | any(.with["job-results"] // "" |
        contains("needs.validate-retired-links.result"))) != true
    then error("consumer scan must gate required CI")
    else true end' "$1" >/dev/null
}

guard "$work/bundle.json"
count=0
while IFS=$'\t' read -r label mutation diagnostic; do
  jq "$mutation" "$work/bundle.json" >"$work/mutated.json"
  if guard "$work/mutated.json" >"$work/result" 2>&1; then
    echo "FAIL: $label was accepted" >&2
    exit 1
  fi
  grep -qF "$diagnostic" "$work/result"
  count=$((count + 1))
done <<'CASES'
missing config	.config=null	explicit and bounded
broadened scope	.config.paths += ["."]	explicit and bounded
historical bypass	.config.exceptions=[{}]	explicit and bounded
skipped job	.ci.jobs["validate-retired-links"].if="false"	execute without write
write access	.ci.jobs["validate-retired-links"].permissions.contents="write"	execute without write
disabled caller	.ci.jobs["validate-retired-links"].steps |= map(if .id == "links" then .with.enabled="false" else . end)	explicitly enabled
action bypass	.ci.jobs["validate-retired-links"].steps |= map(if .id == "links" then del(.uses) | .run="echo PASS" else . end)	explicitly enabled
lost success proof	.ci.jobs["validate-retired-links"].steps |= map(select(.name != "Require a complete scan"))	complete validation
lost aggregation	.ci.jobs["ci-required-checks"].needs |= map(select(. != "validate-retired-links"))	gate required CI
lost result	.ci.jobs["ci-required-checks"].steps |= map(if .with["job-results"] then .with["job-results"] |= gsub("needs.validate-retired-links.result";"needs.other.result") else . end)	gate required CI
CASES
echo "PASS: consumer wiring rejects $count independent regressions"

[[ $# == 0 ]] && exit 0
[[ $# == 1 && -x "$1" ]] || { echo 'Expected one executable released validator' >&2; exit 1; }
validator="$1"
"$validator" --root "$root" >"$work/clean.log" 2>&1
cat "$work/clean.log"
mkdir -p "$work/fixture/.github"
cp "$root/README.md" "$root/AGENTS.md" "$work/fixture/"
cp "$root/.github/retired-repo-links.json" "$work/fixture/.github/"
printf '\n[Retired-link fixture](https://github.com/devantler-tech/reusable-workflows)\n' >>"$work/fixture/README.md"
result=0
"$validator" --root "$work/fixture" >"$work/negative.log" 2>&1 || result=$?
[[ "$result" == 1 ]]
grep -E '^README.md:[0-9]+: link targets retired repository devantler-tech/reusable-workflows$' "$work/negative.log"
rm "$work/fixture/.github/retired-repo-links.json"
result=0
"$validator" --root "$work/fixture" >"$work/missing.log" 2>&1 || result=$?
[[ "$result" == 2 ]]
grep -qF 'configuration' "$work/missing.log"
echo 'PASS: released validator accepts clean documentation and rejects the seeded link and missing configuration'
