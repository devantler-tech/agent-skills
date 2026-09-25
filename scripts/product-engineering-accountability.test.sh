#!/usr/bin/env bash
# Exercise the installed-format brief checker and renderer with real JSON, offline.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
filter="$root/product-engineering/scripts/accountability-brief.jq"
example="$root/product-engineering/references/accountability-product.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
passed=0
# A structurally complete brief still requires human review and grants no authority.
valid() {
  local name=$1 mutation=$2
  jq "$mutation" "$example" > "$work/input.json"
  jq -s --arg mode check -f "$filter" "$work/input.json" > "$work/result.json"
  jq -e '.status == "STRUCTURALLY_VALID" and .semanticReview == "REQUIRED" and .authority == "none"' "$work/result.json" >/dev/null || { printf 'FAIL %s\n' "$name"; exit 1; }
  passed=$((passed + 1))
}
# Invalid or misleading structure must fail before emitting any brief or check result.
invalid() {
  local name=$1 mutation=$2
  jq "$mutation" "$example" > "$work/input.json"
  for mode in check render; do
    if jq -s --arg mode "$mode" -f "$filter" "$work/input.json" > "$work/result" 2> "$work/error"; then
      printf 'FAIL %s accepted by %s\n' "$name" "$mode"; exit 1
    fi
    [ ! -s "$work/result" ] || { printf 'FAIL partial output for %s\n' "$name"; exit 1; }
  done
  passed=$((passed + 1))
}
valid 'synthetic proposal with unknowns' '.'
valid 'analogy is optional' '.model.analogy = null'
valid 'tab and line feed in prose render as spaces' '.model.explanation="line one\n\tline two"'
valid 'incumbent can remain selected' '.comparison.selected = "current"'
valid 'recording a failed observation is valid' '.evidence[0] |= (.basis="OBSERVED" | .kind="behavior" | .result="fail") | .claims[0].basis="OBSERVED"'
invalid 'empty input object' '{}'
invalid 'unsupported schema' '.schemaVersion=2'
invalid 'missing owner' 'del(.decision.owner)'
invalid 'blank summary' '.decision.summary="  \n"'
invalid 'analogy without limits' '.model.analogy.limits=""'
invalid 'missing incumbent' '.comparison.incumbent="absent"'
invalid 'unknown selected alternative' '.comparison.selected="absent"'
invalid 'duplicate alternatives' '.comparison.options += [.comparison.options[0]]'
invalid 'no falsification condition' '.comparison.falsifiers=[]'
invalid 'no claims' '.claims=[]'
invalid 'duplicate claim IDs' '.claims += [.claims[0]]'
invalid 'unlabelled claim' 'del(.claims[0].basis)'
invalid 'model confidence as proof' '.claims[0].basis="CONFIDENT"'
invalid 'simulation passed off as observation' '.claims[0].basis="OBSERVED"'
invalid 'simulator labelled observed' '.evidence[0].basis="OBSERVED"'
invalid 'inference without evidence' '.claims[1].evidence=[]'
invalid 'claim references missing evidence' '.claims[0].evidence=["absent"]'
invalid 'duplicate claim references' '.claims[0].evidence=["latency","latency"]'
invalid 'duplicate evidence IDs' '.evidence += [.evidence[0]]'
invalid 'unscoped guarantee' '.claims[0].scope=""'
invalid 'unknown evidence asserted as result' '.evidence[0].result="unknown"'
invalid 'unknown claim without follow-up' '.unknowns=[]'
invalid 'unrelated follow-up cannot cover unknown claim' '.unknowns=[.unknowns[1]]'
invalid 'unrelated follow-up cannot cover unproven recovery' '.unknowns=[.unknowns[0]]'
invalid 'render-equivalent evidence identifiers' '.evidence += [(.evidence[0] | .id="late  ncy"), (.evidence[0] | .id="late ncy")]'
invalid 'leading whitespace hides fictional source' '.synthetic=false | .evidence[].source |= " " + .'
invalid 'case variants of fictional URI scheme' '.synthetic=false | .evidence[].source |= sub("example://";"EXAMPLE://")'
invalid 'unknown evidence without a linked follow-up' '.evidence += [{id:"pending",source:"artifact://pending",revision:"candidate-search-2",kind:"live",basis:"UNKNOWN",observedAt:null,result:"unknown",finding:"Unavailable"}]'
invalid 'missing follow-up targets' 'del(.unknowns[0].targets)'
invalid 'empty follow-up targets' '.unknowns[0].targets=[]'
invalid 'duplicate follow-up targets' '.unknowns[0].targets += [.unknowns[0].targets[0]]'
invalid 'duplicate follow-up identifiers' '.unknowns += [.unknowns[0]]'
invalid 'missing claim target' '.unknowns[0].targets=["claim:absent"]'
invalid 'missing evidence target' '.unknowns[0].targets=["evidence:absent"]'
invalid 'generic decision target cannot cover a specific gap' '.unknowns[0].targets=["decision"]'
invalid 'known outcome cannot cover a different unknown' '.unknowns[0].targets=["claim:benefit"]'
invalid 'noncanonical decision identifier' '.decision.id="search preview"'
invalid 'bidi override hides rendered text' '.decision.summary="safe \u202e txet lieh"'
invalid 'zero-width character hides rendered text' '.model.explanation="approved\u200bnot"'
invalid 'C1 control character hides rendered text' '.model.explanation="approved\u0085\u009bnot"'
invalid 'identifier with a trailing newline' '.decision.id |= . + "\n"'
invalid 'exact value with a trailing newline' '.humanDecisions[0].resolution={decision:"Approve the trial",reference:"PR-12\n"}'
invalid 'noncanonical option identifier' '.comparison.options[0].id="current  choice" | .comparison.incumbent="current  choice"'
invalid 'noncanonical claim identifier' '.claims[0].id="Speed"'
invalid 'noncanonical follow-up identifier' '.unknowns[0].id="user benefit"'
invalid 'trailing whitespace in source' '.evidence[0].source += " "'
invalid 'multiline source' '.evidence[0].source += "\nfragment"'
for mark in '\u200b' '\u2060' '\ufeff' '\u00a0'; do
  invalid "invisible prefix $mark hides fictional source" ".synthetic=false | .evidence[].source |= \"$mark\" + sub(\"example://\";\"EXAMPLE://\")"
