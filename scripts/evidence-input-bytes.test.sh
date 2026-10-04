#!/usr/bin/env bash
# Exercise each installed entrypoint with the same retained raw bytes it evaluates.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0 failed=0
for tool in proof brief flow; do
  case $tool in
    proof) wrapper="$root/product-engineering/scripts/check-evidence.sh"; example="$root/product-engineering/references/evidence-example.json"; args=(--now 2026-09-24T00:00:00Z) ;;
    brief) wrapper="$root/product-engineering/scripts/accountability-brief.sh"; example="$root/product-engineering/references/accountability-product.json"; args=(--mode check) ;;
    flow) wrapper="$root/agent-improvement/scripts/measure-flow.sh"; example="$root/agent-improvement/references/flow-example.json"; args=() ;;
  esac
  for scenario in healthy invalid-byte replacement-character international valid-surrogate-pair literal-surrogate unpaired-low-surrogate unpaired-high-surrogate malformed duplicate multiple; do
    jq -c . "$example" > "$work/input.json"
    case $scenario in
      invalid-byte|replacement-character|international|valid-surrogate-pair|literal-surrogate|unpaired-low-surrogate|unpaired-high-surrogate)
        case $tool in proof) field='.evidence[1].uri' ;; brief) field='.evidence[0].source' ;; flow) field='.run.evidence' ;; esac
        case $scenario in invalid-byte) suffix=PLACEHOLDER ;; replacement-character) suffix=$'\357\277\275' ;; international) suffix='測定-é' ;; *) suffix=PLACEHOLDER ;; esac
        jq --arg suffix "$suffix" "$field += \$suffix" "$example" > "$work/input.json"
        case $scenario in
          invalid-byte) LC_ALL=C sed $'s/PLACEHOLDER/\377/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
          valid-surrogate-pair) sed 's/PLACEHOLDER/\\ud83d\\ude00/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
          literal-surrogate) sed 's/PLACEHOLDER/\\\\udc00/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
          unpaired-low-surrogate) sed 's/PLACEHOLDER/\\udc00/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
          unpaired-high-surrogate) sed 's/PLACEHOLDER/\\ud800/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
          *) ;;
        esac
        ;;
      malformed) printf '{"broken":' > "$work/input.json" ;;
      duplicate) sed 's/^{/{"retained":false,"retained":true,/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      multiple) cat "$example" >> "$work/input.json" ;;
    esac
    rc=0
    bash "$wrapper" "${args[@]}" "$work/input.json" > "$work/out" 2> "$work/err" || rc=$?
    case $scenario in
      healthy|replacement-character|international|valid-surrogate-pair|literal-surrogate)
        if [[ $rc == 0 && -s $work/out ]]; then passed=$((passed+1)); else printf 'FAIL %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi ;;
      *)
        if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then passed=$((passed+1)); else printf 'FAIL %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi
        if [[ $scenario == invalid-byte ]] && ! grep -q 'valid UTF-8' "$work/err"; then printf 'FAIL missing byte diagnostic: %s\n' "$tool"; failed=$((failed+1)); fi
        if [[ $scenario == unpaired-low-surrogate || $scenario == unpaired-high-surrogate ]] && ! grep -q 'unpaired JSON surrogate escape' "$work/err"; then printf 'FAIL missing surrogate diagnostic: %s %s\n' "$tool" "$scenario"; failed=$((failed+1)); fi ;;
    esac
  done
done
# Failed scanner reads must not turn unexamined retained bytes into a valid result.
mkdir "$work/read-failure-bin"
REAL_CAT=$(command -v cat)
export REAL_CAT
cat > "$work/read-failure-bin/cat" <<'STUB'
#!/usr/bin/env bash
if [[ ${!#} == */input ]]; then
  [[ $READ_FAILURE_KIND != partial ]] || printf '%s' '{"prefix":"ordinary"}'
  exit 1
fi
exec "$REAL_CAT" "$@"
STUB
chmod +x "$work/read-failure-bin/cat"
for tool in proof brief-check brief-render flow; do
  case $tool in
    proof) wrapper="$root/product-engineering/scripts/check-evidence.sh"; example="$root/product-engineering/references/evidence-example.json"; args=(--now 2026-09-24T00:00:00Z); field='.evidence[1].uri' ;;
    brief-check|brief-render)
      wrapper="$root/product-engineering/scripts/accountability-brief.sh"; example="$root/product-engineering/references/accountability-product.json"; field='.evidence[0].source'
      args=(--mode "${tool#brief-}") ;;
    flow) wrapper="$root/agent-improvement/scripts/measure-flow.sh"; example="$root/agent-improvement/references/flow-example.json"; args=(); field='.run.evidence' ;;
  esac
  for input_kind in healthy unpaired; do
    jq -c . "$example" > "$work/input.json"
    if [[ $input_kind == unpaired ]]; then
      jq "$field += \"PLACEHOLDER\"" "$example" > "$work/new"
      sed 's/PLACEHOLDER/\\udfff/' "$work/new" > "$work/input.json"
      rc=0
      bash "$wrapper" "${args[@]}" "$work/input.json" > "$work/out" 2> "$work/err" || rc=$?
      if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then
        passed=$((passed+1))
      else
        printf 'FAIL %s ordinary unpaired refusal exit=%s\n' "$tool" "$rc"; failed=$((failed+1))
      fi
    fi
    for kind in empty partial; do
      rc=0
      PATH="$work/read-failure-bin:$PATH" READ_FAILURE_KIND="$kind" bash "$wrapper" "${args[@]}" "$work/input.json" > "$work/out" 2> "$work/err" || rc=$?
      if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then
        passed=$((passed+1))
      else
        printf 'FAIL %s %s scanner-read-%s exit=%s\n' "$tool" "$input_kind" "$kind" "$rc"; failed=$((failed+1))
      fi
    done
  done
