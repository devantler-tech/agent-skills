#!/usr/bin/env bash
#
# Publish validated skills at an explicit commit, with safe completed reruns.
#
#   already published  -> report it and succeed, so the caller's later steps run
#   not published yet  -> bind the checkout, validate, publish, verify
#   ambiguous          -> FAIL, and say what is ambiguous
#
# "Already published" is deliberately narrow: the tag targets the expected
# release commit AND a non-draft release exists for that tag. A tag with no release
# is a half-finished publish, not a finished one, so it fails rather than skipping — the caller must never read
# "skipped" as "published". A failure to READ either fact is likewise a failure,
# never a skip: an unreadable precondition proves nothing.
#
# Usage: publish-skills-release.sh --tag <tag> [--repo <owner/repo>] [--expected-commit <sha>]
set -euo pipefail
# Repository selectors from a hook or parent process must not substitute an
# origin or object store for the checkout that the skill CLI will validate.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX GIT_NAMESPACE
export GIT_NO_REPLACE_OBJECTS=1 GIT_NO_LAZY_FETCH=1

# Print the supported arguments and exit-code contract to stderr without exiting.
usage() {
  cat >&2 <<'USAGE'
Usage: publish-skills-release.sh --tag <tag> [--repo <owner/repo>] [--expected-commit <sha>]

  --tag   the release tag to publish (required), e.g. v1.2.3
  --repo  the github.com repository to publish; defaults to $GITHUB_REPOSITORY
  --expected-commit  full release commit SHA; defaults to $GITHUB_SHA

Each selector may be supplied once. Help must be used alone.
Repository selectors must be one github.com owner/repository pair.

Exit codes:
  0  the release is published (by this run, or already)
  1  the publish failed, or its precondition could not be established
  2  usage error
USAGE
}

# Report an invalid invocation, print usage, and exit with the usage-error status.
# The first argument is the diagnostic to show before the usage text.
die_usage() {
  printf 'publish-skills-release: %s\n\n' "$1" >&2
  usage
  exit 2
}

tag=''
repo="${GITHUB_REPOSITORY:-}"
expected_commit="${GITHUB_SHA:-}"
tag_seen=false repo_seen=false commit_seen=false

case "${1:-}" in
  -h|--help)
    [ "$#" -eq 1 ] || die_usage 'help must be used alone'
    usage; exit 0 ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag)
      [ "$tag_seen" = false ] || die_usage '--tag must be supplied once'
      if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == -* ]]; then die_usage '--tag needs a value'; fi
      tag_seen=true
      tag="$2"
      shift 2
      ;;
    --repo)
      [ "$repo_seen" = false ] || die_usage '--repo must be supplied once'
      if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == -* ]]; then die_usage '--repo needs a value'; fi
      repo_seen=true
      repo="$2"
      shift 2
      ;;
    --expected-commit)
      [ "$commit_seen" = false ] || die_usage '--expected-commit must be supplied once'
      if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == -* ]]; then die_usage '--expected-commit needs a value'; fi
      commit_seen=true
      expected_commit="$2"
      shift 2
      ;;
    -h | --help)
      die_usage 'help must be used alone'
      ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$tag" ] || die_usage "--tag is required"
