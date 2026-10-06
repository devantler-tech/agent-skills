#!/usr/bin/env bash
# Exercise complete catalogue and destination observations before consumer writes.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
# Record an assertion without stopping so the fixture reports every failed outcome.
check() { if "$@"; then printf 'PASS %s\n' "$label"; else printf 'FAIL %s\n' "$label"; fail=$((fail+1)); fi; }
# Create an isolated two-skill catalogue with copies of the real production helpers.
fixture() {
  root="$work/$1"
  mkdir -p "$root/scripts" "$root/alpha" "$root/beta"
  cp "$here"/{install.sh,readme-index.sh,readme-index.awk,check-readme-index.sh,check-upstream-skills.sh} "$root/scripts/"
  printf fixture > "$root/alpha/SKILL.md"; printf fixture > "$root/beta/SKILL.md"
  printf '## Skills\n\n| Skill | Upstream | Install |\n|---|---|---|\n' > "$root/README.md"
}
# Emit one advertised source and command row at the requested Markdown indentation.
row() { printf '%s| %s | [%s](https://github.com/%s/tree/main/%s) | gh skill install %s %s |\n' "$1" "$2" "$3" "$3" "$4" "$3" "$2"; }
for indent in '' ' ' '  ' '   '; do
  fixture "indent-${#indent}"
  {
    row '' alpha devantler-tech/agent-skills alpha
    printf '\n%s| Skill | Upstream | Install |\n%s|---|---|---|\n' "$indent" "$indent"
    row "$indent" beta devantler-tech/agent-plugins beta
  } >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2>&1 || rc=$?
  label="visible table indent ${#indent} includes both rows"; check test "$rc:$(wc -l < "$root/out" | tr -d ' ')" = 0:2
done
# GFM outer table pipes are independently optional on headers and body rows.
for shape in both none left right; do
  fixture "outer-$shape"
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  case $shape in both) leading='| '; trailing=' |' ;; none) leading=''; trailing='' ;;
    left) leading='| '; trailing='' ;; right) leading=''; trailing=' |' ;; esac
  printf '%sbeta | [devantler-tech/agent-skills](https://github.com/devantler-tech/agent-skills/tree/main/beta) | gh skill install devantler-tech/agent-skills beta%s\n' \
    "$leading" "$trailing" >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="$shape outer pipes preserve both catalogue rows"; check test "$rc:$(wc -l < "$root/out" | tr -d ' ')" = 0:2
  rc=0; bash "$root/scripts/check-readme-index.sh" > "$root/guard" 2>&1 || rc=$?
  label="$shape outer pipes cover both maintained skills"; check test "$rc" -eq 0
  # A complete table with that same edge shape must also establish its framing.
  sed 's/^| *//; s/ *|$//' "$root/README.md" > "$root/no-edges"
  awk -v left="$leading" -v right="$trailing" '{if (index($0,"|")) print left $0 right; else print}' \
    "$root/no-edges" > "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="$shape header and separator pipes remain a table"; check test "$rc:$(wc -l < "$root/out" | tr -d ' ')" = 0:2