done

# Independently installed directories retain their complete path, including final newlines.
mkdir -p "$work/installed" "$work/installed"$'\n' "$work/bin"
# The stub must expand its own argument when invoked.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1"\nexit 71\n' > "$work/bin/dirname"
chmod +x "$work/bin/dirname"
for tool in proof brief-check brief-render flow; do
  case $tool in
    proof) name=check-evidence; origin=product-engineering; example="$root/product-engineering/references/evidence-example.json"; args=(--now 2026-09-24T00:00:00Z) ;;
    brief-check|brief-render) name=accountability-brief; origin=product-engineering; example="$root/product-engineering/references/accountability-product.json"; args=(--mode "${tool#brief-}") ;;
    flow) name=measure-flow; origin=agent-improvement; example="$root/agent-improvement/references/flow-example.json"; args=() ;;
  esac
  cp "$root/$origin/scripts/$name.sh" "$work/installed"$'\n'/
  cp "$root/$origin/scripts/validate-json-unicode-escapes.sh" "$work/installed"$'\n'/
  printf 'error("requested installed filter refuses")\n' > "$work/installed"$'\n'/"$name.jq"
  printf '{decision:"ADOPT",unexamined:true}\n' > "$work/installed/$name.jq"
  for scenario in newline dirname-failure; do
    rc=0
    if [[ $scenario == dirname-failure ]]; then
      PATH="$work/bin:$PATH" bash "$work/installed"$'\n'/"$name.sh" "${args[@]}" "$example" > "$work/out" 2> "$work/err" || rc=$?
    else
      bash "$work/installed"$'\n'/"$name.sh" "${args[@]}" "$example" > "$work/out" 2> "$work/err" || rc=$?
    fi
    if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then passed=$((passed+1)); else printf 'FAIL installed %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi
  done
  # Use the real installed filter so a masked scanner failure would return success.
  cp "$root/$origin/scripts/$name.jq" "$work/installed"$'\n'/
  jq -c . "$example" > "$work/copied-input.json"
  rc=0
  bash "$work/installed"$'\n'/"$name.sh" "${args[@]}" "$work/copied-input.json" > "$work/out" 2> "$work/err" || rc=$?
  if [[ $rc == 0 && -s $work/out ]]; then passed=$((passed+1)); else printf 'FAIL copied %s positive exit=%s\n' "$tool" "$rc"; failed=$((failed+1)); fi
  for kind in empty partial; do
    rc=0
    PATH="$work/read-failure-bin:$PATH" READ_FAILURE_KIND="$kind" bash "$work/installed"$'\n'/"$name.sh" "${args[@]}" "$work/copied-input.json" > "$work/out" 2> "$work/err" || rc=$?
    if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then passed=$((passed+1)); else printf 'FAIL copied %s scanner-read-%s exit=%s\n' "$tool" "$kind" "$rc"; failed=$((failed+1)); fi
  done
done
cmp "$root/product-engineering/scripts/validate-json-unicode-escapes.sh" "$root/agent-improvement/scripts/validate-json-unicode-escapes.sh" || failed=$((failed+1))
# Rendering also uses the actual installed byte boundary before the jq renderer.
bash "$root/product-engineering/scripts/accountability-brief.sh" --mode render "$root/product-engineering/references/accountability-product.json" > "$work/render" || failed=$((failed+1))
grep -q SIMULATED "$work/render" || failed=$((failed+1))
printf 'raw input entrypoints: %s passes, %s failures\n' "$passed" "$failed"
[[ $failed == 0 ]]
