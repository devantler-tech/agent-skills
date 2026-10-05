#!/usr/bin/env bash
# Actual installed census: exact roots and full SHA1/SHA256 commits.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
helper="$here/inspect-shell-helpers.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0
# Retain stdout and refusal status; a false successful observation must fail.
refuse() {
 local status=0
 bash "$helper" --inspect --repo-dir "$1" --revision "$2" > "$work/out" 2> "$work/err" || status=$?
 if [[ $status != 2 || -s $work/out || ! -s $work/err ]]; then printf 'FAIL: %s\n' "$3" >&2; failed=$((failed+1)); fi
}
plain="$work/repo"
newline="$plain"$'\n'
for path in "$plain" "$newline"; do
 git init -q "$path"
 git -C "$path" config user.name test
 git -C "$path" config user.email test@example.invalid
 git -C "$path" config commit.gpgsign false
 printf '# %s\nexit 99\n' "$path" > "$path/local.sh"
 git -C "$path" add -- local.sh
 git -C "$path" commit -qm "$path"
done
foreign=$(git -C "$plain" rev-parse HEAD)
requested=$(git -C "$newline" rev-parse HEAD)
if git -C "$newline" cat-file -e "$foreign^{commit}" 2>/dev/null; then
 printf 'FAIL: independent repository fixture has the foreign commit\n' >&2; exit 1
fi
bash "$helper" --inspect --repo-dir "$plain" --revision "$foreign" > "$work/out"
jq -e --arg revision "$foreign" '.status=="OBSERVED" and .revision==$revision' "$work/out" >/dev/null
refuse "$newline" "$foreign" 'newline root must never observe its adjacent repository'
bash "$helper" --inspect --repo-dir "$newline" --revision "$requested" > "$work/out" 2> "$work/err" || {
 printf 'FAIL: exact newline repository must remain observable\n' >&2; failed=$((failed+1))
}
if ! jq -e --arg revision "$requested" '.status=="OBSERVED" and .revision==$revision and .coverage.selectedPaths==1' "$work/out" >/dev/null; then
 printf 'FAIL: exact requested repository identity\n' >&2; failed=$((failed+1))
fi
mkdir "$work/installed" "$work/installed"$'\n'
cp "$here/go-entrypoint.go" "$work/installed/"
cp "$helper" "$work/installed"$'\n'/
printf 'invalid installed source\n' > "$work/installed"$'\n'"/go-entrypoint.go"
printf 'package main\nfunc main() { panic("never run") }\n' > "$plain/main.go"
git -C "$plain" add -- main.go
git -C "$plain" commit -qm parser-control
full=$(git -C "$plain" rev-parse HEAD)
status=0
bash "$work/installed"$'\n'"/inspect-shell-helpers.sh" --inspect --include-go --repo-dir "$plain" --revision "$full" > "$work/out" 2> "$work/err" || status=$?
if [[ $status != 2 || -s $work/out || ! -s $work/err ]]; then
 printf 'FAIL: newline installed directory must not select its adjacent parser\n' >&2; failed=$((failed+1))
fi
git init -q --object-format=sha256 "$work/sha256"
git -C "$work/sha256" config user.name test
git -C "$work/sha256" config user.email test@example.invalid
git -C "$work/sha256" config commit.gpgsign false
printf 'exit 99\n' > "$work/sha256/task.sh"
git -C "$work/sha256" add -- task.sh
git -C "$work/sha256" commit -qm sha256
sha=$(git -C "$work/sha256" rev-parse HEAD)
[[ ${#sha} == 64 ]]
bash "$helper" --inspect --repo-dir "$work/sha256" --revision "$sha" > "$work/out"
jq -e --arg revision "$sha" '.status=="OBSERVED" and .revision==$revision' "$work/out" >/dev/null
refuse "$work/sha256" "${sha:0:40}" 'SHA256 prefix must never become exact evidence'
for bytes in $'\364\220\200\200' $'\370\210\200\200\200' $'\374\204\200\200\200\200'; do
  path="task-$bytes.sh"
  blob=$(printf 'exit 99\n' | git -C "$plain" hash-object -w --stdin)
  tree=$(printf '100644 blob %s\t%s\0' "$blob" "$path" | git -C "$plain" mktree -z)
  full=$(printf 'range-fixture\n' | git -C "$plain" commit-tree "$tree")
  refuse "$plain" "$full" 'out-of-range committed path cannot be repaired into a census'
done
[[ $failed == 0 ]] || exit 1
printf 'PASS: exact repository roots, installed parser paths and full commit IDs\n'
