#!/usr/bin/env bash
# Regression targets: false empty census, working-tree leakage, implicit inspection,
# shell execution, path splitting and replacement-object substitution.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX
inspect=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/inspect-shell-helpers.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Report the violated behavior and stop the fixture suite.
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
# Exercise the actual installed command while retaining both output streams.
run() { bash "$inspect" "$@" > "$tmp/out" 2> "$tmp/err"; }
# A refused observation must return UNKNOWN without a success payload.
refuse() {
  local code=0
  run "$@" || code=$?
  [[ $code == 2 && ! -s $tmp/out && -s $tmp/err ]] || fail 'refusal must be UNKNOWN without success output'
}
if [[ ! -f $inspect ]]; then fail 'missing inventory: explicit opt-in must produce revision-bound observations'; fi

# The default must work without Git, jq, or even a repository.
mkdir "$tmp/empty-path"
bash_bin=$(command -v bash)
PATH="$tmp/empty-path" "$bash_bin" "$inspect" > "$tmp/out"
jq -e '.status == "DISABLED" and .authority == "NONE"' "$tmp/out" >/dev/null
printf 'PASS: default-off without repository dependencies\n'

git init -q "$tmp/repo"
git -C "$tmp/repo" config user.name 'Inventory test'
git -C "$tmp/repo" config user.email 'inventory@example.invalid'
git -C "$tmp/repo" config commit.gpgsign false
mkdir "$tmp/repo/scripts"
printf '#!/usr/bin/env bash\nexit 91\n' > "$tmp/repo/scripts/a.sh"
printf 'test-only\n' > "$tmp/repo/scripts/a.test.sh"
printf 'not-shell\n' > "$tmp/repo/scripts/not.go"
weird=$'scripts/quoted" tab\tline\n.sh'
printf 'do not run\n' > "$tmp/repo/$weird"
chmod +x "$tmp/repo/scripts/a.sh"
git -C "$tmp/repo" add -- scripts
git -C "$tmp/repo" commit -qm fixture
revision=$(git -C "$tmp/repo" rev-parse HEAD)
blob=$(git -C "$tmp/repo" rev-parse "$revision:scripts/a.sh")
run --inspect --repo-dir "$tmp/repo" --revision "$revision"
jq -e --arg revision "$revision" --arg blob "$blob" --arg weird "$weird" '
  .status == "OBSERVED" and .authority == "NONE" and .revision == $revision and
  .selection == "tracked-shell-paths-v1" and .coverage.selectedPaths == 2 and
  .coverage.callers == "UNKNOWN" and .coverage.goPrograms == "NOT_EXAMINED" and
  .coverage.portfolio == "NOT_ASSERTED" and
  ([.candidates[].path] | sort) == (["scripts/a.sh", $weird] | sort) and
  any(.candidates[]; .path == "scripts/a.sh" and .blob == $blob and .executable == true) and
  all(.candidates[]; .callers == "UNKNOWN" and .destination == "UNASSESSED")
' "$tmp/out" >/dev/null || fail 'exact committed paths, blob and unresolved usage'
cp "$tmp/out" "$tmp/observed"
printf 'PASS: real Git census, escaped paths and no inspected execution\n'

printf 'uncommitted\n' > "$tmp/repo/scripts/a.sh"
printf 'untracked\n' > "$tmp/repo/scripts/new.sh"
run --inspect --repo-dir "$tmp/repo" --revision "$revision"
cmp "$tmp/out" "$tmp/observed" || fail 'working-tree content changed committed inventory'
printf 'PASS: dirty working tree cannot alter committed evidence\n'

refuse --inspect --repo-dir "$tmp/repo" --revision HEAD
refuse --inspect --repo-dir "$tmp/repo" --revision "${revision:0:10}"
refuse --inspect --repo-dir "$tmp/repo" --revision "$(printf '%040d' 0)"
refuse --inspect --repo-dir "$tmp/repo/scripts" --revision "$revision"
refuse --inspect --repo-dir "$tmp/repo" --revision "$blob"
refuse --inspect --repo-dir "$tmp/repo" --revision
refuse --unexpected
printf 'PASS: unresolved revisions and wrong roots fail closed\n'

