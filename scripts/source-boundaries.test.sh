#!/usr/bin/env bash
set -euo pipefail
here=${SOURCE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0
fixture() {
  local root=$1 ref=$2
  mkdir -p "$root/scripts" "$root/bin" "$root/alpha"
  cp "$here"/*.sh "$here/readme-index.awk" "$root/scripts/"
  # shellcheck disable=SC2016 # The catalogue contains literal Markdown command examples.
  printf '## Skills\n\n| Skill | Upstream | Install |\n|---|---|---|\n| `alpha` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/%s/alpha) | `gh skill install devantler-tech/agent-skills alpha` |\n' "$ref" > "$root/README.md"
  printf 'fixture\n' > "$root/alpha/SKILL.md"
  cat > "$root/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -eu
if [[ "$1 $2" == 'skill --help' ]]; then exit 0; fi
if [[ "$1" == api ]]; then cat "$RESPONSE_FILE"; exit 0; fi
printf 'installed\n' >> "$INSTALL_TRACE"
STUB
  chmod +x "$root/bin/gh"
}
install_case() {
  local name=$1 ref=$2 response=$3 expect=$4 root="$work/$1" rc=0
  fixture "$root" "$ref"
  printf '%s\n' "$response" > "$root/response"
  : > "$root/installs"
  PATH="$root/bin:$PATH" RESPONSE_FILE="$root/response" INSTALL_TRACE="$root/installs" bash "$root/scripts/install.sh" codex > "$root/out" 2>&1 || rc=$?
  if { [ "$expect" = pass ] && [ "$rc" -eq 0 ] && [ -s "$root/installs" ]; } ||
     { [ "$expect" = reject ] && [ "$rc" -ne 0 ] && [ ! -s "$root/installs" ]; }; then
    printf 'PASS %s\n' "$name"
  else printf 'FAIL %s (exit=%s)\n' "$name" "$rc"; fail=$((fail+1)); fi
}
one=1111111111111111111111111111111111111111
two=2222222222222222222222222222222222222222
install_case literal-commit "$one" "{\"sha\":\"$one\"}" pass
install_case mismatched-literal-commit "$one" "{\"sha\":\"$two\"}" reject
install_case repeated-source-sha main "{\"sha\":\"$one\",\"sha\":\"$two\"}" reject
install_case branch-source main "{\"sha\":\"$one\"}" pass
install_case repeated-source-container main "{\"sha\":\"$one\",\"commit\":{},\"commit\":{\"message\":\"other\"}}" reject
install_case escaped-repeated-sha main "{\"sha\":\"$one\",\"sh\\u0061\":\"$two\"}" reject
install_case malformed-source main '{"sha":' reject
root="$work/upstream"; fixture "$root" main
sed 's@devantler-tech/agent-skills@test/source@g' "$root/README.md" > "$root/new"; mv "$root/new" "$root/README.md"
for kind in clean repeated-path repeated-container; do
  case "$kind" in
    clean) payload='{"type":"file","name":"SKILL.md","path":"alpha/SKILL.md"}' ;;
    repeated-path) payload='{"type":"file","name":"SKILL.md","path":"different/SKILL.md","path":"alpha/SKILL.md"}' ;;
    repeated-container) payload='{"type":"file","name":"SKILL.md","path":"alpha/SKILL.md","links":{},"links":{"self":"other"}}' ;;
  esac
  printf 'HTTP/1.1 200 OK\r\n\r\n%s\n' "$payload" > "$root/response"
  rc=0
  PATH="$root/bin:$PATH" RESPONSE_FILE="$root/response" INSTALL_TRACE="$root/installs" bash "$root/scripts/check-upstream-skills.sh" > "$root/out" 2>&1 || rc=$?
  if { [ "$kind" = clean ] && [ "$rc" -eq 0 ] && grep -q '  ok ' "$root/out"; } ||
     { [ "$kind" != clean ] && [ "$rc" -ne 0 ] && grep -q invalid-responses=1 "$root/out" && ! grep -q '  ok ' "$root/out"; }; then
    printf 'PASS upstream-%s\n' "$kind"
  else printf 'FAIL upstream-%s (exit=%s)\n' "$kind" "$rc"; fail=$((fail+1)); fi
done
root="$work/inventory"; fixture "$root" main
mkdir -p "$root/orphan"; printf 'unindexed\n' > "$root/orphan/SKILL.md"
cat > "$root/bin/find" <<'STUB'
#!/usr/bin/env bash
printf './alpha/SKILL.md\0'
STUB
chmod +x "$root/bin/find"
rc=0
PATH="$root/bin:$PATH" bash "$root/scripts/check-readme-index.sh" > "$root/out" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q inventory "$root/out"; then printf 'PASS omitted-local-skill\n'
else printf 'FAIL omitted-local-skill (exit=%s)\n' "$rc"; fail=$((fail+1)); fi
root="$work/hidden-inventory"; fixture "$root" main
mkdir -p "$root/.hidden"; printf 'unindexed\n' > "$root/.hidden/SKILL.md"
rc=0
bash "$root/scripts/check-readme-index.sh" > "$root/out" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q 'missing from the README index' "$root/out"; then printf 'PASS hidden-unindexed-skill\n'
else printf 'FAIL hidden-unindexed-skill (exit=%s)\n' "$rc"; fail=$((fail+1)); fi
printf 'Source boundaries: %s failure(s)\n' "$fail"
test "$fail" -eq 0
