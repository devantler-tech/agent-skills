#!/usr/bin/env bash
#
# Fail when an authored SKILL.md grows past its size budget (#285).
#
# The Agent Skills specification recommends keeping SKILL.md under 500 lines and
# its instructions to roughly 5,000 tokens, with detail moved into referenced
# files that load only when needed. Every activation of a skill loads its whole
# SKILL.md, so each line added to a large one is paid on every run.
#
# The budget lives in .github/skill-size-budget.tsv: a default row (`*`) every
# skill gets, and a recorded ceiling for each skill already over the default.
# A skill passes when its SKILL.md is within its budget on both lines and bytes.
# Only SKILL.md is measured, so moving text into references/ always helps.
#
# Checks, in order:
#   1. The budget file exists and every row is `<skill><TAB><lines><TAB><bytes>`
#      with positive whole numbers, one `*` row and no repeated skill.
#   2. At least one skill directory is found (an empty discovery never passes).
#   3. Every SKILL.md is within its budget. A failure names the skill, its size,
#      its budget and what to do.
#   4. Every named row belongs to a skill that exists, so a removed or renamed
#      skill cannot leave a ceiling behind.
# A skill that is now smaller than its recorded ceiling passes with a notice to
# lower the ceiling, since ceilings only come down.
#
# Usage: ./scripts/check-skill-size.sh   (run from anywhere; resolves the repo root)
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd -- "$script_dir/.."

budget_file=".github/skill-size-budget.tsv"
fix_hint="Move detail into references/ and link it from the step that needs it."

if [ ! -f "$budget_file" ]; then
  echo "::error::$budget_file is missing, so no skill can be checked against a budget."
  exit 1
fi

# 1. Parse and validate the budget file. Output: one `<name> <lines> <bytes>` line per row.
if ! rows=$(awk -F'\t' '
  /^[[:space:]]*$/ || /^#/ { next }
  {
    if (NF != 3) { printf "line %d: expected 3 tab-separated fields, found %d\n", NR, NF; bad = 1; next }
    if ($1 != "*" && $1 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) { printf "line %d: invalid skill name \"%s\"\n", NR, $1; bad = 1; next }
    if ($2 !~ /^[1-9][0-9]*$/ || $3 !~ /^[1-9][0-9]*$/) { printf "line %d: limits must be positive whole numbers\n", NR; bad = 1; next }
    if ($1 in seen) { printf "line %d: \"%s\" is listed more than once\n", NR, $1; bad = 1; next }
    seen[$1] = 1
    out = out $1 " " $2 " " $3 "\n"
  }
  END {
    if (!("*" in seen)) { print "no default row (*)"; bad = 1 }
    if (bad) exit 1
    printf "%s", out
  }' "$budget_file"); then
  printf '%s\n' "$rows" | sed "s|^|::error file=$budget_file::|"
  exit 1
fi

default_lines=$(printf '%s\n' "$rows" | awk '$1 == "*" { print $2 }')
default_bytes=$(printf '%s\n' "$rows" | awk '$1 == "*" { print $3 }')

# 2. Discover skill directories the same way CI's discover-skills job does.
inventory_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$inventory_dir"' EXIT
inventory="$inventory_dir/find"
if ! find . -mindepth 2 -maxdepth 2 -name SKILL.md -print0 > "$inventory"; then
  echo "::error::Skill discovery failed, so the size budget was not checked."
  exit 1
fi

failed=0
checked=0
skills=""
while IFS= read -r -d '' path; do
  path=${path#./}
  skill=${path%/SKILL.md}
  skills="$skills $skill "
  checked=$((checked + 1))

  lines=$(awk 'END { print NR }' "$path")
  bytes=$(wc -c < "$path" | tr -d '[:space:]')

  ceiling=$(printf '%s\n' "$rows" | awk -v s="$skill" '$1 == s { print $2 " " $3 }')
  if [ -n "$ceiling" ]; then
    max_lines=${ceiling% *}
    max_bytes=${ceiling#* }
    source="recorded ceiling"
  else
    max_lines=$default_lines
    max_bytes=$default_bytes
    source="default budget"
  fi

  printf '  %-28s %5s lines %7s bytes  (%s: %s lines, %s bytes)\n' \
    "$skill" "$lines" "$bytes" "$source" "$max_lines" "$max_bytes"

  # 3. Within budget on both dimensions.
  if [ "$lines" -gt "$max_lines" ] || [ "$bytes" -gt "$max_bytes" ]; then
    echo "::error file=$path::$skill/SKILL.md is $lines lines and $bytes bytes, over its $source of $max_lines lines and $max_bytes bytes. $fix_hint"
    failed=1
  elif [ -n "$ceiling" ]; then
    # The lowest ceiling this skill could carry now: its size, or the default where it is inside it.
    new_lines=$((lines > default_lines ? lines : default_lines))
    new_bytes=$((bytes > default_bytes ? bytes : default_bytes))
    if [ "$new_lines" -eq "$default_lines" ] && [ "$new_bytes" -eq "$default_bytes" ]; then
      echo "::notice file=$budget_file::$skill now fits the default budget; delete its row from $budget_file."
    elif [ "$new_lines" -lt "$max_lines" ] || [ "$new_bytes" -lt "$max_bytes" ]; then
      echo "::notice file=$budget_file::$skill shrank; lower its ceiling in $budget_file to $new_lines lines and $new_bytes bytes."
    fi
  fi
done < "$inventory"

if [ "$checked" -eq 0 ]; then
  echo "::error::No SKILL.md was found, so the size budget checked nothing."
  exit 1
fi

# 4. Every named row belongs to an existing skill.
while read -r name _ _; do
  [ "$name" = "*" ] && continue
  case "$skills" in
    *" $name "*) ;;
    *)
      echo "::error file=$budget_file::$budget_file has a ceiling for \"$name\", but there is no $name/SKILL.md. Delete the row."
      failed=1
      ;;
  esac
done <<< "$rows"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "All $checked skills are within their size budget."
