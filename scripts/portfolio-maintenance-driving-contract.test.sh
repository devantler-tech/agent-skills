#!/usr/bin/env bash
# Contract test for who may drive a PR under the maintainer's own login.
#
# Whether the engineer may update, rebase, promote, merge or close such a PR is a
# deployment fact — the Trust gate's maintainer-PR driving fact — not a skill
# default. A deployment that keeps hands-off wants the interactive-session marker
# to revoke driving; one that gives the engineer every PR wants it to change
# attribution only (devantler-tech/agent-plugins#201). An absolute "leave it
# hands-off" sentence here would contradict the second kind of deployment, and a
# missing fail-closed default would let an undeclared deployment gain every PR.
#
# Each required clause is asserted against the skill, and each is then removed
# from a copy to prove the assertion actually fails without it.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="$repo_root/portfolio-maintenance/SKILL.md"
tmp="$(mktemp -d)"
# Bash 3.2 can report an errexit abort as success once an EXIT trap has run, so the
# trap refuses to exit 0 unless the script reached its final line.
completed=0
trap 'rm -rf "$tmp"; [ "$completed" = 1 ] || exit 1' EXIT

required_clauses=(
	"whether you may drive a pr under the maintainer's own login is the trust gate's maintainer-pr driving fact."
	"under \`hands-off\` — also the answer when the fact is absent, unreadable, or unrecognised —"
	"a pr you have no record of creating is not yours"
	"one you created whose body now carries the interactive-session marker"
	"under \`attribution-only\`, the deployment gives you every such pr under its own active-work rules"
	"an actionable maintainer comment on one you did not create stays a named blocker on that pr until it is satisfied or withdrawn."
)
forbidden_clauses=(
	"a pr you have no record of creating is not yours: leave it hands-off"
)

normalize() {
	LC_ALL=C awk '{
		line=tolower($0)
		gsub(/\*/, "", line)
		gsub(/[[:space:]]+/, " ", line)
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
		if (line != "") printf "%s ", line
	}
	# One terminated line, so an awk pass that removes nothing reproduces it byte for byte and the
	# "found nothing to remove" guard below can actually fire.
	END { printf "\n" }' "$1"
}

# check <file> — exit 0 when every required clause is present and no forbidden one is.
check() {
	local text clause
	text="$(normalize "$1")"
	[ -n "$text" ] || return 1
	for clause in "${required_clauses[@]}"; do
		[[ $text == *"$clause"* ]] || return 1
	done
	for clause in "${forbidden_clauses[@]}"; do
		[[ $text != *"$clause"* ]] || return 1
	done
}

fail=0
[ -r "$skill" ] || { echo "cannot read $skill" >&2; exit 1; }

if check "$skill"; then
	echo "  ✓ portfolio-maintenance defers PR driving to the Trust gate fact"
else
	echo "  ✗ portfolio-maintenance must defer PR driving to the Trust gate's maintainer-PR driving fact, default to hands-off, and keep the named-blocker guard" >&2
	fail=1
fi

# Mutation cases: the skill with one required clause removed must fail. The skill's
# prose wraps, so each clause is removed from the normalised text, not the file.
normalize "$skill" > "$tmp/normalized.md"
for clause in "${required_clauses[@]}"; do
	awk -v clause="$clause" '{
		position = index($0, clause)
		if (position > 0) $0 = substr($0, 1, position - 1) substr($0, position + length(clause))
		print
	}' "$tmp/normalized.md" > "$tmp/mutant.md"
	if cmp -s "$tmp/normalized.md" "$tmp/mutant.md"; then
		echo "  ✗ mutation found nothing to remove for: $clause" >&2
		fail=1
	elif check "$tmp/mutant.md"; then
		echo "  ✗ check passed with a required clause removed: $clause" >&2
		fail=1
	else
		echo "  ✓ removing a required clause fails: ${clause:0:60}…"
	fi
done

# Restoring the old absolute sentence must fail even with every required clause present.
printf '%s a pr you have no record of creating is not yours: leave it hands-off even if it looks machine-authored.\n' \
	"$(cat "$tmp/normalized.md")" > "$tmp/absolute.md"
if check "$tmp/absolute.md"; then
	echo "  ✗ check passed with the absolute hands-off sentence restored" >&2
	fail=1
else
	echo "  ✓ restoring the absolute hands-off sentence fails"
fi

if [ "$fail" -ne 0 ]; then
	echo "portfolio-maintenance driving contract: FAIL" >&2
	exit 1
fi
completed=1
echo "portfolio-maintenance driving contract: OK"
