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
printf 'package helper\n' > "$tmp/repo/scripts/not.go"
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
parser_dir=$(dirname "$inspect")
GOENV=off GOWORK=off GO111MODULE=off GOTOOLCHAIN=local GOFLAGS='' CGO_ENABLED=0 \
  go test "$parser_dir/go-entrypoint.go" "$parser_dir/go-entrypoint_test.go"
  GIT_INDEX_FILE="$tmp/caller-index" INVENTORY_TEST_CONTEXT_CHILD=1 \
    bash "${BASH_SOURCE[0]}" > "$tmp/inherited-output" 2>&1 || fail 'inherited Git context broke the fixture harness'
  [[ ! -e $tmp/caller-index ]] || fail 'fixture commands wrote the caller index'
printf 'PASS: inherited caller index remains untouched by the fixture harness\n'
fi

# The optional Go observation parses committed syntax, including constrained
# entrypoints, rather than matching main-shaped text or executing init/main.
if [[ ${INVENTORY_TEST_CONTEXT_CHILD:-0} != 1 ]]; then
git init -q "$tmp/go-repo"
git -C "$tmp/go-repo" config user.name test
git -C "$tmp/go-repo" config user.email test@example.invalid
git -C "$tmp/go-repo" config commit.gpgsign false
mkdir -p "$tmp/go-repo/cmd" "$tmp/go-repo/lib"
printf 'package main\nfunc main() { panic("must not execute") }\n' > "$tmp/go-repo/cmd/main.go"
go_weird=$'cmd/quoted" tab\tline\n.go'
printf '//go:build imaginaryplatform\n\npackage main\nfunc main() {}\n' > "$tmp/go-repo/$go_weird"
printf 'package helper\n// package main; func main() {}\nconst text = "func main() {}"\n' > "$tmp/go-repo/lib/helper.go"
printf 'package main\nfunc helper() {}\n' > "$tmp/go-repo/cmd/helper.go"
printf 'package main\nfunc main() {\n' > "$tmp/go-repo/cmd/broken_test.go"
printf 'package helper\ntype T struct{}\nfunc (T) main() {}\n' > "$tmp/go-repo/lib/method.go"
printf 'exit 92\n' > "$tmp/go-repo/task.sh"
git -C "$tmp/go-repo" add -- cmd lib task.sh
git -C "$tmp/go-repo" commit -qm go-fixture
go_revision=$(git -C "$tmp/go-repo" rev-parse HEAD)
go_blob=$(git -C "$tmp/go-repo" rev-parse "$go_revision:cmd/main.go")
last_go_blob=$(git -C "$tmp/go-repo" rev-parse "$go_revision:$go_weird")
git -C "$tmp/go-repo" status --porcelain=v1 > "$tmp/go-status"
git -C "$tmp/go-repo" show-ref > "$tmp/go-refs"
git -C "$tmp/go-repo" ls-files --stage > "$tmp/go-index"
run --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$go_revision" || fail 'explicit Go inspection must observe entrypoints'
jq -e --arg revision "$go_revision" --arg blob "$go_blob" --arg weird "$go_weird" '
  .version == 2 and .status == "OBSERVED" and .authority == "NONE" and .revision == $revision and
  .selection == "tracked-shell-and-go-entrypoints-v1" and .coverage.selectedPaths == 3 and
  .coverage.goFilesExamined == 5 and .coverage.goPrograms == "ENTRYPOINT_FILES_ONLY" and
  .coverage.buildability == "NOT_ASSERTED" and .coverage.callers == "UNKNOWN" and
  .coverage.portfolio == "NOT_ASSERTED" and
  ([.candidates[].path]|sort) == (["cmd/main.go",$weird,"task.sh"]|sort) and
  any(.candidates[]; .path == "cmd/main.go" and .blob == $blob and .kind == "go-entrypoint") and
  all(.candidates[]; .callers == "UNKNOWN" and .destination == "UNASSESSED")
' "$tmp/out" >/dev/null || fail 'Go syntax observation or evidence boundary is wrong'
cp "$tmp/out" "$tmp/go-observed"
git -C "$tmp/go-repo" status --porcelain=v1 > "$tmp/go-status-after"
git -C "$tmp/go-repo" show-ref > "$tmp/go-refs-after"
git -C "$tmp/go-repo" ls-files --stage > "$tmp/go-index-after"
if ! cmp "$tmp/go-status" "$tmp/go-status-after" || ! cmp "$tmp/go-refs" "$tmp/go-refs-after" ||
  ! cmp "$tmp/go-index" "$tmp/go-index-after"; then fail 'inspection modified caller state'; fi
printf 'PASS: parsed Go entrypoints, constrained and escaped paths, no source execution or caller mutation\n'
printf 'invalid dirty content\n' > "$tmp/go-repo/cmd/main.go"
printf 'package main\nfunc main() {}\n' > "$tmp/go-repo/untracked.go"
run --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$go_revision"
cmp "$tmp/out" "$tmp/go-observed" || fail 'dirty Go source changed committed evidence'
printf 'PASS: Go observation excludes dirty and untracked source\n'
PATH="$tmp/empty-path" "$bash_bin" "$inspect" --include-go > "$tmp/out"
jq -e '.status == "DISABLED" and .authority == "NONE"' "$tmp/out" >/dev/null
printf 'PASS: Go opt-in cannot implicitly enable repository inspection\n'
cat > "$tmp/bin/git" <<'STUB'
#!/usr/bin/env bash
if [[ " $* " == *' ls-tree '* && $FAIL_GIT_COMMAND == truncated-tree ]]; then
  printf '100644 blob %040d\tcmd/main.go' 0
  exit 0
