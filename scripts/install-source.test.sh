#!/usr/bin/env bash
# Exercise the actual installer against bounded native-CLI response fixtures.
set -Eeuo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/scripts" "$work/bin"
cp "$here/install.sh" "$here/readme-index.sh" "$here/readme-index.awk" "$work/root/scripts/"
cat > "$work/root/README.md" <<'EOF'
## Skills

| Skill | Upstream | Install |
|---|---|---|
| `alpha` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/alpha) | `gh skill install devantler-tech/agent-skills alpha` |
| `beta` | [`devantler-tech/agent-plugins`](https://github.com/devantler-tech/agent-plugins/tree/v1.0.0/beta) | `gh skill install devantler-tech/agent-plugins beta` |
EOF
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -eu
# Model private staging separately from final user-scope call assertions.
if [[ "${1:-} ${2:-}" == 'skill install' && " $* " == *' --dir '* ]]; then
  stage=''
  for ((i=1;i<=$#;i++)); do if [[ ${!i} == --dir ]]; then i=$((i+1)); stage=${!i}; fi; done
  slug=${4%/SKILL.md}; slug=${slug##*/}
  mkdir -p "$stage/$slug"
  printf -- '---\nname: %s\ndescription: Fixture.\n---\n' "$slug" > "$stage/$slug/SKILL.md"
  exit 0
fi
printf '%s\n' "${GH_HOST:-unset}" >> "$CALL_HOSTS"
if [[ "$1 $2" == 'skill --help' ]]; then exit 0; fi
if [[ "$1" == api ]]; then
  printf 'api\n' >> "$CALL_ORDER"
  case "$*" in
    *agent-skills/commits/main*) printf '{"sha":"%s"}\n' '1111111111111111111111111111111111111111' ;;
    *agent-plugins/commits/v1.0.0*)
      case "${RESPONSE_MODE:-good}" in
        good) printf '{"sha":"%s"}\n' '2222222222222222222222222222222222222222' ;;
        partial) printf '{"sha":"%s"}\n' '2222222222222222222222222222222222222222'; exit 1 ;;
        multiple) printf '{"sha":"%s"}\n{"sha":"%s"}\n' '2222222222222222222222222222222222222222' '3333333333333333333333333333333333333333' ;;
        malformed) printf '{"sha":"%s\\n"}\n' '2222222222222222222222222222222222222222' ;;
      esac ;;
    *) exit 1 ;;
  esac
  exit 0
fi
[[ "$1 $2" == 'skill install' ]] || exit 1
printf 'install\n' >> "$CALL_ORDER"
printf '<%s>' "$@" >> "$INSTALL_CALLS"; printf '\n' >> "$INSTALL_CALLS"
EOF
chmod +x "$work/bin/gh"
export CALL_HOSTS="$work/hosts" CALL_ORDER="$work/order" INSTALL_CALLS="$work/installs"
fail=0
check() { if "$@"; then printf 'PASS %s\n' "$label"; else printf 'FAIL %s\n' "$label"; fail=$((fail+1)); fi; }
run() {
  : > "$CALL_HOSTS"; : > "$CALL_ORDER"; : > "$INSTALL_CALLS"
  rc=0
  PATH="$work/bin:$PATH" GH_HOST=enterprise.invalid RESPONSE_MODE="$1" bash "$work/root/scripts/install.sh" codex > "$work/out" 2> "$work/err" || rc=$?
}
run good
label='branch and tag resolve to immutable pins'; check test "$rc" -eq 0
printf '%s\n' '<skill><install><devantler-tech/agent-plugins><beta/SKILL.md><--pin><2222222222222222222222222222222222222222><--agent><codex><--scope><user><--force>' '<skill><install><devantler-tech/agent-skills><alpha/SKILL.md><--pin><1111111111111111111111111111111111111111><--agent><codex><--scope><user><--force>' > "$work/want"
label='installs use exactly the named source commits'; check cmp -s "$work/want" "$INSTALL_CALLS"
printf 'api\napi\ninstall\ninstall\n' > "$work/want-order"
label='every source resolves before any install'; check cmp -s "$work/want-order" "$CALL_ORDER"
label='every native request uses github.com'; check test "$(sort -u "$CALL_HOSTS")" = github.com
for mode in partial multiple malformed; do
  run "$mode"
  label="$mode source response fails verification"; check test "$rc" -ne 0
  label="$mode source response leaves all installs untouched"; check test ! -s "$INSTALL_CALLS"
done
# One catalogue source must remain one snapshot even if its branch moves while
# other skills are resolving. The actual installer must bind all siblings together.
cat >> "$work/root/README.md" <<'EOF'
| `gamma` | [`devantler-tech/agent-skills`](https://github.com/devantler-tech/agent-skills/tree/main/gamma) | `gh skill install devantler-tech/agent-skills gamma` |
EOF
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -eu
# Model private staging separately from final user-scope call assertions.
if [[ "${1:-} ${2:-}" == 'skill install' && " $* " == *' --dir '* ]]; then
  stage=''
  for ((i=1;i<=$#;i++)); do if [[ ${!i} == --dir ]]; then i=$((i+1)); stage=${!i}; fi; done
  slug=${4%/SKILL.md}; slug=${slug##*/}
  mkdir -p "$stage/$slug"
  printf -- '---\nname: %s\ndescription: Fixture.\n---\n' "$slug" > "$stage/$slug/SKILL.md"
  exit 0
fi
if [[ "$1 $2" == 'skill --help' ]]; then exit 0; fi
if [[ "$1" == api ]]; then
  printf '%s\n' "$*" >> "$CALL_ORDER"
  case "$*" in
    *agent-skills/commits/main*)
      if grep -q agent-skills "$INSTALL_CALLS"; then exit 1; fi
      count=$(grep -c agent-skills "$CALL_ORDER")
      if [[ $count == 1 ]]; then printf '{"sha":"%s"}\n' '1111111111111111111111111111111111111111'
      else printf '{"sha":"%s"}\n' '3333333333333333333333333333333333333333'; fi ;;
    *agent-plugins/commits/v1.0.0*) printf '{"sha":"%s"}\n' '2222222222222222222222222222222222222222' ;;
    *) exit 1 ;;
  esac
  exit 0
fi
[[ "$1 $2" == 'skill install' ]] || exit 1
printf '<%s>' "$@" >> "$INSTALL_CALLS"; printf '\n' >> "$INSTALL_CALLS"
EOF
run good
label='moving catalogue branch still installs a consistent snapshot'; check test "$rc" -eq 0
label='each repository and ref is resolved once'; check test "$(grep -c agent-skills "$CALL_ORDER")" -eq 1
label='all sibling skills use the same frozen commit'; check test "$(grep -c '<--pin><1111111111111111111111111111111111111111>' "$INSTALL_CALLS")" -eq 2
printf 'source-install regressions: %s failure(s)\n' "$fail"
test "$fail" -eq 0
