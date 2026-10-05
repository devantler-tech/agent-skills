#!/usr/bin/env bash
# Canonical tree components must be observed before flattened paths can prove coverage.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0 fail=0
# Preserve all results so malformed and valid controls run against the same object store.
record() {
  if "$@"; then printf 'PASS: %s\n' "$label"; pass=$((pass + 1))
  else printf 'FAIL: %s\n' "$label"; fail=$((fail + 1)); fi
}
git init -q "$work/repo"
git -C "$work/repo" config user.name 'Tree integrity fixture'
git -C "$work/repo" config user.email fixture@example.invalid
git -C "$work/repo" config commit.gpgsign false
blob=$(printf 'do not execute\n' | git -C "$work/repo" hash-object -w --stdin)
# Write Git's binary tree representation directly; mktree refuses malformed components.
raw_tree() {
  local mode=$1 name=$2 object=$3 i
  printf '%s %s\0' "$mode" "$name"
  for ((i=0; i<${#object}; i+=2)); do printf '%b' "\\x${object:i:2}"; done
}
# Invoke the real installed observer and retain both streams and the native exit code.
observe() {
  status=0
  bash "$here/inspect-shell-helpers.sh" --inspect --repo-dir "$work/repo" \
    --revision "$1" > "$work/out" 2> "$work/error" || status=$?
}
# UNKNOWN must never carry a partial success report.
refused() { [[ $status == 2 && ! -s $work/out ]] && grep -q '^UNKNOWN:' "$work/error"; }
# A nested path remains legitimate even though its flattened spelling contains a slash.
raw_tree 100644 $'quoted" tab\tline\n.sh' "$blob" > "$work/nested.tree"
nested=$(git -C "$work/repo" hash-object -t tree -w "$work/nested.tree")
printf '040000 tree %s\tfolder\0' "$nested" | git -C "$work/repo" mktree -z > "$work/root"
root=$(cat "$work/root")
valid=$(printf 'valid nested fixture\n' | git -C "$work/repo" commit-tree "$root")
observe "$valid"
label='nested whitespace path retains exact committed identity'
# shellcheck disable=SC2016 # These variables belong to jq.
record jq -e --arg path $'folder/quoted" tab\tline\n.sh' --arg blob "$blob" \
  '.status=="OBSERVED" and .coverage.selectedPaths==1 and .candidates[0].path==$path and .candidates[0].blob==$blob' "$work/out"

for name in ../escape.sh folder/slashed.sh . .. .git; do
  raw_tree 100644 "$name" "$blob" > "$work/raw.tree"
  tree=$(git -C "$work/repo" hash-object --literally -t tree -w "$work/raw.tree")
  revision=$(printf 'malformed component fixture\n' | git -C "$work/repo" commit-tree "$tree")
  observe "$revision"
  label="malformed component refuses: $name"
  record refused
  # Every reachable subtree needs validation, including nonselected components.
  printf '040000 tree %s\tnested\0' "$tree" | git -C "$work/repo" mktree -z > "$work/nested-root"
  revision=$(printf 'nested malformed fixture\n' | git -C "$work/repo" commit-tree "$(cat "$work/nested-root")")
  observe "$revision"
  label="nested malformed component refuses: $name"
  record refused
done
observe "$valid"
label='unrelated malformed objects do not invalidate the selected valid tree'
record jq -e '.status=="OBSERVED" and .coverage.selectedPaths==1' "$work/out"

# Failed and substituted raw-object reads cannot masquerade as complete tree inspection.
real_git=$(command -v git)
mkdir "$work/bin"
cat > "$work/bin/git" <<'STUB'
#!/usr/bin/env bash
if [[ " $* " == *' cat-file tree '* ]]; then
  if [[ $MODE == partial ]]; then "$REAL_GIT" "$@"; exit 73; fi
  exit 0
fi
exec "$REAL_GIT" "$@"
STUB
chmod +x "$work/bin/git"
for mode in partial substituted; do
  MODE=$mode REAL_GIT=$real_git PATH="$work/bin:$PATH" observe "$valid"
  label="$mode raw-tree read refuses without success"
  record refused
done
printf 'Tree integrity controls: %s pass, %s fail\n' "$pass" "$fail"
[[ $fail == 0 ]]
