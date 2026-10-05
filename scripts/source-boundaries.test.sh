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
# Model private staging separately from final user-scope call assertions.
if [[ "${1:-} ${2:-}" == 'skill install' && " $* " == *' --dir '* ]]; then
  if [[ -n ${STAGE_TRACE:-} ]]; then printf 'staged\n' >> "$STAGE_TRACE"; fi
  stage=''
  for ((i=1;i<=$#;i++)); do if [[ ${!i} == --dir ]]; then i=$((i+1)); stage=${!i}; fi; done
  slug=${4%/SKILL.md}; slug=${slug##*/}
  mkdir -p "$stage/$slug"
  printf -- '---\nname: %s\ndescription: Fixture.\n---\n' "$slug" > "$stage/$slug/SKILL.md"
  exit 0
fi
if [[ "$1 $2" == 'skill --help' ]]; then exit 0; fi
if [[ "$1" == api ]]; then
  if [[ $2 == */commits/* ]]; then printf 'HTTP/1.1 200 OK\r\n\r\n{"sha":"1111111111111111111111111111111111111111"}\n'; else cat "$RESPONSE_FILE"; fi
  exit "${RESPONSE_STATUS:-0}"
fi
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
# Observe the original bytes before Bash can discard NULs or jq can repair UTF-8.
# A malformed or failed response must not reach even the private native installer.
for interpreter in /bin/bash bash; do
  for kind in valid newline replacement astral nul-key nul-sha nul-tail invalid-utf8 above-unicode obsolete-five obsolete-six partial-failure; do
    root="$work/raw-${interpreter##*/}-$kind"; fixture "$root" main
    status=0; expected=reject
    case "$kind" in
      valid) printf '{"sha":"%s"}' "$one" > "$root/response"; expected=pass ;;
      newline) printf '{"sha":"%s"}\n\n' "$one" > "$root/response"; expected=pass ;;
      replacement) printf '{"sha":"%s","message":"\357\277\275"}' "$one" > "$root/response"; expected=pass ;;
      astral) printf '{"sha":"%s","message":"\360\237\230\200"}' "$one" > "$root/response"; expected=pass ;;
      nul-key) printf '{"sh\000a":"%s"}' "$one" > "$root/response" ;;
      nul-sha) printf '{"sha":"%s\000"}' "$one" > "$root/response" ;;
      nul-tail) printf '{"sha":"%s"}\000' "$one" > "$root/response" ;;
      invalid-utf8) printf '{"sha":"%s","message":"\377"}' "$one" > "$root/response" ;;
      above-unicode) printf '{"sha":"%s","message":"\364\220\200\200"}' "$one" > "$root/response" ;;
      obsolete-five) printf '{"sha":"%s","message":"\370\210\200\200\200"}' "$one" > "$root/response" ;;
      obsolete-six) printf '{"sha":"%s","message":"\374\204\200\200\200\200"}' "$one" > "$root/response" ;;
      partial-failure) printf '{"sha":"%s"}' "$one" > "$root/response"; status=1 ;;
    esac
    : > "$root/stages"; : > "$root/installs"; rc=0
    PATH="$root/bin:$PATH" RESPONSE_FILE="$root/response" RESPONSE_STATUS="$status" \
      STAGE_TRACE="$root/stages" INSTALL_TRACE="$root/installs" \
      "$interpreter" "$root/scripts/install.sh" codex > "$root/out" 2>&1 || rc=$?
    if { [[ $expected == pass && $rc -eq 0 && -s $root/stages && -s $root/installs ]]; } ||
       { [[ $expected == reject && $rc -ne 0 && ! -s $root/stages && ! -s $root/installs ]]; }; then
      printf 'PASS raw-response-%s-%s\n' "$interpreter" "$kind"
    else printf 'FAIL raw-response-%s-%s (exit=%s)\n' "$interpreter" "$kind" "$rc"; fail=$((fail+1)); fi
  done
done
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
for kind in empty-timeout html-rate-limit empty-server html-server malformed-server recovering-server; do
  root="$work/$kind"; fixture "$root" main
  sed 's@devantler-tech/agent-skills@test/source@g' "$root/README.md" > "$root/new"; mv "$root/new" "$root/README.md"
  : > "$root/calls"
  cat > "$root/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -eu
if [[ $2 == */commits/* ]]; then printf 'HTTP/1.1 200 OK\r\n\r\n{"sha":"1111111111111111111111111111111111111111"}\n'; exit 0; fi
printf 'call\n' >> "$RETRY_TRACE"
case "$RETRY_KIND" in
  empty-timeout) status=408; body='' ;;
  html-rate-limit) status=429; body='<html>Try later</html>' ;;
  empty-server) status=503; body='' ;;
  html-server) status=502; body='<html>Unavailable</html>' ;;
  malformed-server) status=504; body='{"message":' ;;
  recovering-server)
    if [ "$(wc -l < "$RETRY_TRACE")" -gt 1 ]; then
      printf 'HTTP/1.1 200 OK\r\n\r\n{"type":"file","name":"SKILL.md","path":"alpha/SKILL.md"}\n'
      exit 0
    fi
    status=503; body='<html>Unavailable</html>' ;;
  *) exit 2 ;;
esac
printf 'HTTP/1.1 %s Error\r\n\r\n%s\n' "$status" "$body"
exit 1
STUB
  chmod +x "$root/bin/gh"
  rc=0
  PATH="$root/bin:$PATH" RETRY_TRACE="$root/calls" RETRY_KIND="$kind" UPSTREAM_RETRY_SLEEP=true \
    bash "$root/scripts/check-upstream-skills.sh" > "$root/out" 2>&1 || rc=$?
  expected_calls=3; [ "$kind" != recovering-server ] || expected_calls=2
  if [ "$rc" -eq 0 ] && [ "$(wc -l < "$root/calls")" -eq "$expected_calls" ] && \
      { { [ "$kind" = recovering-server ] && grep -q '  ok ' "$root/out"; } ||
        { [ "$kind" != recovering-server ] && grep -q 'transient' "$root/out"; }; }; then
    printf 'PASS retry-%s\n' "$kind"
  else printf 'FAIL retry-%s (exit=%s)\n' "$kind" "$rc"; fail=$((fail+1)); fi
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
