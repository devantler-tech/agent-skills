#!/usr/bin/env bash
# Real Git objects with repeated paths must never produce a successful census.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q "$work/repo"
git -C "$work/repo" config user.name Fixture
git -C "$work/repo" config user.email fixture@example.invalid
git -C "$work/repo" config commit.gpgsign false
git -C "$work/repo" commit --allow-empty -qm root
first=$(printf 'exit 91\n' | git -C "$work/repo" hash-object -w --stdin)
second=$(printf 'exit 92\n' | git -C "$work/repo" hash-object -w --stdin)
failed=0 passed=0
# Check unknown status, absent success output and an explanatory refusal.
refuse() {
  local rc=0
  bash "$here/inspect-shell-helpers.sh" --inspect "${args[@]}" --repo-dir "$work/repo" --revision "$revision" > "$work/out" 2> "$work/err" || rc=$?
  if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then passed=$((passed+1))
  else printf 'FAIL repeated %s %s %s\n' "$mode" "$kind" "$path"; failed=$((failed+1)); fi
}
for mode in shell go; do
  args=()
  [[ $mode != go ]] || args=(--include-go)
  for kind in identical conflicting; do
    other=$first
    [[ $kind != conflicting ]] || other=$second
    for path in task.sh unselected.txt $'new\nline.sh'; do
      # Store NUL records in a file, never a shell variable.
      printf '100644 blob %s\t%s\0' "$first" "$path" > "$work/tree"
      printf '100644 blob %s\t%s\0' "$other" "$path" >> "$work/tree"
      tree=$(git -C "$work/repo" mktree -z < "$work/tree")
      revision=$(printf 'Repeated path\n' | git -C "$work/repo" commit-tree "$tree")
      refuse
    done
  done
done
# Unique byte-exact newline and whitespace names remain supported.
printf '100644 blob %s\t%s\0' "$first" ' task.sh ' > "$work/tree"
printf '100644 blob %s\t%s\0' "$first" $'new\nline.sh' >> "$work/tree"
tree=$(git -C "$work/repo" mktree -z < "$work/tree")
revision=$(printf 'Unique paths\n' | git -C "$work/repo" commit-tree "$tree")
bash "$here/inspect-shell-helpers.sh" --inspect --repo-dir "$work/repo" --revision "$revision" > "$work/out"
jq -e '.status=="OBSERVED" and .coverage.selectedPaths==1 and .candidates[0].path=="new\nline.sh"' "$work/out" >/dev/null
passed=$((passed+1))
printf 'committed path uniqueness: %s passes, %s failures\n' "$passed" "$failed"
[[ $failed == 0 ]]

