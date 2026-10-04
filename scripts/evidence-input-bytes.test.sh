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
  for scenario in healthy invalid-byte replacement-character international malformed duplicate multiple; do
    jq -c . "$example" > "$work/input.json"
    case $scenario in
      invalid-byte|replacement-character|international)
        case $tool in proof) field='.evidence[1].uri' ;; brief) field='.evidence[0].source' ;; flow) field='.run.evidence' ;; esac
        case $scenario in invalid-byte) suffix=PLACEHOLDER ;; replacement-character) suffix=$'\357\277\275' ;; international) suffix='測定-é' ;; esac
        jq --arg suffix "$suffix" "$field += \$suffix" "$example" > "$work/input.json"
        if [[ $scenario == invalid-byte ]]; then LC_ALL=C sed $'s/PLACEHOLDER/\377/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json"; fi ;;
      malformed) printf '{"broken":' > "$work/input.json" ;;
      duplicate) sed 's/^{/{"retained":false,"retained":true,/' "$work/input.json" > "$work/new"; mv "$work/new" "$work/input.json" ;;
      multiple) cat "$example" >> "$work/input.json" ;;
    esac
    rc=0
    bash "$wrapper" "${args[@]}" "$work/input.json" > "$work/out" 2> "$work/err" || rc=$?
    case $scenario in
      healthy|replacement-character|international)
        if [[ $rc == 0 && -s $work/out ]]; then passed=$((passed+1)); else printf 'FAIL %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi ;;
      *)
        if [[ $rc == 2 && ! -s $work/out && -s $work/err ]]; then passed=$((passed+1)); else printf 'FAIL %s %s exit=%s\n' "$tool" "$scenario" "$rc"; failed=$((failed+1)); fi
        if [[ $scenario == invalid-byte ]] && ! grep -q 'valid UTF-8' "$work/err"; then printf 'FAIL missing byte diagnostic: %s\n' "$tool"; failed=$((failed+1)); fi ;;
    esac
  done
done
# Rendering also uses the actual installed byte boundary before the jq renderer.
bash "$root/product-engineering/scripts/accountability-brief.sh" --mode render "$root/product-engineering/references/accountability-product.json" > "$work/render" || failed=$((failed+1))
grep -q SIMULATED "$work/render" || failed=$((failed+1))
printf 'raw input entrypoints: %s passes, %s failures\n' "$passed" "$failed"
[[ $failed == 0 ]]