fi
if [[ " $* " == *' ls-tree '* && $FAIL_GIT_COMMAND == empty-tree ]]; then exit 0; fi
if [[ " $* " == *' ls-tree '* && $FAIL_GIT_COMMAND == prefix-tree ]]; then
  "$REAL_GIT" "$@" > "$PREFIX_OUTPUT" || exit $?
  for ((index=0; index<2; index++)); do
    IFS= read -r -d '' entry || exit 74
    printf '%s\0' "$entry"
  done < "$PREFIX_OUTPUT"
  exit 0
fi
if [[ " $* " == *' diff-tree '* ]]; then
  case $FAIL_GIT_COMMAND in
    empty-diff) exit 0 ;;
    truncated-diff) printf ':000000 100644'; exit 0 ;;
    prefix-diff)
      "$REAL_GIT" "$@" > "$PREFIX_OUTPUT" || exit $?
      for ((index=0; index<4; index++)); do
        IFS= read -r -d '' entry || exit 74
        printf '%s\0' "$entry"
      done < "$PREFIX_OUTPUT"
      exit 0 ;;
  esac
fi
if [[ " $* " == *" cat-file blob $TARGET_BLOB "* ]]; then
  case $FAIL_GIT_COMMAND in
    failed-source) exit 73 ;;
    partial-source) printf 'package helper\n'; exit 0 ;;
    record-source) touch "$READ_MARKER" ;;
  esac
fi
exec "$REAL_GIT" "$@"
STUB
for operation in truncated-tree empty-tree prefix-tree empty-diff truncated-diff prefix-diff failed-source partial-source; do
  REAL_GIT="$git_bin" TARGET_BLOB="$last_go_blob" PREFIX_OUTPUT="$tmp/prefix-tree" FAIL_GIT_COMMAND="$operation" PATH="$tmp/bin:$PATH" \
    refuse --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$go_revision"
done
for operation in truncated-tree empty-tree prefix-tree empty-diff truncated-diff prefix-diff; do
  REAL_GIT="$git_bin" PREFIX_OUTPUT="$tmp/prefix-tree" FAIL_GIT_COMMAND="$operation" PATH="$tmp/bin:$PATH" \
    refuse --inspect --repo-dir "$tmp/go-repo" --revision "$go_revision"
done
printf 'PASS: failed, partial or unterminated Git observations emit no partial success\n'
printf 'package main\nfunc main(){}\n' > "$tmp/large.go"
head -c 4194305 /dev/zero | tr '\0' ' ' >> "$tmp/large.go"
large_blob=$(git -C "$tmp/go-repo" hash-object -w --stdin < "$tmp/large.go")
large_tree=$(printf '100644 blob %s\ta.go\000100644 blob %s\tz-large.go\0' "$go_blob" "$large_blob" | git -C "$tmp/go-repo" mktree -z)
large_revision=$(git -C "$tmp/go-repo" commit-tree "$large_tree" -m large-source)
REAL_GIT="$git_bin" TARGET_BLOB="$large_blob" FAIL_GIT_COMMAND=record-source READ_MARKER="$tmp/materialized-large-source" PATH="$tmp/bin:$PATH" \
  refuse --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$large_revision"
[[ ! -e $tmp/materialized-large-source ]] || fail 'oversized Go source must be refused before materializing its bytes'
printf 'PASS: oversized Go source is refused before materialization, after a healthy entrypoint\n'
ln -s cmd/main.go "$tmp/go-repo/link.go"
git -C "$tmp/go-repo" add -- link.go
git -C "$tmp/go-repo" commit -qm go-symlink
go_link_revision=$(git -C "$tmp/go-repo" rev-parse HEAD)
refuse --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$go_link_revision"
printf 'PASS: selected Go symlinks are unsupported coverage\n'
git -C "$tmp/go-repo" rm -q -- link.go
git -C "$tmp/go-repo" commit -qm remove-fixture-link
printf 'package main\nfunc main(\n' > "$tmp/go-repo/broken.go"
git -C "$tmp/go-repo" add -- broken.go
git -C "$tmp/go-repo" commit -qm malformed
bad_go_revision=$(git -C "$tmp/go-repo" rev-parse HEAD)
refuse --inspect --include-go --repo-dir "$tmp/go-repo" --revision "$bad_go_revision"
run --inspect --repo-dir "$tmp/go-repo" --revision "$bad_go_revision"
jq -e '.version == 1 and .coverage.goPrograms == "NOT_EXAMINED" and .coverage.selectedPaths == 1' "$tmp/out" >/dev/null
printf 'PASS: malformed Go refuses incomplete opt-in evidence while shell-only behavior stays compatible\n'
fi