done
# Actual peer and parent headings end the index; deeper and non-heading examples
# do not. These are shipped parser consumers rather than a duplicate recognizer.
for heading in ordinary one-space two-space three-space tabbed parent setext setext-parent closing-hashes child no-space indented-code list-child fenced list-lazy quote-lazy quote-heading quote-explicit quote-list quote-blank quote-reference list-heading list-empty code-outside code-continuation paragraph-four quote-code quote-tab nested-tab quote-tab-code nested-tab-code quote-space nested-space; do
  fixture "scope-$heading"
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  printf '\n' >> "$root/README.md"
  expected=1
  # shellcheck disable=SC2016 # Literal fenced Markdown is fixture data.
  {
  case $heading in
    ordinary) printf '## Other\n' ;;
    one-space) printf ' ## Other\n' ;;
    two-space) printf '  ## Other\n' ;;
    three-space) printf '   ## Other\n' ;;
    tabbed) printf '##\tOther\n' ;;
    parent) printf '# Other\n' ;;
    setext) printf 'Other\n-----\n' ;;
    setext-parent) printf 'Other\n=====\n' ;;
    closing-hashes) printf '## Other ##\n' ;;
    child) printf '### Category\n'; expected=2 ;;
    no-space) printf '##Other\n'; expected=2 ;;
    indented-code) printf '    ## Other\n'; expected=2 ;;
    list-child) printf -- '- Example\n  ## Other\n'; expected=2 ;;
    fenced) printf '```markdown\n## Other\n```\n'; expected=2 ;;
    list-lazy) printf -- '- Note\n  continued\n---\n'; expected=2 ;;
    quote-lazy) printf '> Note\ncontinued\n---\n'; expected=2 ;;
    quote-heading) printf '> ## Quoted heading\nOther\n---\n' ;;
    quote-explicit) printf '> Note\n> continued\n---\n'; expected=2 ;;
    quote-list) printf '> - Note\ncontinued\n---\n'; expected=2 ;;
    quote-blank) printf '> Note\n\nOther\n---\n' ;;
    quote-reference) printf '> [example]: /url\nOther\n---\n' ;;
    list-heading) printf -- '- ## Quoted heading\nOther\n---\n' ;;
    list-empty) printf -- '-\nOther\n---\n' ;;
    code-outside) printf -- '-     code\nOther\n---\n' ;;
    code-continuation) printf -- '-     code\n  More\n---\n'; expected=2 ;;
    paragraph-four) printf -- '-    Note\ncontinued\n---\n'; expected=2 ;;
    quote-code) printf '> -     code\nOther\n---\n' ;;
    quote-tab) printf '> -\t  Note\ncontinued\n---\n'; expected=2 ;;
    nested-tab) printf -- '- -\t  Note\ncontinued\n---\n'; expected=2 ;;
    quote-tab-code) printf '> -\t    code\nOther\n---\n' ;;
    nested-tab-code) printf -- '- -\t    code\nOther\n---\n' ;;
    quote-space) printf '> -   Note\ncontinued\n---\n'; expected=2 ;;
    nested-space) printf -- '- -   Note\ncontinued\n---\n'; expected=2 ;;
  esac
  printf '\n| Skill | Upstream | Install |\n|---|---|---|\n'
  row '' beta devantler-tech/agent-skills beta
  } >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="$heading retains the rendered Skills scope"; check test "$rc:$(wc -l < "$root/out" | tr -d ' ')" = "0:$expected"
done
for heading in indented tabbed closing-hashes setext; do
  fixture "skills-heading-$heading"
  case $heading in indented) printf '   ## Skills\n' ;; tabbed) printf '##\tSkills\n' ;;
    closing-hashes) printf '## Skills ##\n' ;; setext) printf 'Skills\n------\n' ;; esac > "$root/README.md"
  printf '\n| Skill | Upstream | Install |\n|---|---|---|\n' >> "$root/README.md"
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="$heading Skills heading begins the catalogue"; check test "$rc:$(cat "$root/out")" = '0:devantler-tech/agent-skills alpha'
done
# A clean sibling must never substitute for the physical checkout being checked.
fixture malformed-optional-row
{
  row '' alpha devantler-tech/agent-skills alpha
  printf 'beta | [devantler-tech/agent-skills](https://github.com/devantler-tech/agent-skills/tree/main/beta) | gh skill install devantler-tech/agent-skills other\n'
} >> "$root/README.md"
rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
label='an unpiped contradictory row refuses the complete preview'; check test "$rc" -ne 0
label='an unpiped contradictory row emits no partial entries'; check test ! -s "$root/out"
fixture repeated-rendered-section
{
  row '' alpha devantler-tech/agent-skills alpha
  printf '\nSkills\n------\n\n| Skill | Upstream | Install |\n|---|---|---|\n'
  row '' beta devantler-tech/agent-skills beta
} >> "$root/README.md"
rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
label='a second rendered Skills section refuses the complete preview'; check test "$rc" -ne 0
label='repeated rendered sections emit no partial entries'; check test ! -s "$root/out"
for suffix in '' $'\n' $'\n\n'; do
  fixture "physical$suffix"
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  if [[ -z $suffix ]]; then rm -rf "$root/beta"; continue; fi
  rc=0; bash "$root/scripts/check-readme-index.sh" > "$root/out" 2>&1 || rc=$?
  label="physical checkout with ${#suffix} trailing newlines rejects its orphan"; check test "$rc" -ne 0
done
for framing in prose missing-header mismatched-delimiter; do
  fixture "framing-$framing"
  case $framing in
    prose) printf '## Skills\n\nAn ordinary paragraph containing a command example.\n' > "$root/README.md" ;;
    missing-header) printf '## Skills\n\n' > "$root/README.md" ;;
    mismatched-delimiter) printf '## Skills\n\n| Skill | Upstream | Install |\n|---|---|\n' > "$root/README.md" ;;
  esac
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  for consumer in install.sh check-readme-index.sh; do
    arguments=(); [[ $consumer != install.sh ]] || arguments=(--list)
    rc=0; bash "$root/scripts/$consumer" "${arguments[@]}" > "$root/out" 2> "$root/err" || rc=$?
    label="$consumer refuses an empty catalogue with $framing framing"; check test "$rc" -ne 0
    label="$consumer emits no entries from $framing framing"; check test ! -s "$root/out"
  done
  printf '\n| Skill | Upstream | Install |\n|---|---|---|\n' >> "$root/README.md"
  row '' beta devantler-tech/agent-plugins beta >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="a real table following $framing includes only its own row"; check test "$rc:$(cat "$root/out")" = '0:devantler-tech/agent-plugins beta'
