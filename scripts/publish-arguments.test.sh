#!/usr/bin/env bash
# Ambiguous release selectors must fail before any native GitHub operation.
set -euo pipefail
here=${PUBLISH_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf 'called\n' >> "$CALLS"
exit 1
STUB
chmod +x "$work/bin/gh"
export CALLS="$work/calls"
fail=0
# Require a usage error with no GitHub calls or publication output for one invocation.
reject() {
  local label=$1 rc=0
  shift
  : > "$CALLS"
  PATH="$work/bin:$PATH" GITHUB_REPOSITORY=owner/repo GITHUB_SHA=1111111111111111111111111111111111111111 \
    bash "$here/publish-skills-release.sh" "$@" > "$work/out" 2> "$work/err" || rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$CALLS" ] && [ ! -s "$work/out" ]; then printf 'PASS %s\n' "$label"
  else printf 'FAIL %s exit=%s calls=%s\n' "$label" "$rc" "$(wc -l < "$CALLS")"; fail=$((fail+1)); fi
}
reject duplicate-tag --tag v1.0.0 --tag v2.0.0
reject duplicate-repository --tag v1.0.0 --repo owner/repo --repo other/repo
reject duplicate-commit --tag v1.0.0 --expected-commit 1111111111111111111111111111111111111111 --expected-commit 2222222222222222222222222222222222222222
reject empty-then-tag --tag '' --tag v1.0.0
reject missing-value-before-help --tag --help
reject help-before-invalid --help --invented
reject help-after-selectors --tag v1.0.0 --help
for selector in '/owner/repo' 'owner/repo/other' 'owner/../other' 'owner/repo?ref=other' 'owner/repo#fragment' 'owner/repo%2fother' 'owner//repo' '-owner/repo' 'owner-/repo' 'owner/repo name'; do
  reject "repository $selector" --tag v1.0.0 --repo "$selector"
done
# Valid selectors proceed to the independently failed API boundary. These are
# argument acceptance controls, not evidence of a completed publication.
for selector in 'Owner/Repo_name.test' 'owner/repo' 'a/repo'; do
  : > "$CALLS"; rc=0
  PATH="$work/bin:$PATH" GITHUB_REPOSITORY=other/repo GITHUB_SHA=2222222222222222222222222222222222222222 \
    bash "$here/publish-skills-release.sh" --tag v1.0.0 --repo "$selector" \
    --expected-commit 1111111111111111111111111111111111111111 > "$work/out" 2> "$work/err" || rc=$?
  if [ "$rc" -eq 1 ] && [ -s "$CALLS" ]; then printf 'PASS valid override %s\n' "$selector"
  else printf 'FAIL valid override %s\n' "$selector"; fail=$((fail+1)); fi
done
: > "$CALLS"
PATH="$work/bin:$PATH" bash "$here/publish-skills-release.sh" --help > "$work/out" 2> "$work/err"
if [ ! -s "$CALLS" ]; then printf 'PASS standalone help\n'
else fail=$((fail+1)); fi
: > "$CALLS"; rc=0
PATH="$work/bin:$PATH" GITHUB_REPOSITORY='owner/repo?other' GITHUB_SHA=1111111111111111111111111111111111111111 \
  bash "$here/publish-skills-release.sh" --tag v1.0.0 > "$work/out" 2> "$work/err" || rc=$?
if [ "$rc" -eq 2 ] && [ ! -s "$CALLS" ]; then printf 'PASS environment repository validation\n'
else printf 'FAIL environment repository validation\n'; fail=$((fail+1)); fi
printf 'publish argument boundaries: %s failure(s)\n' "$fail"
test "$fail" -eq 0
