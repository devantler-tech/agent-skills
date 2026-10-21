#!/usr/bin/env bash
# Exercise the two real entrypoints and their single serialized publisher.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for name in cd release publish-skills; do
  yq -o=json '.' "$root/.github/workflows/$name.yaml" >"$scratch/$name.json"
done
jq -n --slurpfile manual "$scratch/cd.json" --slurpfile automatic "$scratch/release.json" \
  --slurpfile publisher "$scratch/publish-skills.json" \
  '{manual:$manual[0],automatic:$automatic[0],publisher:$publisher[0]}' >"$scratch/actual.json"

check() {
  jq -e '
    (.manual.on | keys) == ["workflow_dispatch"] and
    .manual.on.workflow_dispatch.inputs.tag.required == true and
    .manual.on.workflow_dispatch.inputs.tag.type == "string" and
    .manual.permissions == {} and
    .manual.jobs.release.uses == "./.github/workflows/publish-skills.yaml" and
    .manual.jobs.release.with.tag == "${{ inputs.tag }}" and
    .manual.jobs.release.permissions == {contents:"write"} and
    .manual.concurrency == null and
    .automatic.jobs.publish.uses == "./.github/workflows/publish-skills.yaml" and
    .automatic.jobs.publish.with.tag == "${{ needs.version.outputs.tag }}" and
    .automatic.jobs.publish.permissions == {contents:"write"} and
    .automatic.concurrency.group != "publish-skills" and
    (.publisher.on | keys) == ["workflow_call"] and
    .publisher.on.workflow_call.inputs.tag.required == true and
    .publisher.permissions == {} and
    .publisher.concurrency == {group:"publish-skills","cancel-in-progress":false,queue:"max"} and
    .publisher.jobs.release.permissions == {contents:"write"} and
    ([.publisher.jobs.release.steps[] | select(.run? == "./scripts/publish-skills-release.sh --tag \"$TAG\" --expected-commit \"$EXPECTED_COMMIT\"")] |
      length == 1 and .[0].env == {GH_TOKEN:"${{ secrets.GITHUB_TOKEN }}",TAG:"${{ inputs.tag }}",EXPECTED_COMMIT:"${{ github.sha }}"})
  ' "$1" >/dev/null
}
check "$scratch/actual.json" || { echo 'FAIL: both entrypoints must bind the same serialized release publisher' >&2; exit 1; }
for mutation in \
  '.manual.jobs.release.uses = "./.github/workflows/missing.yaml"' \
  '.automatic.jobs.publish.with.tag = "v0.0.0"' \
  '.manual.concurrency = {group:"publish-skills"}' \
  '.publisher.concurrency["cancel-in-progress"] = true' \
  '(.publisher.jobs.release.steps[] | select(.env.EXPECTED_COMMIT)).env.EXPECTED_COMMIT = "main"'; do
  jq "$mutation" "$scratch/actual.json" >"$scratch/mutated.json"
  if check "$scratch/mutated.json"; then
    echo "FAIL: accepted publication boundary mutation: $mutation" >&2
    exit 1
  fi
done
echo 'PASS: two owner-local release entrypoints preserve serialized commit-bound publication'
