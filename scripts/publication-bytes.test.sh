#!/usr/bin/env bash
# Observe the production publication entrypoint; only forge I/O is replaced.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/responses" "$work/repo"
git -C "$work/repo" init -q
printf 'fixture\n' > "$work/repo/README.md"
git -C "$work/repo" add README.md
git -C "$work/repo" -c user.name=Fixture -c user.email=fixture@example.test \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm fixture
git -C "$work/repo" remote add origin https://github.com/fixture/source.git
commit=$(git -C "$work/repo" rev-parse HEAD)
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PUB_BYTES_WORK/calls"
case ${1:-}:${2:-} in
  api:repos/fixture/source/git/ref/tags/v1.0.0)
    if [ "$PUB_BYTES_BOUNDARY" = absence ] || [ "${PUB_BYTES_FRESH:-false}" = true ]; then
      printf 'HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n'
      cat "$PUB_BYTES_WORK/responses/absence"; exit 1
    fi
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n'
    part=tag-ref ;;
  api:repos/fixture/source/commits/tags/v1.0.0) part=tag-commit ;;
  release:view) part=release ;;
  api:repos/fixture/source/git/refs|release:create)
    printf '%s\n' "$*" >> "$PUB_BYTES_WORK/writes"; exit 0 ;;
  skill:publish)
    [ "$*" = 'skill publish --dry-run' ] || exit 91
    printf 'validation\n' >> "$PUB_BYTES_WORK/validation"; exit 0 ;;
  *) printf 'unexpected forge command\n' >&2; exit 91 ;;
esac
cat "$PUB_BYTES_WORK/responses/$part"
if [ "$PUB_BYTES_BOUNDARY" = "$part" ] && [ "$PUB_BYTES_KIND" = failed-producer ]; then exit 1; fi
STUB
chmod +x "$work/bin/gh"
healthy() {
  printf '{"ref":"refs/tags/v1.0.0","object":{"type":"commit","sha":"%s"}}\n' "$commit" > "$work/responses/tag-ref"
  printf '{"sha":"%s"}\n' "$commit" > "$work/responses/tag-commit"
  printf '{"tagName":"v1.0.0","isDraft":false}\n' > "$work/responses/release"
  printf '{"message":"Not Found"}\n' > "$work/responses/absence"
  : > "$work/writes"; : > "$work/validation"; : > "$work/calls"
}
fail=0
for boundary in tag-ref tag-commit release absence; do
  for kind in healthy healthy-unicode healthy-escaped-control nul-key nul-value nul-tail invalid-utf8 raw-control raw-newline duplicate failed-producer escaped-identity-nul escaped-identity-newline; do
    # A 404 is intentionally a failed producer; its exact status/body is absence proof.
    if [ "$boundary:$kind" = absence:failed-producer ]; then continue; fi
    healthy
    rm -rf "$work/scratch"; mkdir "$work/scratch"
    response="$work/responses/$boundary"
    case "$kind" in
      healthy-unicode) sed 's/}$/,"retained":"Déploiement"}/' "$response" > "$work/modified"; mv "$work/modified" "$response" ;;
      healthy-escaped-control) sed 's/}$/,"retained":"\\u0000"}/' "$response" > "$work/modified"; mv "$work/modified" "$response" ;;
      nul-key|nul-value|invalid-utf8|raw-control|raw-newline)
        # Put malformed original bytes beside a complete plausible identity.
        # Bash/jq repair must not convert this response into publication proof.
        sed 's/}$/,"retained":"PLACEHOLDER"}/' "$response" > "$work/modified"
        case "$kind" in
          nul-key) sed 's/"retained":"PLACEHOLDER"/"rePLACEHOLDERtained":"safe"/' "$work/modified" > "$work/key"; mv "$work/key" "$work/modified"; byte='\000' ;;
          nul-value) byte='\000' ;;
          invalid-utf8) byte='\377' ;;
          raw-control) byte='\001' ;;
          raw-newline) byte='\012' ;;
        esac
        # Split around the marker so printf writes the original byte directly.
        prefix=$(sed 's/PLACEHOLDER.*//' "$work/modified")
        suffix=$(sed 's/.*PLACEHOLDER//' "$work/modified")
        printf '%s%b%s\n' "$prefix" "$byte" "$suffix" > "$response" ;;
      nul-tail) printf '\000' >> "$response" ;;
      duplicate) sed 's/^{/{"repeat":true,"repeat":false,/' "$response" > "$work/modified"; mv "$work/modified" "$response" ;;
      escaped-identity-*)
        case "$boundary" in tag-ref) field='.ref' ;; tag-commit) field='.sha' ;; release) field='.tagName' ;; absence) field='.message' ;; esac
        case "$kind" in escaped-identity-nul) suffix='"\u0000"' ;; escaped-identity-newline) suffix='"\n"' ;; esac
        jq "$field += $suffix" "$response" > "$work/modified"; mv "$work/modified" "$response" ;;
    esac
    rc=0
    (cd "$work/repo" && env PATH="$work/bin:$PATH" TMPDIR="$work/scratch" PUB_BYTES_WORK="$work" \
      PUB_BYTES_BOUNDARY="$boundary" PUB_BYTES_KIND="$kind" \
      "$BASH" "$here/publish-skills-release.sh" --tag v1.0.0 --repo fixture/source --expected-commit "$commit") \
      > "$work/out" 2> "$work/err" || rc=$?
    good=false
    if [[ "$kind" == healthy* ]]; then
      if [ "$rc" -eq 0 ] && grep -Fq 'verified v1.0.0 is published' "$work/out"; then
        if [ "$boundary" != absence ] || { [ -s "$work/validation" ] && [ "$(wc -l < "$work/writes" | tr -d ' ')" = 2 ]; }; then good=true; fi
      fi
    elif [ "$rc" -ne 0 ] && ! grep -Fq 'verified v1.0.0 is published' "$work/out" && [ ! -s "$work/writes" ]; then
      good=true
      if [ "$boundary" = absence ] && [ -s "$work/validation" ]; then good=false; fi
    fi
    # Apple Git may write xcrun_db in TMPDIR; assert cleanup of publisher-owned trees.
    if [ -n "$(find "$work/scratch" -mindepth 1 -maxdepth 1 -name 'skill-publication.*' -print -quit)" ]; then
      printf 'FAIL publication-%s-%s leaked private observations\n' "$boundary" "$kind"
      good=false
    fi
    if [ "$good" = true ]; then printf 'PASS publication-%s-%s\n' "$boundary" "$kind"
    else printf 'FAIL publication-%s-%s exit=%s\n' "$boundary" "$kind" "$rc"; cat "$work/out" "$work/err"; fail=$((fail+1)); fi
  done