done
fixture target
row '' alpha devantler-tech/agent-skills missing/alpha >> "$root/README.md"
row '' beta devantler-tech/agent-skills beta >> "$root/README.md"
rc=0; bash "$root/scripts/check-readme-index.sh" > "$root/out" 2>&1 || rc=$?
label='a missing advertised local path cannot borrow a root slug'; check test "$rc" -ne 0
for repo in .github _skills -skills . ..; do
  fixture "repo-$repo"
  row '' alpha "devantler-tech/$repo" alpha >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2>&1 || rc=$?
  if [[ $repo == . || $repo == .. ]]; then
    label="traversal repository $repo is refused"; check test "$rc" -ne 0
  else
    label="legal repository $repo is accepted"; check test "$rc" -eq 0
  fi
done
# Canonical skill names cannot alias each other by case on a destination
# filesystem. Complete parsing must refuse unsupported names before native calls.
for scenario in uppercase dotted underscored leading-hyphen trailing-hyphen double-hyphen oversized; do
  case "$scenario" in
    uppercase) name=Alpha ;;
    dotted) name=alpha.beta ;;
    underscored) name=alpha_beta ;;
    leading-hyphen) name=-alpha ;;
    trailing-hyphen) name=alpha- ;;
    double-hyphen) name=alpha--beta ;;
    oversized) name=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklm ;;
  esac
  fixture "skill-name-$scenario"
  row '' alpha fixture/one alpha >> "$root/README.md"
  row '' "$name" fixture/two "$name" >> "$root/README.md"
  mkdir "$root/bin"
  cat > "$root/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NATIVE_CALLS"
exit 99
STUB
  chmod +x "$root/bin/gh"
  for consumer in preview installer upstream; do
    : > "$root/calls"
    rc=0
    case "$consumer" in
      preview) command=(bash "$root/scripts/install.sh" --list) ;;
      installer) command=(bash "$root/scripts/install.sh" codex) ;;
      upstream) command=(bash "$root/scripts/check-upstream-skills.sh") ;;
    esac
    PATH="$root/bin:$PATH" NATIVE_CALLS="$root/calls" "${command[@]}" > "$root/out" 2> "$root/err" || rc=$?
    label="$consumer rejects $scenario skill names"; check test "$rc" -ne 0
    label="$consumer refuses $scenario before any native call"; check test ! -s "$root/calls"
    if [[ "$consumer" == preview ]]; then
      label="$scenario refusal emits no partial catalogue"; check test ! -s "$root/out"
    fi
  done
done
for name in alpha alpha-2 7 abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijkl; do
  fixture "valid-skill-name-$name"
  row '' "$name" Fixture/Source "$name" >> "$root/README.md"
  rc=0; bash "$root/scripts/install.sh" --list > "$root/out" 2> "$root/err" || rc=$?
  label="canonical skill name $name remains valid"; check test "$rc" -eq 0
  label="canonical skill name preserves repository casing"; check test "$(cat "$root/out")" = "Fixture/Source $name"
done
# The stub models the native CLI destination derived from frontmatter; it records
# only user writes, while --dir materializes that identity in a private stage.
for mode in valid minimum-cli mismatched colliding failed-stage extra-stage; do
  fixture "$mode"
  row '' alpha devantler-tech/agent-skills alpha >> "$root/README.md"
  row '' beta devantler-tech/agent-plugins beta >> "$root/README.md"
  mkdir "$root/bin"; : > "$root/user-writes"
  cat > "$root/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -eu
if [[ "$1 $2" == 'skill --help' ]]; then exit 0; fi
if [[ "$1" == api ]]; then printf '{"sha":"1111111111111111111111111111111111111111"}\n'; exit 0; fi
[[ "$1 $2" == 'skill install' ]] || exit 1
if [[ $MODE == minimum-cli ]]; then
  for argument in "$@"; do
    [[ $argument != --allow-hidden-dirs ]] || { echo 'unknown flag: --allow-hidden-dirs' >&2; exit 1; }
  done
