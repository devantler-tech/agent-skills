#!/usr/bin/env bash
#
# Self-test for check-skill-size.sh. Each case builds a throwaway repository
# root holding a copy of the REAL script, a budget file and fixture skills, runs
# the script there and checks both its exit status and the message it prints.
# No network, gh or real skill content is needed.
set -Eeuo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

# make_root <root> <budget rows...>: a fixture root with the real script and a
# budget file holding the given rows (each row's fields separated by spaces here,
# written with tabs).
make_root() {
  local root="$1" row
  shift
  rm -rf "$root"
  mkdir -p "$root/scripts" "$root/.github"
  cp "$here/check-skill-size.sh" "$root/scripts/"
  {
    printf '# fixture budget\n'
    for row in "$@"; do
      printf '%s\n' "$row" | tr ' ' '\t'
    done
  } > "$root/.github/skill-size-budget.tsv"
}

# add_skill <root> <skill> <lines> <bytes per line> [file]: a SKILL.md (or the named
# file inside the skill) of exactly <lines> newline-terminated lines.
add_skill() {
  local root="$1" skill="$2" lines="$3" width="$4" file="${5:-SKILL.md}"
  mkdir -p "$root/$skill/$(dirname "$file")"
  awk -v n="$lines" -v w="$width" 'BEGIN {
    line = ""; for (i = 1; i < w; i++) line = line "x"
    for (i = 0; i < n; i++) print line
  }' > "$root/$skill/$file"
}

# expect <name> <pass|fail> <root> [text the output must contain]
expect() {
  local name="$1" want="$2" root="$3" text="${4:-}" out status=0
  out=$(bash "$root/scripts/check-skill-size.sh" 2>&1) || status=$?
  if [ "$want" = pass ] && [ "$status" -ne 0 ]; then
    printf '  ❌ %s — expected PASS, got exit %s\n%s\n' "$name" "$status" "$out"; fail=1; return
  fi
  if [ "$want" = fail ] && [ "$status" -eq 0 ]; then
    printf '  ❌ %s — expected FAIL, but it passed\n%s\n' "$name" "$out"; fail=1; return
  fi
  if [ -n "$text" ] && ! grep -qF -- "$text" <<<"$out"; then
    printf '  ❌ %s — output does not contain: %s\n%s\n' "$name" "$text" "$out"; fail=1; return
  fi
  printf '  ✅ %s\n' "$name"
}

default='* 500 20000'

# Inside the default budget.
r="$tmp/inside"; make_root "$r" "$default"
add_skill "$r" alpha 100 10
expect "skill inside the default budget passes" pass "$r" "All 1 skills are within their size budget."

# At exactly the default budget.
r="$tmp/at-default"; make_root "$r" "$default"
add_skill "$r" alpha 500 40
expect "skill at exactly the default budget passes" pass "$r"

# Over the default line budget: the message names the skill, its size, its budget and the fix.
r="$tmp/over-lines"; make_root "$r" "$default"
add_skill "$r" alpha 501 10
expect "skill over the default line budget fails" fail "$r" \
  "alpha/SKILL.md is 501 lines and 5010 bytes, over its default budget of 500 lines and 20000 bytes. Move detail into references/"

# Over the default byte budget while inside the line budget.
r="$tmp/over-bytes"; make_root "$r" "$default"
add_skill "$r" alpha 100 201
expect "skill over the default byte budget fails" fail "$r" "alpha/SKILL.md is 100 lines and 20100 bytes"

# A last line without a trailing newline still counts as a line.
r="$tmp/no-newline"; make_root "$r" "$default"
add_skill "$r" alpha 500 10
printf 'last' >> "$r/alpha/SKILL.md"
expect "a final unterminated line counts toward the budget" fail "$r" "is 501 lines"

# An over-budget skill at its recorded ceiling passes; other skills keep the default.
r="$tmp/at-ceiling"; make_root "$r" "$default" 'big 600 30000'
add_skill "$r" big 600 50
add_skill "$r" small 10 10
expect "over-budget skill at its recorded ceiling passes" pass "$r" "recorded ceiling: 600 lines, 30000 bytes"

