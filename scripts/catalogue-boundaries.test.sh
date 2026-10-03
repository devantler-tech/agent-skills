#!/usr/bin/env bash
# Exercise catalogue options and exact path selection through the shipped installer.
set -euo pipefail
here=${CATALOGUE_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/scripts" "$work/bin"
cp "$here/install.sh" "$here/readme-index.sh" "$here/readme-index.awk" "$work/root/scripts/"
fail=0
# Write a complete catalogue with a supplied literal command suffix.
catalogue() {
  # shellcheck disable=SC2016 # Markdown code spans are literal data.
  printf '## Skills\n\n| Skill | Upstream | Install |\n|---|---|---|\n| `alpha` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/nested/alpha) | `gh skill install devantler-tech/agent-skills alpha%s` |\n' "$1" > "$work/root/README.md"
}
# Assert complete parser acceptance or refusal before any emitted install entry.
options() {
  local name=$1 expected=$2 suffix=$3 rc=0
  catalogue "$suffix"
  bash "$work/root/scripts/install.sh" --list > "$work/out" 2> "$work/err" || rc=$?
  if { [ "$expected" = pass ] && [ "$rc" -eq 0 ]; } ||
     { [ "$expected" = reject ] && [ "$rc" -ne 0 ] && [ ! -s "$work/out" ]; }; then
    printf 'PASS %s\n' "$name"
  else printf 'FAIL %s exit=%s\n' "$name" "$rc"; fail=$((fail+1)); fi
}
options ordinary pass ''
options documented pass ' --agent codex --scope user --force --allow-hidden-dirs --pin main'
options equals-form pass ' --agent=codex --scope=project --pin=main'
options unknown-option reject ' --invented value'
options missing-agent reject ' --agent'
options missing-pin reject ' --pin'
options missing-value-before-option reject ' --agent --force'
options invalid-scope reject ' --scope nowhere'
options extra-positional reject ' --force other'
options conflicting-pin reject ' --pin v2.0.0'
options conflicting-equals-pin reject ' --pin=v2.0.0'
options repeated-pin reject ' --pin main --pin main'
options local-source-conflict reject ' --from-local'
options selection-conflict reject ' --all'
# A name-only call intentionally substitutes another discovered alpha. The exact
# catalogue path returns the advertised bytes and retains the frozen source commit.
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -eu
if [ "$1 $2" = 'skill --help' ]; then exit 0; fi
if [ "$1" = api ]; then printf '{"sha":"1111111111111111111111111111111111111111"}\n'; exit 0; fi
[ "$1 $2" = 'skill install' ] || exit 1
printf '<%s>' "$@" > "$INSTALL_CALL"
if [ "$4" = nested/alpha/SKILL.md ]; then printf advertised > "$INSTALLED_BYTES"
else printf substituted > "$INSTALLED_BYTES"; fi
STUB
chmod +x "$work/bin/gh"
catalogue ''
export INSTALL_CALL="$work/call" INSTALLED_BYTES="$work/installed"
PATH="$work/bin:$PATH" bash "$work/root/scripts/install.sh" codex > "$work/install-out"
if [ "$(cat "$INSTALLED_BYTES")" = advertised ] &&
   grep -q '<--pin><1111111111111111111111111111111111111111>' "$INSTALL_CALL"; then
  printf 'PASS exact path cannot substitute a same-name skill\n'
else printf 'FAIL exact path substitution\n'; fail=$((fail+1)); fi
printf 'catalogue boundaries: %s failure(s)\n' "$fail"
test "$fail" -eq 0