done
# Fresh publication checks the tag commit after reservation. A malformed decoded
# identity must refuse release creation, even though the absence proof was valid.
for kind in healthy escaped-identity-nul escaped-identity-newline; do
  healthy
  rm -rf "$work/scratch"; mkdir "$work/scratch"
  case "$kind" in
    escaped-identity-nul) suffix='"\u0000"' ;;
    escaped-identity-newline) suffix='"\n"' ;;
    healthy) suffix='""' ;;
  esac
  jq ".sha += $suffix" "$work/responses/tag-commit" > "$work/modified"
  mv "$work/modified" "$work/responses/tag-commit"
  rc=0
  (cd "$work/repo" && env PATH="$work/bin:$PATH" TMPDIR="$work/scratch" PUB_BYTES_WORK="$work" \
    PUB_BYTES_BOUNDARY=tag-commit PUB_BYTES_FRESH=true PUB_BYTES_KIND="$kind" \
    "$BASH" "$here/publish-skills-release.sh" --tag v1.0.0 --repo fixture/source --expected-commit "$commit") \
    > "$work/out" 2> "$work/err" || rc=$?
  good=false
  if [ "$kind" = healthy ]; then
    if [ "$rc" -eq 0 ] && grep -Fq 'verified v1.0.0 is published' "$work/out" && [ "$(wc -l < "$work/writes" | tr -d ' ')" = 2 ]; then good=true; fi
  elif [ "$rc" -ne 0 ] && ! grep -Fq 'verified v1.0.0 is published' "$work/out" &&
    [ "$(wc -l < "$work/writes" | tr -d ' ')" = 1 ] && ! grep -Fq 'release create' "$work/writes"; then good=true; fi
  if [ -n "$(find "$work/scratch" -mindepth 1 -maxdepth 1 -name 'skill-publication.*' -print -quit)" ]; then good=false; fi
  if [ "$good" = true ]; then printf 'PASS publication-fresh-commit-%s\n' "$kind"
  else printf 'FAIL publication-fresh-commit-%s exit=%s\n' "$kind" "$rc"; cat "$work/out" "$work/err"; fail=$((fail+1)); fi
done
printf 'publication bytes: %s failure(s)\n' "$fail"
test "$fail" -eq 0
