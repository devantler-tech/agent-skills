#!/usr/bin/env bash
# Configured observation callbacks must stay inert, including at valid trees.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q "$work/repo"
git -C "$work/repo" config user.name 'Observation fixture'
git -C "$work/repo" config user.email fixture@example.invalid
printf '#!/bin/sh\nexit 0\n' > "$work/repo/helper.sh"
git -C "$work/repo" add helper.sh
git -C "$work/repo" -c commit.gpgsign=false commit -qm fixture
revision=$(git -C "$work/repo" rev-parse HEAD)
printf '#!/bin/sh\nprintf executed > "%s"\nprintf "token\\n"\n' "$work/marker" > "$work/hook"
chmod +x "$work/hook"
git -C "$work/repo" config core.fsmonitor "$work/hook"
# Snapshot raw caller files, without an index-consulting observation of our own.
snapshot() {
  shasum "$work/repo/.git/index" "$work/repo/.git/config"
  find "$work/repo/.git/refs" "$work/repo/.git/objects" -type f -exec shasum {} + | LC_ALL=C sort
}
snapshot > "$work/before"
pass=0 fail=0
record() {
  if "$@"; then printf 'PASS: %s\n' "$label"; pass=$((pass+1))
  else printf 'FAIL: %s\n' "$label"; fail=$((fail+1)); fi
}
bash "$here/inspect-shell-helpers.sh" --repo-dir "$work/repo" --revision "$revision" > "$work/disabled"
label='disabled inventory retains no execution authority'
record jq -e '.status=="DISABLED" and .authority=="NONE"' "$work/disabled"
label='disabled inventory never runs the configured hook'; record test ! -e "$work/marker"
bash "$here/inspect-shell-helpers.sh" --inspect --repo-dir "$work/repo" --revision "$revision" > "$work/enabled"
label='enabled inventory retains its exact committed helper'
record jq -e '.status=="OBSERVED" and .authority=="NONE" and .coverage.selectedPaths==1 and .candidates[0].path=="helper.sh"' "$work/enabled"
label='enabled inventory never runs the configured hook'; record test ! -e "$work/marker"
snapshot > "$work/after"
label='observations retain index, configuration, refs and objects'; record cmp "$work/before" "$work/after"
# The harmless callback is executable and its marker would detect execution.
"$work/hook" > "$work/control"
label='configured marker callback is an effective control'; record test -s "$work/marker"
printf 'Observation controls: %s pass, %s fail\n' "$pass" "$fail"
[[ $fail == 0 ]]