done
invalid 'visible prefix hides fictional source' '.synthetic=false | .evidence[].source |= "see " + sub("example://";"EXAMPLE://")'
invalid 'visible prefix hides fictional decision reference' '.synthetic=false | .evidence[].source |= sub("^example://";"artifact://") | .humanDecisions[0].resolution={decision:"Approved",reference:"see example://decision/1"}'
for revision in 'candidate  search-2' 'candidate\tsearch-2' 'candidate\nsearch-2' 'candidate\u200bsearch-2' 'candidate\u00a0search-2' ' candidate-search-2'; do
  invalid "render-equivalent revision: $revision" ".decision.revision=\"$revision\" | .evidence[].revision=\"$revision\""
done
invalid 'future evidence' '.evidence[0].observedAt="2026-09-25T00:00:00Z"'
invalid 'invalid calendar date' '.decision.asOf="2026-02-30T12:00:00Z"'
invalid 'missing revision' '.evidence[0].revision=""'
invalid 'unknown top-level field' '.approvalGranted=true'
invalid 'fictional source passed off as real' '.synthetic=false'
invalid 'missing stop action' 'del(.operations.stop.action)'
invalid 'missing failure signal' '.operations.failureModes[0].signal=""'
invalid 'missing recovery verification' '.operations.rollback.verification=""'
invalid 'simulated rollback claimed proven' '.operations.rollback.status="PROVEN"'
invalid 'rollback evidence for another revision' '.evidence[1].revision="previous-search"'
invalid 'non-rollback evidence' '.operations.rollback.evidence=["latency"]'
invalid 'failed rollback claimed successful' '.evidence[1].result="fail"'
invalid 'unknown operator' '.operations.observe.owner=null'
invalid 'human decision has no owner' '.humanDecisions[0].owner=""'
invalid 'empty resolution pretends decision' '.humanDecisions[0].resolution=""'
invalid 'uncited resolution pretends decision' '.humanDecisions[0].resolution="Approved"'
invalid 'resolution reference is missing' '.humanDecisions[0].resolution={decision:"Approved"}'
invalid 'resolution reference is blank' '.humanDecisions[0].resolution={decision:"Approved",reference:" "}'
invalid 'resolution decision is blank' '.humanDecisions[0].resolution={decision:" ",reference:"artifact://decision/42"}'
for scheme in 'example://' 'EXAMPLE://'; do
  invalid "fictional decision reference $scheme passed off as real" ".synthetic=false | .evidence[].source |= sub(\"^example://\";\"artifact://\") | .humanDecisions[0].resolution={decision:\"Approved\",reference:\"${scheme}decision/1\"}"
done
for reference in ' artifact://decision/42' 'artifact://decision/42 ' '\u200bartifact://decision/42' 'artifact://decision  42' 'artifact://decision\n42'; do
  invalid "render-equivalent decision reference: $reference" ".humanDecisions[0].resolution={decision:\"Approved\",reference:\"$reference\"}"
