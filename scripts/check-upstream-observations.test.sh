#!/usr/bin/env bash
# Failure injection at process boundaries, against the real upstream verifier.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE=${UPSTREAM_SOURCE:-$HERE}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail=0
for mode in authentication cancelled parse-failure body-read-failure error-read-failure backoff-failure missing-backoff; do
  d="$WORK/$mode"
  mkdir -p "$d/scripts" "$d/bin"
  cp "$SOURCE/check-upstream-skills.sh" "$SOURCE/readme-index.sh" "$SOURCE/readme-index.awk" "$d/scripts/"
  cat > "$d/README.md" <<'EOF'
# Fixture

## Skills

| Skill | Upstream | Install |
|-------|----------|---------|
| alpha | [test/present](https://github.com/test/present/tree/main/skills/alpha) | gh skill install test/present alpha |
EOF
  cat > "$d/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' request >> "$UPSTREAM_CALLS"
case "$UPSTREAM_FAILURE" in
  authentication) printf 'Authentication required\n' >&2; exit 4 ;;
  cancelled) printf 'Cancelled\n' >&2; exit 2 ;;
  backoff-failure|missing-backoff) printf 'HTTP/1.1 503 Service Unavailable\r\n\r\n{"message":"Service Unavailable"}\n'; exit 1 ;;
  *) printf 'HTTP/1.1 200 OK\r\n\r\n{"type":"file","name":"SKILL.md","path":"skills/alpha/SKILL.md"}\n' ;;
esac
STUB
  chmod +x "$d/bin/gh"
  if [ "$mode" = parse-failure ] || [ "$mode" = body-read-failure ]; then
    cat > "$d/bin/awk" <<'STUB'
#!/usr/bin/env bash
"$UPSTREAM_REAL_AWK" "$@"
rc=$?
case "$UPSTREAM_FAILURE:$1" in parse-failure:NR==1*|body-read-failure:body*) exit 1 ;; esac
exit "$rc"
STUB
    chmod +x "$d/bin/awk"
  fi
  if [ "$mode" = error-read-failure ]; then
    cat > "$d/bin/cat" <<'STUB'
#!/usr/bin/env bash
"$UPSTREAM_REAL_CAT" "$@"
rc=$?
case "$1" in */error) exit 1 ;; esac
exit "$rc"
STUB
    chmod +x "$d/bin/cat"
  fi
  backoff=true
  [ "$mode" != backoff-failure ] || backoff=false
  [ "$mode" != missing-backoff ] || backoff="$d/missing-command"
  rc=0
  out=$(env PATH="$d/bin:$PATH" UPSTREAM_FAILURE="$mode" UPSTREAM_CALLS="$d/calls" \
    UPSTREAM_RETRY_SLEEP="$backoff" UPSTREAM_REAL_AWK="$(command -v awk)" UPSTREAM_REAL_CAT="$(command -v cat)" \
    bash "$d/scripts/check-upstream-skills.sh" 2>&1) || rc=$?
  calls=$(wc -l < "$d/calls" | tr -d ' ')
  if [ "$rc" -eq 1 ] && [ "$calls" -eq 1 ] && [[ "$out" == *invalid-responses=1* ]]; then
    printf 'PASS %s fails verification after one request\n' "$mode"
  else
    printf 'FAIL %s (exit=%s, requests=%s)\n%s\n' "$mode" "$rc" "$calls" "$out"
    fail=$((fail+1))
  fi
done
printf 'upstream observations: %s failure(s)\n' "$fail"
[ "$fail" -eq 0 ]