fi
path=$4; slug=${path%/SKILL.md}; slug=${slug##*/}; actual=$slug
case $MODE in colliding) actual=shared ;; mismatched) [[ $slug != beta ]] || actual=other ;; esac
dir=''
for ((i=1;i<=$#;i++)); do if [[ ${!i} == --dir ]]; then i=$((i+1)); dir=${!i}; fi; done
if [[ -n $dir ]]; then
  mkdir -p "$dir/$actual"
  printf -- '---\nname: %s\ndescription: Fixture.\n---\n' "$actual" > "$dir/$actual/SKILL.md"
  [[ $MODE != extra-stage ]] || mkdir "$dir/unselected"
  [[ $MODE != failed-stage ]] || exit 1
else
  printf '%s\n' "$actual" >> "$USER_WRITES"
fi
STUB
  chmod +x "$root/bin/gh"
  rc=0
  PATH="$root/bin:$PATH" MODE="$mode" USER_WRITES="$root/user-writes" bash "$root/scripts/install.sh" codex > "$root/out" 2>&1 || rc=$?
  if [[ $mode == valid || $mode == minimum-cli ]]; then
    label="$mode native destination identities still install"; check test "$rc" -eq 0
    label="$mode batch writes both user destinations"; check test "$(wc -l < "$root/user-writes" | tr -d ' ')" = 2
  else
    label="$mode destination preflight fails"; check test "$rc" -ne 0
    label="$mode refuses before any user write"; check test ! -s "$root/user-writes"
  fi
done
fixture snapshot
row '' alpha devantler-tech/agent-plugins alpha >> "$root/README.md"
row '' beta devantler-tech/agent-plugins beta >> "$root/README.md"
mkdir "$root/bin"; : > "$root/calls"
cat > "$root/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -eu
target=$2
printf '%s\n' "$target" >> "$CALLS"
case $target in
  */commits/main) printf 'HTTP/1.1 200 OK\r\n\r\n{"sha":"1111111111111111111111111111111111111111"}\n' ;;
  */contents/alpha/SKILL.md*) printf 'HTTP/1.1 200 OK\r\n\r\n{"type":"file","name":"SKILL.md","path":"alpha/SKILL.md"}\n' ;;
  */contents/beta/SKILL.md?ref=main) printf 'HTTP/1.1 200 OK\r\n\r\n{"type":"file","name":"SKILL.md","path":"beta/SKILL.md"}\n' ;;
  */contents/beta/SKILL.md*) printf 'HTTP/1.1 404 Not Found\r\n\r\n{"message":"Not Found"}\n'; exit 1 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$root/bin/gh"
rc=0
PATH="$root/bin:$PATH" CALLS="$root/calls" UPSTREAM_RETRY_SLEEP=true bash "$root/scripts/check-upstream-skills.sh" > "$root/out" 2>&1 || rc=$?
label='a moving ref cannot combine files from incompatible revisions'; check test "$rc" -ne 0
label='one source ref is resolved once per observation'; check test "$(grep -c '/commits/main' "$root/calls" || true)" = 1
label='all target reads use the same immutable revision'; check test "$(grep -c '/contents/.*?ref=1111111111111111111111111111111111111111' "$root/calls" || true)" = 2
# A source link naming an immutable commit must pin the copyable command too.
# Without the pin, native gh skill prefers the latest release instead of that
# reviewed source. Check both consumers of the shared catalogue interpretation.
for mode in pinned missing mismatched; do
  fixture "commit-command-$mode"
  pin=1111111111111111111111111111111111111111
  option=" --pin $pin"
  case "$mode" in
    missing) option='' ;;
    mismatched) option=' --pin 2222222222222222222222222222222222222222' ;;
  esac
  printf '| alpha | [fixture/source](https://github.com/fixture/source/tree/%s/skills/alpha) | gh skill install fixture/source alpha%s |\n' \
    "$pin" "$option" >> "$root/README.md"
  for consumer in install targets; do
    case "$consumer" in
      install) command=(bash "$root/scripts/install.sh" --list) ;;
      targets) command=(bash "$root/scripts/readme-index.sh" --targets) ;;
    esac
    rc=0; "${command[@]}" > "$root/out" 2> "$root/err" || rc=$?
    if [[ "$mode" == pinned ]]; then
      label="$consumer preserves a commit-pinned catalogue command"; check test "$rc" -eq 0
    else
      label="$consumer refuses a $mode commit pin"; check test "$rc" -ne 0
      label="$consumer emits no entries for a $mode commit pin"; check test ! -s "$root/out"
    fi
  done
done
printf 'catalogue integrity: %s failures\n' "$fail"
test "$fail" -eq 0
