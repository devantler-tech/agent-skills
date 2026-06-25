#!/usr/bin/env bash
#
# Self-test for install.sh — pins the load-bearing contracts of the user-facing
# installer that check-readme-index.sh does NOT assert. The index guard calls
# `install.sh --list` only to count entries and resolve in-house rows; it never
# pins install.sh's OWN behaviour, and the `lint-scripts` CI gate runs entirely
# WITH gh present — so a regression in any of the properties below would ship
# undetected and break the installer for every consumer of this shared library:
#   • `--list` (and its `-l` alias) print exactly `<owner/repo> <skill>` per
#     entry, sorted and de-duplicated, parsed only from the `## Skills` section;
#   • `--list` needs NEITHER gh NOR network — it must run cleanly even when gh is
#     absent or broken (the explicitly-documented property; CI alone can't prove
#     it because CI always has gh — a refactor that moved the gh check before the
#     `--list` early-exit would pass CI yet break the documented offline path);
#   • a missing README index and an index that parses to zero entries each fail
#     loudly (non-zero exit), never silently installing nothing.
#
# install.sh resolves its README as `scripts/../README.md` (no env override), so
# every case is a self-contained fixture tree — <case>/scripts/install.sh +
# <case>/README.md — into which the REAL install.sh is copied and run. The test
# therefore exercises the live script content and never touches the real repo or
# needs gh/network. Run as part of the `lint-scripts` CI gate.
set -Eeuo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

# Build a fixture repo root at $1: the REAL install.sh in scripts/, and a README
# whose `## Skills` table body is read from stdin, followed by a SEPARATE
# `## Installing` section carrying an example install command that must NEVER be
# parsed (it proves the parser stays scoped to `## Skills`).
make_root() { # root  <<skills_table_body
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/scripts"
  cp "$here/install.sh" "$root/scripts/"
  {
    printf '# Test catalogue\n\n## Skills\n\n'
    printf '| Skill | Upstream | Install |\n|-------|----------|---------|\n'
    cat
    # Literal markdown backticks, not a command substitution.
    # shellcheck disable=SC2016
    printf '\n## Installing\n\nExample (must NOT be parsed): `gh skill install out/of-scope example`\n'
  } > "$root/README.md"
}

# Assert `install.sh --list` for fixture $2 prints exactly $3.
expect_list() { # name root expected
  local got
  if got=$(bash "$2/scripts/install.sh" --list 2>/dev/null); then
    if [ "$got" = "$3" ]; then
      printf '  ✅ %s — listed as expected\n' "$1"
    else
      printf '  ❌ %s — output mismatch\n     expected: %s\n     got:      %s\n' \
        "$1" "${3//$'\n'/ | }" "${got//$'\n'/ | }"; fail=1
    fi
  else
    printf '  ❌ %s — expected exit 0 but install.sh --list FAILED\n' "$1"; fail=1
  fi
}

# Assert `install.sh $3...` for fixture $2 exits non-zero (fails loudly).
expect_fail() { # name root args...
  local name="$1" root="$2"; shift 2
  if bash "$root/scripts/install.sh" "$@" >/dev/null 2>&1; then
    printf '  ❌ %s — expected non-zero exit but it SUCCEEDED\n' "$name"; fail=1
  else
    printf '  ✅ %s — failed loudly as expected\n' "$name"
  fi
}

# 1. --list output contract: exactly `<owner/repo> <skill>` per entry, sorted,
#    parsed only from `## Skills` (the `## Installing` example is excluded — the
#    output is the two Skills rows, NOT three). devantler-tech sorts before
#    fluxcd, so the order is deterministic.
two="$tmp/two"
make_root "$two" <<'EOF'
| `alpha` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/alpha) | `gh skill install fluxcd/agent-skills alpha` |
| `beta` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/beta) | `gh skill install devantler-tech/agent-skills beta` |
EOF
expected=$'devantler-tech/agent-skills beta\nfluxcd/agent-skills alpha'
expect_list "--list prints sorted <repo> <skill>, scoped to ## Skills" "$two" "$expected"

# 2. The `-l` short flag is equivalent to `--list`.
if got=$(bash "$two/scripts/install.sh" -l 2>/dev/null) && [ "$got" = "$expected" ]; then
  printf '  ✅ -l is an alias for --list — equivalent output\n'
else
  printf '  ❌ -l alias — expected the same output as --list\n'; fail=1
fi

# 3. De-duplication: the same install command twice collapses to one entry
#    (the `sort -u` in the parser), so a copy-pasted row never double-installs.
dup="$tmp/dup"
make_root "$dup" <<'EOF'
| `alpha` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/alpha) | `gh skill install fluxcd/agent-skills alpha` |
| `alpha` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/alpha) | `gh skill install fluxcd/agent-skills alpha` |
EOF
expect_list "duplicate rows de-duplicate to one entry" "$dup" "fluxcd/agent-skills alpha"

# 4. --list needs NEITHER gh NOR network. Run it with a gh shim on PATH that
#    records its own invocation and exits non-zero: --list must still exit 0 with
#    the right output AND never touch gh. This is the property CI alone can't
#    prove (CI always has a real, working gh), so a refactor that moved the gh
#    check ahead of the `--list` early-exit would pass CI yet break the
#    documented offline path — this case catches exactly that.
ghbin="$tmp/ghbin"
mkdir -p "$ghbin"
cat > "$ghbin/gh" <<'STUB'
#!/usr/bin/env bash
touch "$GH_CALLED_MARKER"
echo "gh must not be invoked in --list mode" >&2
exit 99
STUB
chmod +x "$ghbin/gh"
marker="$tmp/gh-was-called"
rm -f "$marker"
if got=$(GH_CALLED_MARKER="$marker" PATH="$ghbin:$PATH" \
      bash "$two/scripts/install.sh" --list 2>/dev/null) \
    && [ "$got" = "$expected" ] && [ ! -e "$marker" ]; then
  printf '  ✅ --list is gh-free — correct output and gh never invoked\n'
else
  printf '  ❌ --list gh-free — expected exit 0, correct output, and no gh call'
  [ -e "$marker" ] && printf ' (gh WAS called)'
  printf '\n'; fail=1
fi

# 5. A missing README index fails loudly (never silently installs nothing).
nordme="$tmp/no-readme"
make_root "$nordme" <<'EOF'
| `alpha` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/alpha) | `gh skill install fluxcd/agent-skills alpha` |
EOF
rm -f "$nordme/README.md"
expect_fail "missing README index exits non-zero" "$nordme" --list

# 6. A `## Skills` section that parses to zero entries fails loudly — even though
#    a valid-looking install command exists in `## Installing`, the scoped parser
#    must not pick it up, so the result is still zero and the script exits 1.
empty="$tmp/no-skills"
make_root "$empty" <<'EOF'
| `alpha` | [`fluxcd/agent-skills`](https://github.com/fluxcd/agent-skills/tree/main/skills/alpha) | (install command missing) |
EOF
expect_fail "zero parsed entries exits non-zero (## Installing not parsed)" "$empty" --list

if [ "$fail" -ne 0 ]; then
  printf '❌ install.sh self-test FAILED\n' >&2
  exit 1
fi
printf '✅ install.sh self-test passed (6 cases)\n'