[[ "$tag" != -* ]] || die_usage "--tag must not begin with '-'"
[ -n "$repo" ] || die_usage "--repo is required when GITHUB_REPOSITORY is unset"
[[ "$repo" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || die_usage '--repo (or GITHUB_REPOSITORY) must be an explicit github.com owner/repository pair'
[[ "$expected_commit" =~ ^[0-9a-f]{40}$ ]] || die_usage "--expected-commit (or GITHUB_SHA) must be a full commit SHA"

# Origin verification below supports github.com. Keep every API, validation,
# and release call on that same host even when the caller sets GH_HOST.
export GH_HOST=github.com

# Ref names can contain URL syntax such as # or %. Encode the tag component
# once for API paths; release commands and JSON comparisons keep the literal tag.
tag_path=$(jq -rn --arg tag "$tag" '$tag | @uri') || exit 1

# Ordinary JSON decoding collapses repeated identity fields and containers.
# Completed streaming paths retain that ambiguity; observations are one object.
unambiguous_object() {
  jq -es 'length==1 and (.[0]|type=="object")' >/dev/null <<< "$1" &&
    jq --stream -es '
      reduce .[] as $event ({complete:{}, valid:true};
        if ($event|length)==2 then
          .complete as $complete | $event[0] as $path |
          .valid = (.valid and (any(range(0;($path|length)+1);
            $complete[($path[0:.]|tojson)]==true)|not)) |
          .complete[($path|tojson)] = true
        else .complete[($event[0][0:-1]|tojson)] = true end) | .valid
    ' >/dev/null <<< "$1"
}

# Verify the requested remote tag resolves to the expected commit. The commits
# endpoint handles annotated tags; qualifying tags/ prevents branch collisions.
verify_tag_commit() {
  local tag_commit response
  response=$(gh api "repos/${repo}/commits/tags/${tag_path}") || {
    printf 'publish-skills-release: could not resolve tag %s to a commit; publication is unverified.\n' "$tag" >&2
    return 1
  }
  unambiguous_object "$response" || return 1
  tag_commit=$(jq -er '.sha | select(type=="string")' <<< "$response") || return 1
  if ! [[ "$tag_commit" =~ ^[0-9a-f]{40}$ ]] || [ "$tag_commit" != "$expected_commit" ]; then
    printf 'publish-skills-release: tag %s does not resolve to the expected release commit; publication is unverified.\n' "$tag" >&2
    return 1
  fi
}

# One HTTP observation binds status to this exact tag endpoint. Error prose
# cannot establish absence: another status may legitimately mention "Not Found".
tag_ref_status=0
tag_response=$(gh api "repos/$repo/git/ref/tags/$tag_path" --include 2>/dev/null) || tag_ref_status=$?
http_status=$(printf '%s\n' "$tag_response" | awk 'NR==1 && /^HTTP\/[0-9.]+ [0-9][0-9][0-9] / {print $2}') || exit 1
tag_body=$(printf '%s\n' "$tag_response" | awk 'body {print; next} {sub(/\r$/, "")} /^$/ {body=1}') || exit 1
if [ "$http_status" = 200 ] && [ "$tag_ref_status" -eq 0 ] && unambiguous_object "$tag_body" &&
   printf '%s' "$tag_body" | jq -es --arg ref "refs/tags/$tag" '
     length==1 and (.[0] | type=="object" and .ref==$ref and
       (.object.type=="commit" or .object.type=="tag") and
       (.object.sha|type=="string" and test("\\A[0-9a-f]{40}\\z")))' >/dev/null; then
  tag_exists=yes
elif [ "$http_status" = 404 ] && [ "$tag_ref_status" -eq 1 ] && unambiguous_object "$tag_body" &&
     printf '%s' "$tag_body" | jq -es 'length==1 and (.[0]|type=="object" and .message=="Not Found")' >/dev/null; then
  tag_exists=no
else
  printf 'publish-skills-release: tag existence observation is incomplete; refusing publication.\n' >&2
  exit 1
fi

# Bind the validation checkout to the requested repository and expected commit.
# Refuse hidden index state, changed disk content, or executable permissions that differ from its tree.
verify_checkout() {
  # The skill CLI validates the working directory and resolves its own origin.
  # Bind those bytes to this release before validation or any publication. Use
  # the effective URL (including Git's insteadOf rewrites), not gh's default repo.
  checkout_root=$(git --no-replace-objects rev-parse --show-toplevel) || exit 1
  [ "$(pwd -P)" = "$checkout_root" ] || {
    printf 'publish-skills-release: run from the repository root; refusing partial skill validation.\n' >&2
    exit 1
  }
  origin_url=$(git remote get-url -- origin) || {
    printf 'publish-skills-release: origin is unresolved; refusing publication.\n' >&2
    exit 1
  }
  origin_url=$(printf '%s' "$origin_url" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  case "$origin_url" in
    https://github.com/*) origin_repo=${origin_url#https://github.com/} ;;
    https://github.com:443/*) origin_repo=${origin_url#https://github.com:443/} ;;
    git@github.com:*) origin_repo=${origin_url#git@github.com:} ;;
    ssh://git@github.com/*) origin_repo=${origin_url#ssh://git@github.com/} ;;
    ssh://git@github.com:22/*) origin_repo=${origin_url#ssh://git@github.com:22/} ;;
    *)
      printf 'publish-skills-release: origin must identify the expected GitHub repository.\n' >&2
      exit 1
      ;;
  esac
  origin_repo=${origin_repo%.git}
  if [ "$origin_repo" != "$(printf '%s' "$repo" | LC_ALL=C tr '[:upper:]' '[:lower:]')" ]; then
    printf 'publish-skills-release: origin differs from --repo; refusing publication.\n' >&2
    exit 1
  fi
  checkout_commit=$(git --no-replace-objects rev-parse --verify 'HEAD^{commit}') || exit 1
  [ "$checkout_commit" = "$expected_commit" ] || {
    printf 'publish-skills-release: HEAD differs from the expected release commit; refusing publication.\n' >&2
    exit 1
  }
  # These index flags hide modified or absent tracked files from status. Reject
  # them rather than validating disk bytes that differ from the release commit.
  # NUL-delimited records preserve filenames containing whitespace or newlines.
  checkout_observation=$(mktemp -d) || exit 1
  trap 'rm -rf "$checkout_observation"' EXIT
  git --no-replace-objects ls-files -v -z > "$checkout_observation/index" || exit 1
  : > "$checkout_observation/index-paths"
  entry=''
  while IFS= read -r -d '' entry; do
    case "${entry:0:1}" in
      H) ;;
      *) printf 'publish-skills-release: hidden or invalid index flags; refusing publication.\n' >&2; exit 1 ;;
    esac
    [[ ${entry:1:1} = ' ' && -n ${entry:2} ]] || exit 1
    printf '%s' "${entry:2}" | base64 | tr -d '\r\n' >> "$checkout_observation/index-paths" || exit 1
    printf '\n' >> "$checkout_observation/index-paths"
  done < "$checkout_observation/index"
  if [ -n "$entry" ]; then
    printf 'publish-skills-release: hidden or unreadable index flags prevent checkout verification; refusing publication.\n' >&2
    exit 1
  fi
  checkout_status=$(git --no-replace-objects -c core.fsmonitor= --no-optional-locks \
    status --porcelain=v1 --untracked-files=all --ignored) || exit 1
  [ -z "$checkout_status" ] || {
    printf 'publish-skills-release: checkout has uncommitted or ignored files; refusing publication.\n' >&2
    exit 1
  }

  # Status compares cleaned content. Validate the actual disk bytes against
  # immutable blobs so filters or newline conversion cannot hide a different skill.
  tracked_files="$checkout_observation/tree"
  git --no-replace-objects ls-tree -r --full-tree -z "$expected_commit" >"$tracked_files" || exit 1
  : > "$checkout_observation/tree-paths"
  : > "$checkout_observation/tree-records"
  while IFS= read -r -d '' record; do
    header=${record%%$'\t'*}
    path=${record#*$'\t'}
    [[ "$header" =~ ^(100644|100755|120000)\ blob\ ([0-9a-f]{40})$ ]] || {
      printf 'publish-skills-release: unsupported tracked object; refusing publication.\n' >&2
      exit 1
    }
    mode=${BASH_REMATCH[1]}
    expected_blob=${BASH_REMATCH[2]}
    printf '%s' "$path" | base64 | tr -d '\r\n' >> "$checkout_observation/tree-paths" || exit 1
    printf '\n' >> "$checkout_observation/tree-paths"
    printf '%s %s\t%s\0' "$mode" "$expected_blob" "$path" | base64 | tr -d '\r\n' >> "$checkout_observation/tree-records" || exit 1
    printf '\n' >> "$checkout_observation/tree-records"
    if [ "$mode" = 120000 ]; then
      [ -L "./$path" ] || exit 1
      link=$(readlink "./$path" && printf '.') || exit 1
      link=${link%.}; link=${link%$'\n'}
      actual_blob=$(printf '%s' "$link" | git --no-replace-objects hash-object --stdin) || exit 1
    else
      [ -f "./$path" ] && [ ! -L "./$path" ] || exit 1
      if { [ "$mode" = 100755 ] && [ ! -x "./$path" ]; } ||
         { [ "$mode" = 100644 ] && [ -x "./$path" ]; }; then
        printf 'publish-skills-release: tracked executable permissions differ from the release commit; refusing publication.\n' >&2
        exit 1
      fi
      actual_blob=$(git --no-replace-objects hash-object --no-filters -- "./$path") || exit 1
    fi
    [ "$actual_blob" = "$expected_blob" ] || {
      printf 'publish-skills-release: tracked disk bytes differ from the expected release commit; refusing publication.\n' >&2
      exit 1
    }
  done <"$tracked_files"
  [ -z "${record:-}" ] || {
    printf 'publish-skills-release: incomplete tracked file record; refusing publication.\n' >&2
    exit 1
  }
  # An independently framed raw diff proves that a successful ls-tree listing
  # did not omit any tracked leaf. No external diff, checkout filter or rename
  # conversion participates in this observation.
  empty_tree=$(git --no-replace-objects hash-object -t tree --stdin < /dev/null) || exit 1
  git --no-replace-objects diff-tree -r --raw -z --no-abbrev --no-commit-id --no-renames \
    --no-ext-diff --no-textconv --no-relative --no-color --ignore-submodules=none \
    "$empty_tree" "$expected_commit" > "$checkout_observation/diff" || exit 1
  : > "$checkout_observation/diff-records"
  header=''
  while IFS= read -r -d '' header; do
    IFS= read -r -d '' path || exit 1
    read -r old_mode new_mode old_blob new_blob change extra <<< "$header"
    [[ $old_mode = :000000 && $new_mode =~ ^100(644|755)$|^120000$ &&
       $old_blob =~ ^0{40}$ && $new_blob =~ ^[0-9a-f]{40}$ && $change = A && -z ${extra:-} && -n $path ]] || exit 1
    printf '%s %s\t%s\0' "$new_mode" "$new_blob" "$path" | base64 | tr -d '\r\n' >> "$checkout_observation/diff-records" || exit 1
    printf '\n' >> "$checkout_observation/diff-records"
  done < "$checkout_observation/diff"
  [ -z "$header" ] || exit 1
  for inventory in tree-records diff-records tree-paths index-paths; do
    LC_ALL=C sort "$checkout_observation/$inventory" > "$checkout_observation/$inventory.sorted" || exit 1
  done
  if ! cmp -s "$checkout_observation/tree-records.sorted" "$checkout_observation/diff-records.sorted" ||
     ! cmp -s "$checkout_observation/tree-paths.sorted" "$checkout_observation/index-paths.sorted"; then
      printf 'publish-skills-release: incomplete or inconsistent tracked inventory; refusing publication.\n' >&2
      exit 1
  fi
  rm -rf "$checkout_observation"
  trap - EXIT

}

if [ "$tag_exists" = no ]; then
  verify_checkout
  # gh skill publish --tag targets a branch name, or the default branch for a
  # detached checkout. Validate with the skill CLI, then name the immutable
  # commit explicitly when creating the GitHub release. The topic check remains
  # the caller's responsibility, as on the skill CLI's non-interactive path.
  gh skill publish --dry-run
  verify_checkout
  # Create-only ref reservation loses atomically if another publisher wins the
  # tag after our absence probe. Never publish against that writer's tag. A
  # failed release leaves the reserved tag for explicit operator recovery.
  gh api "repos/${repo}/git/refs" --method POST \
    -f "ref=refs/tags/${tag}" -f "sha=${expected_commit}" >/dev/null || {
    printf 'publish-skills-release: could not reserve tag %s; refusing release creation.\n' "$tag" >&2
    exit 1
  }
  verify_tag_commit
  printf 'publish-skills-release: %s is not published yet; publishing.\n' "$tag"
  gh release create "$tag" --repo "$repo" --target "$expected_commit" --generate-notes --verify-tag
fi

# Recheck after creation, and apply the same postcondition to completed reruns.
verify_tag_commit

# The tag exists. Only a real, non-draft release for it proves the publish
# finished; a tag without one is a half-finished publish that needs a human.
release_json=$(gh release view "$tag" --repo "$repo" --json tagName,isDraft 2>&1) || {
  printf 'publish-skills-release: tag %s exists on %s but its release could not be read, so the publish state is unknown; refusing to publish or skip.\n' \
    "$tag" "$repo" >&2
  printf '%s\n' "$release_json" >&2
  exit 1
}

if ! unambiguous_object "$release_json" || ! printf '%s' "$release_json" | jq -es --arg tag "$tag" \
  'length == 1 and (.[0] | type == "object" and .tagName == $tag and .isDraft == false)' >/dev/null; then
  printf 'publish-skills-release: tag %s exists on %s but a matching non-draft release was not established; publication is unverified.\n' \
    "$tag" "$repo" >&2
  exit 1
fi

printf 'publish-skills-release: verified %s is published on %s at the expected commit.\n' \
  "$tag" "$repo"