done
valid 'unproven rollback stays explicitly unknown' '.operations.rollback |= (.status="UNKNOWN" | .evidence=[])'
valid 'observed recovery can be recorded' '.evidence[1].basis="OBSERVED" | .operations.rollback.status="PROVEN"'
valid 'unknown evidence is allowed when labelled and linked' '.evidence[0] |= (.basis="UNKNOWN" | .result="unknown" | .observedAt=null) | .claims[0].basis="UNKNOWN" | .claims[1].basis="UNKNOWN" | .unknowns[0].targets += ["evidence:latency","claim:speed"]'
valid 'real records keep the same structural boundary' '.synthetic=false | .evidence[].source |= sub("^example://";"artifact://")'
valid 'all evidence can remain explicitly unknown' '.evidence=[] | .claims[] |= (.basis="UNKNOWN" | .evidence=[]) | .operations.rollback |= (.status="UNKNOWN" | .evidence=[]) | .unknowns[0].targets += ["claim:speed"]'
valid 'cited human decision' '.humanDecisions[0].resolution={decision:"Declined",reference:"artifact://decision/42"}'
jq -e '.openHumanDecisions == 0' "$work/result.json" >/dev/null
jq -sr --arg mode render -f "$filter" "$work/input.json" > "$work/render.md"
grep -Fq 'Resolution: Declined. Reference: artifact://decision/42.' "$work/render.md"
grep -Fq 'claim:live\-effect' "$work/render.md"
grep -Fq 'live\-recovery [rollback]' "$work/render.md"
valid 'one owned follow-up explicitly covers several gaps' '.unknowns[0].targets += ["rollback"] | .unknowns=[.unknowns[0]]'
valid 'single spaces keep revisions and sources exact' '.decision.revision="candidate search 2" | .evidence[].revision="candidate search 2" | .synthetic=false | .evidence[].source |= sub("^example://";"artifact://") | .evidence[0].source="artifact://run 42"'
jq -sr --arg mode render -f "$filter" "$work/input.json" > "$work/render.md"
grep -Fq 'Revision: candidate search 2 ·' "$work/render.md"
grep -Fq 'revision=candidate search 2,' "$work/render.md"
grep -Fq 'Source: artifact://run 42.' "$work/render.md"
valid 'general decision uncertainty can be separately recorded' '.unknowns += [{id:"decision-scope",targets:["decision"],question:"Who is affected?",impact:"Scope incomplete",nextStep:"Review affected users",owner:"Product owner"}]'

for mutation in '.decision=null' '.claims={}' '.evidence=null' '.unknowns=null' '.operations.failureModes=[]' '.humanDecisions={}' '.claims[0].evidence=[1]' '.synthetic="true"' '.decision.title="bad\u0007text"'; do
  invalid "wrong data shape: $mutation" "$mutation"
done

# Every teaching example is valid, remains marked synthetic, and renders its own decision.
for scenario in product infrastructure library; do
  candidate="$root/product-engineering/references/accountability-$scenario.json"
  jq -s --arg mode check -f "$filter" "$candidate" > "$work/result.json"
  jq -e '.synthetic == true and .semanticReview == "REQUIRED" and .authority == "none"' "$work/result.json" >/dev/null
  jq -sr --arg mode render -f "$filter" "$candidate" > "$work/render.md"
  grep -Fq "$(jq -r '.decision.title' "$candidate")" "$work/render.md"
  grep -Fq 'Synthetic example' "$work/render.md"
  passed=$((passed + 1))
done

# Reject empty/multiple documents and an unsupported mode, not merely malformed field values.
for input in empty multiple; do
  if [ "$input" = empty ]; then : > "$work/input.json"; else cat "$example" "$example" > "$work/input.json"; fi
  if jq -s --arg mode check -f "$filter" "$work/input.json" > "$work/result" 2> "$work/error"; then exit 1; fi
  [ ! -s "$work/result" ]; passed=$((passed + 1))
done
if jq -s --arg mode publish -f "$filter" "$example" > "$work/result" 2> "$work/error"; then exit 1; fi
[ ! -s "$work/result" ]; passed=$((passed + 1))

# Data remains text in Markdown; titles cannot inject links, images, HTML, or new headings.
jq '.decision.title="[click](https://example.invalid) <script>\n# fake ~~strike~~"' "$example" > "$work/input.json"
jq -sr --arg mode render -f "$filter" "$work/input.json" > "$work/render.md"
grep -Fq 'Synthetic example' "$work/render.md"
grep -Fq '\[click\]\(https://example\.invalid\) &lt;script&gt; \# fake' "$work/render.md"
grep -Fq '\~\~strike\~\~' "$work/render.md"
if grep -q '^# fake' "$work/render.md"; then exit 1; fi
grep -Fq 'SIMULATED' "$work/render.md"
grep -Fq 'UNKNOWN' "$work/render.md"
passed=$((passed + 1))
# Standalone fields must not become headings, lists, or thematic breaks.
for value in '# Forged heading' '- Forged item' '+ Forged item' '1. Forged item' '---' '==='; do
  jq --arg value "$value" '.decision.summary=$value | .model.explanation=$value | .comparison.whySelected=$value' "$example" > "$work/input.json"
  jq -sr --arg mode render -f "$filter" "$work/input.json" > "$work/render.md"
  if grep -Fxq -- "$value" "$work/render.md"; then
    printf 'FAIL standalone Markdown structure: %s\n' "$value"; exit 1
  fi
  passed=$((passed + 1))
done
printf 'accountability brief: PASS (%s cases)\n' "$passed"