# Growing past the recorded ceiling fails.
r="$tmp/grows"; make_root "$r" "$default" 'big 600 30000'
add_skill "$r" big 601 10
expect "over-budget skill growing past its ceiling fails" fail "$r" \
  "big/SKILL.md is 601 lines and 6010 bytes, over its recorded ceiling of 600 lines and 30000 bytes"

r="$tmp/grows-bytes"; make_root "$r" "$default" 'big 600 30000'
add_skill "$r" big 600 51
expect "over-budget skill growing past its byte ceiling fails" fail "$r" "is 600 lines and 30600 bytes"

# Shrinking passes, with a notice naming the ceiling to record.
r="$tmp/shrinks"; make_root "$r" "$default" 'big 600 30000'
add_skill "$r" big 550 50
expect "over-budget skill that shrinks passes and says what to record" pass "$r" \
  "lower its ceiling in .github/skill-size-budget.tsv to 550 lines and 27500 bytes"

# Shrinking into the default budget passes, with a notice to delete the row.
r="$tmp/shrinks-inside"; make_root "$r" "$default" 'big 600 30000'
add_skill "$r" big 200 10
expect "skill that shrinks inside the default passes and says to delete its row" pass "$r" \
  "big now fits the default budget; delete its row"

# Reference files are not counted.
r="$tmp/references"; make_root "$r" "$default"
add_skill "$r" alpha 100 10
add_skill "$r" alpha 5000 100 references/detail.md
expect "reference files are not counted" pass "$r"

# A ceiling for a skill that does not exist fails, so a removed skill leaves nothing behind.
r="$tmp/stale-row"; make_root "$r" "$default" 'gone 600 30000'
add_skill "$r" alpha 100 10
expect "a ceiling for a missing skill fails" fail "$r" 'has a ceiling for "gone", but there is no gone/SKILL.md'

# The budget file itself is validated, and every problem fails closed.
r="$tmp/no-budget"; make_root "$r" "$default"
add_skill "$r" alpha 100 10
rm "$r/.github/skill-size-budget.tsv"
expect "a missing budget file fails" fail "$r" "skill-size-budget.tsv is missing"

r="$tmp/no-default"; make_root "$r" 'alpha 600 30000'
add_skill "$r" alpha 100 10
expect "a budget without a default row fails" fail "$r" "no default row"

r="$tmp/two-fields"; make_root "$r" "$default" 'alpha 600'
add_skill "$r" alpha 100 10
expect "a row with two fields fails" fail "$r" "expected 3 tab-separated fields, found 2"

r="$tmp/spaces"; make_root "$r" "$default"
printf 'alpha 600 30000\n' >> "$r/.github/skill-size-budget.tsv"
add_skill "$r" alpha 100 10
expect "a row separated by spaces instead of tabs fails" fail "$r" "found 1"

r="$tmp/not-number"; make_root "$r" "$default" 'alpha 600 lots'
add_skill "$r" alpha 100 10
expect "a non-numeric limit fails" fail "$r" "limits must be positive whole numbers"

r="$tmp/zero"; make_root "$r" "$default" 'alpha 0 30000'
add_skill "$r" alpha 100 10
expect "a zero limit fails" fail "$r" "limits must be positive whole numbers"

r="$tmp/duplicate"; make_root "$r" "$default" 'alpha 600 30000' 'alpha 700 30000'
add_skill "$r" alpha 100 10
expect "a repeated skill row fails" fail "$r" '"alpha" is listed more than once'

r="$tmp/bad-name"; make_root "$r" "$default" 'Alpha 600 30000'
add_skill "$r" alpha 100 10
expect "an invalid skill name fails" fail "$r" 'invalid skill name "Alpha"'

# A tree with no skills never passes.
r="$tmp/empty"; make_root "$r" "$default"
expect "a tree with no SKILL.md fails" fail "$r" "No SKILL.md was found"

if [ "$fail" -ne 0 ]; then
  echo "check-skill-size self-test FAILED"
  exit 1
fi
echo "check-skill-size self-test passed"