# Successful empty scope is distinguished from a failed tree read.
git init -q "$tmp/empty-repo"
git -C "$tmp/empty-repo" -c user.name=test -c user.email=test@example.invalid \
  -c commit.gpgsign=false commit --allow-empty -qm empty
empty_revision=$(git -C "$tmp/empty-repo" rev-parse HEAD)
run --inspect --repo-dir "$tmp/empty-repo" --revision "$empty_revision"
jq -e '.status == "OBSERVED" and .coverage.selectedPaths == 0 and .candidates == []' "$tmp/out" >/dev/null
printf 'PASS: actual empty committed scope\n'
GIT_DIR="$tmp/empty-repo/.git" GIT_WORK_TREE="$tmp/repo" \
  run --inspect --repo-dir "$tmp/repo" --revision "$revision"
cmp "$tmp/out" "$tmp/observed" || fail 'ambient Git directory redirected the observation'
printf 'PASS: ambient Git context cannot redirect the named repository\n'

git_bin=$(command -v git)
mkdir "$tmp/bin"
cat > "$tmp/bin/git" <<'STUB'
#!/usr/bin/env bash
for arg do
  if [[ $arg == "$FAIL_GIT_COMMAND" ]]; then exit 73; fi
done
if [[ $FAIL_GIT_COMMAND == selected-blob && " $* " == *' cat-file -e '* ]]; then exit 73; fi
exec "$REAL_GIT" "$@"
STUB
chmod +x "$tmp/bin/git"
for operation in ls-tree cat-file selected-blob --no-lazy-fetch; do
  REAL_GIT="$git_bin" FAIL_GIT_COMMAND="$operation" PATH="$tmp/bin:$PATH" \
    refuse --inspect --repo-dir "$tmp/repo" --revision "$revision"
done
printf 'PASS: failed tree and object reads never emit an empty success\n'

bad_tree=$(printf '100644 blob %s\t%s\0' "$blob" $'invalid-\xff.sh' | git -C "$tmp/repo" mktree -z)
bad_revision=$(git -C "$tmp/repo" commit-tree "$bad_tree" -p "$revision" -m invalid-path)
refuse --inspect --repo-dir "$tmp/repo" --revision "$bad_revision"
printf 'PASS: invalid UTF-8 cannot be silently renamed by JSON encoding\n'

# A local replace ref must not alter the meaning of the named commit.
git -C "$tmp/repo" fetch -q "$tmp/empty-repo" HEAD
git -C "$tmp/repo" replace "$revision" "$empty_revision"
run --inspect --repo-dir "$tmp/repo" --revision "$revision"
cmp "$tmp/out" "$tmp/observed" || fail 'replace ref changed exact-revision observation'
printf 'PASS: replacement refs cannot rewrite named evidence\n'

ln -s a.sh "$tmp/repo/scripts/link.sh"
git -C "$tmp/repo" add -- scripts/link.sh
git -C "$tmp/repo" commit -qm symlink
link_revision=$(git -C "$tmp/repo" --no-replace-objects rev-parse HEAD)
refuse --inspect --repo-dir "$tmp/repo" --revision "$link_revision"
printf 'PASS: selected symlinks refuse unsupported coverage\n'

# Exercise this fixture harness as a caller with a redirected index. Removing
# its initial environment scrub must fail instead of writing that caller file.
if [[ ${INVENTORY_TEST_CONTEXT_CHILD:-0} != 1 ]]; then
  GIT_INDEX_FILE="$tmp/caller-index" INVENTORY_TEST_CONTEXT_CHILD=1 \
    bash "${BASH_SOURCE[0]}" > "$tmp/inherited-output" 2>&1 || fail 'inherited Git context broke the fixture harness'
  [[ ! -e $tmp/caller-index ]] || fail 'fixture commands wrote the caller index'
  printf 'PASS: inherited caller index remains untouched by the fixture harness\n'
fi
