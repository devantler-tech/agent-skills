#!/usr/bin/env bash
# Observe shell paths and optional Go entrypoints in Git objects; never run surveyed code.
set -euo pipefail
# Report an incomplete observation without emitting a successful census.
unknown() { printf 'UNKNOWN: %s\n' "$*" >&2; exit 2; }
enabled=false
include_go=false
repo=
revision=
while (($#)); do
  case $1 in
    --inspect) enabled=true; shift ;;
    --include-go) include_go=true; shift ;;
    --repo-dir|--revision)
      (($# >= 2)) || unknown "missing value for $1"
      [[ -n $2 ]] || unknown "empty value for $1"
      case $1 in
        --repo-dir) [[ -z $repo ]] || unknown 'duplicate repository'; repo=$2 ;;
        --revision) [[ -z $revision ]] || unknown 'duplicate revision'; revision=$2 ;;
      esac
      shift 2 ;;
    --help)
      printf '%s\n' 'Usage: bash inspect-shell-helpers.sh --inspect [--include-go] --repo-dir ROOT --revision FULL_COMMIT' \
        'Without --inspect: DISABLED, no repository reads. Enabled: committed *.sh paths except *.test.sh.' \
        '--include-go: also parse non-test *.go blobs for package main entrypoint files; requires Go.'
      exit 0 ;;
    *) unknown 'unrecognized argument' ;;
  esac
done
if [[ $enabled == false ]]; then
  printf '%s\n' '{"status":"DISABLED","authority":"NONE"}'
  exit 0
fi
[[ -n $repo && -n $revision ]] || unknown 'repository root and exact revision are required'
[[ $revision =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || unknown 'revision must be a full lowercase commit identifier'
for dependency in git jq mktemp iconv; do
  command -v "$dependency" >/dev/null || unknown "missing dependency: $dependency"
done
repo=$(cd "$repo" 2>/dev/null && pwd -P) || unknown 'repository directory is unavailable'
# No checkout, filters, replacement objects or automatic promisor fetches.
export GIT_NO_LAZY_FETCH=1
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
# Explicit no-fetch capability is required; unsupported Git refuses before reads.
read_git() { git --no-lazy-fetch --no-replace-objects --no-optional-locks -C "$repo" "$@"; }
top=$(read_git rev-parse --show-toplevel 2>/dev/null) || unknown 'not a worktree repository'
top=$(cd "$top" && pwd -P) || unknown 'repository root is unavailable'
[[ $top == "$repo" ]] || unknown 'repo-dir must be the repository root'
kind=$(read_git cat-file -t "$revision" 2>/dev/null) || unknown 'commit object is unavailable'
[[ $kind == commit ]] || unknown 'revision is not a commit'
umask 077
tmp=$(mktemp -d) || unknown 'temporary observation directory is unavailable'
trap 'rm -rf "$tmp"' EXIT
read_git ls-tree -r -z "$revision" > "$tmp/tree" 2>/dev/null || unknown 'committed tree could not be read'
if [[ $include_go == true ]]; then
  command -v go >/dev/null || unknown 'missing dependency: go'
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || unknown 'installed helper directory is unavailable'
  # Compile only this installed parser, never a surveyed package or its dependencies.
  GOENV=off GOWORK=off GO111MODULE=off GOTOOLCHAIN=local GOFLAGS='' CGO_ENABLED=0 \
    GOOS='' GOARCH='' GOCACHEPROG='' GOTMPDIR="$tmp" \
    go build -o "$tmp/go-entrypoint" "$script_dir/go-entrypoint.go" 2>/dev/null || unknown 'installed Go parser could not be built'
fi
go_files_examined=0
: > "$tmp/candidates"
while IFS= read -r -d '' entry; do
  [[ $entry == *$'\t'* ]] || unknown 'malformed tree entry'
  path=${entry#*$'\t'}
  candidate_kind=shell-path
  if [[ $path == *.sh && $path != *.test.sh ]]; then
    :
  elif [[ $include_go == true && $path == *.go && $path != *_test.go ]]; then
    candidate_kind=go-entrypoint
  else
    continue
  fi
  metadata=${entry%%$'\t'*}
  read -r mode type blob extra <<< "$metadata"
  [[ -z ${extra:-} && $type == blob && $mode =~ ^100(644|755)$ &&
    $blob =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || unknown 'selected path is not a supported regular blob'
  printf '%s' "$path" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 || unknown 'selected path is not valid UTF-8'
  read_git cat-file -e "$blob^{blob}" 2>/dev/null || unknown 'selected blob is unavailable'
  if [[ $candidate_kind == go-entrypoint ]]; then
    read_git cat-file blob "$blob" > "$tmp/source.go" 2>/dev/null || unknown 'selected Go source could not be read'
    observed_blob=$(read_git hash-object --stdin < "$tmp/source.go") || unknown 'Go source identity could not be checked'
    [[ $observed_blob == "$blob" ]] || unknown 'Go source does not match its committed blob'
    entrypoint=$("$tmp/go-entrypoint" < "$tmp/source.go" 2>/dev/null) || unknown 'selected Go source could not be parsed completely'
    go_files_examined=$((go_files_examined + 1))
    case $entrypoint in
      true) : ;;
      false) continue ;;
      *) unknown 'Go parser returned an invalid observation' ;;
    esac
  fi
  executable=false
  [[ $mode == 100755 ]] && executable=true
  jq -cn --arg path "$path" --arg blob "$blob" --argjson executable "$executable" \
    --arg kind "$candidate_kind" --argjson includeGo "$include_go" \
    '{path:$path,blob:$blob,executable:$executable,callers:"UNKNOWN",destination:"UNASSESSED"} +
      (if $includeGo then {kind:$kind} else {} end)' \
    >> "$tmp/candidates" || unknown 'candidate could not be encoded'
done < "$tmp/tree"
[[ -z $entry ]] || unknown 'committed tree has an unterminated record'
# Buffer the entire result before exposing a successful observation.
jq -s --arg revision "$revision" --argjson includeGo "$include_go" --argjson goFilesExamined "$go_files_examined" '
  sort_by(.path) as $candidates |
  {version:1,status:"OBSERVED",authority:"NONE",revision:$revision,
   selection:"tracked-shell-paths-v1",
   coverage:{selectedPaths:($candidates|length),callers:"UNKNOWN",
     goPrograms:"NOT_EXAMINED",portfolio:"NOT_ASSERTED"},candidates:$candidates} |
  if $includeGo then
    .version = 2 | .selection = "tracked-shell-and-go-entrypoints-v1" |
    .coverage.goPrograms = "ENTRYPOINT_FILES_ONLY" | .coverage.goFilesExamined = $goFilesExamined |
    .coverage.buildability = "NOT_ASSERTED"
  else . end
' "$tmp/candidates" > "$tmp/result" || unknown 'observation could not be encoded'
cat "$tmp/result"
