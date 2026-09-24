# Offline jq 1.6+ checker and Markdown renderer. Slurp exactly one brief; no external reads.
# jq -s --arg mode check -f accountability-brief.jq brief.json
# jq -sr --arg mode render -f accountability-brief.jq brief.json
def text: type == "string" and test("\\S") and (test("[\u0000-\u0008\u000b-\u001f\u007f]") | not);
def shape($fields): type == "object" and (keys == ($fields | sort));
def oneof($values): . as $v | $values | index($v) != null;
def texts: type == "array" and all(.[]; text);
def unique_values: length == (unique | length);
def ids: map(.id) | unique_values;
def refs: texts and unique_values;
def utc: text and (try ((fromdateiso8601 | strftime("%Y-%m-%dT%H:%M:%SZ")) == .) catch false);
def need($ok; $why): if $ok then . else error("invalid accountability brief: " + $why) end;
def schema:
  shape(["schemaVersion","synthetic","decision","model","comparison","evidence","claims","operations","unknowns","humanDecisions"])
  and .schemaVersion == 1 and (.synthetic | type == "boolean")
  and (.decision | shape(["id","revision","asOf","title","owner","audience","summary","request"])
    and ([.id,.revision,.title,.owner,.audience,.summary,.request] | all(.[]; text)) and (.asOf | utc))
  and (.model | shape(["explanation","analogy","behavior","architecture"])
    and ([.explanation,.behavior,.architecture] | all(.[]; text))
    and (.analogy == null or (.analogy | shape(["description","limits"]) and ([.description,.limits] | all(.[]; text)))))
  and (.comparison | shape(["incumbent","selected","options","whySelected","falsifiers"])
    and ([.incumbent,.selected,.whySelected] | all(.[]; text))
    and (.options | type == "array" and length >= 2 and ids and all(.[];
      shape(["id","description","disposition","tradeoff"]) and ([.id,.description,.disposition,.tradeoff] | all(.[]; text))))
    and (.falsifiers | type == "array" and length > 0 and all(.[];
      shape(["condition","response","owner"]) and ([.condition,.response,.owner] | all(.[]; text)))))
  and (.evidence | type == "array" and ids and all(.[];
    shape(["id","source","revision","kind","basis","observedAt","result","finding"])
    and ([.id,.source,.revision,.finding] | all(.[]; text))
    and (.kind | oneof(["static","behavior","deployment","live","review","rollback","simulation"]))
    and (.basis | oneof(["OBSERVED","SIMULATED","UNKNOWN"]))
    and (.result | oneof(["pass","fail","unknown"]))
    and (if .basis == "UNKNOWN" then .result == "unknown" and .observedAt == null
         else .result != "unknown" and (.observedAt | utc) end)
    and (.kind != "simulation" or .basis != "OBSERVED")))
  and (.claims | type == "array" and length > 0 and ids and all(.[];
    shape(["id","statement","basis","scope","evidence","limits"])
    and ([.id,.statement,.scope,.limits] | all(.[]; text)) and (.evidence | refs)
    and (.basis | oneof(["OBSERVED","INFERRED","SIMULATED","UNKNOWN"]))))
  and (.operations | shape(["failureModes","observe","stop","rollback"])
    and (.failureModes | type == "array" and length > 0 and all(.[];
      shape(["failure","signal","response","owner"]) and ([.failure,.signal,.response,.owner] | all(.[]; text))))
    and (.observe | shape(["where","owner"]) and ([.where,.owner] | all(.[]; text)))
    and (.stop | shape(["when","action","owner"]) and ([.when,.action,.owner] | all(.[]; text)))
    and (.rollback | shape(["status","action","verification","owner","evidence"])
      and ([.action,.verification,.owner] | all(.[]; text)) and (.evidence | refs)
      and (.status | oneof(["PROVEN","SIMULATED","UNKNOWN"]))))
  and (.unknowns | type == "array" and all(.[]; shape(["question","impact","nextStep","owner"])
    and ([.question,.impact,.nextStep,.owner] | all(.[]; text))))
  and (.humanDecisions | type == "array" and all(.[]; shape(["question","owner","resolution"])
    and ([.question,.owner] | all(.[]; text)) and (.resolution == null or (.resolution | text))));

# Validate associations and evidence labels, without claiming to interpret the supporting artifacts.
def validate:
  need(schema; "schema, required fields, or labels")
  | . as $b
  | need(.synthetic or all(.evidence[]; (.source | startswith("example://")) | not); "fictional sources must stay marked synthetic")
  | need(all([$b.comparison.incumbent,$b.comparison.selected][]; . as $id | any($b.comparison.options[]; .id == $id)); "alternatives must include incumbent and selected method")
  | need(all(.evidence[]; .observedAt == null or .observedAt <= $b.decision.asOf); "evidence is later than the brief")
  | need(all((.claims[].evidence[], .operations.rollback.evidence[]); . as $id | any($b.evidence[]; .id == $id)); "dangling evidence reference")
  | need(all(.claims[]; . as $claim
      | [.evidence[] as $id | $b.evidence[] | select(.id == $id)] as $sources
      | if .basis == "UNKNOWN" then true
        else ($sources | length > 0) and all($sources[];
          .basis != "UNKNOWN" and .result != "unknown"
          and (if $claim.basis == "OBSERVED" then .basis == "OBSERVED"
               elif $claim.basis == "SIMULATED" then .basis == "SIMULATED" else true end)) end);
      "claim basis exceeds its evidence")
  | need((.operations.rollback | . as $rollback
      | [.evidence[] as $id | $b.evidence[] | select(.id == $id)] as $sources
      | if .status == "UNKNOWN" then true
        else ($sources | length > 0) and all($sources[];
          .kind == "rollback" and .result == "pass" and .revision == $b.decision.revision
          and .basis == (if $rollback.status == "PROVEN" then "OBSERVED" else "SIMULATED" end)) end);
      "rollback status exceeds evidence for this revision")
  | need((any(.claims[]; .basis == "UNKNOWN") or any(.evidence[]; .basis == "UNKNOWN") or .operations.rollback.status != "PROVEN") | not or ($b.unknowns | length > 0);
      "unknown outcomes or recovery need an owned follow-up");

# Render values as plain inline text: normalize whitespace and escape Markdown and HTML syntax.
def md: gsub("[[:space:]]+"; " ") | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;")
  | gsub("(?<mark>[\\\\`*_{}\\[\\]()!|~])"; "\\\(.mark)");
def references: if length == 0 then "none" else map(md) | join(", ") end;
def render:
  . as $b | [
    "# \(.decision.title | md)",
    (if .synthetic then "**Synthetic example — not operational evidence.**" else "**Human accountability brief**" end),
    "Human semantic review is required. This artifact grants no authority to adopt, deploy, or roll back.",
    "Decision: \(.decision.id | md) · Revision: \(.decision.revision | md) · As of: \(.decision.asOf | md)",
    "Owner: \(.decision.owner | md) · Audience: \(.decision.audience | md)",
    "## One-minute summary", (.decision.summary | md),
    "Request: \($b.decision.request | md)",
    "## How it works", ($b.model.explanation | md),
    (if $b.model.analogy != null then "Analogy: \($b.model.analogy.description | md) Limits: \($b.model.analogy.limits | md)" else empty end),
    "Behavior: \($b.model.behavior | md)", "Architecture: \($b.model.architecture | md)",
    "## Alternatives and falsification",
    "Incumbent: \($b.comparison.incumbent | md) · Selected: \($b.comparison.selected | md)",
    ($b.comparison.options[] | "- \(.id | md): \(.description | md) [\(.disposition | md)]. Trade-off: \(.tradeoff | md)"),
    ($b.comparison.whySelected | md),
    ($b.comparison.falsifiers[] | "- Falsifier: \(.condition | md). Response: \(.response | md). Owner: \(.owner | md)."),
    "## Claims and limits",
    ($b.claims[] | "- **\(.basis)** \(.id | md): \(.statement | md). Scope: \(.scope | md). Limits: \(.limits | md) Evidence: \(.evidence | references)."),
    "## Evidence",
    ($b.evidence[] | "- \(.id | md): \(.basis), \(.kind), result=\(.result), revision=\(.revision | md), observed=\((.observedAt // "UNKNOWN") | md). \(.finding | md) Source: \(.source | md)."),
    "## Failure signals and operator actions",
    ($b.operations.failureModes[] | "- Failure: \(.failure | md). Signal: \(.signal | md). Response: \(.response | md). Owner: \(.owner | md)."),
    "Observe: \($b.operations.observe.where | md). Owner: \($b.operations.observe.owner | md).",
    "Stop when: \($b.operations.stop.when | md). Action: \($b.operations.stop.action | md). Owner: \($b.operations.stop.owner | md).",
    "## Recovery",
    "**\($b.operations.rollback.status)** — \($b.operations.rollback.action | md). Verify: \($b.operations.rollback.verification | md). Owner: \($b.operations.rollback.owner | md). Evidence: \($b.operations.rollback.evidence | references).",
    "## Unknowns",
    (if ($b.unknowns | length) == 0 then "None declared; the reviewer must challenge this." else
      $b.unknowns[] | "- \(.question | md) Impact: \(.impact | md). Next step: \(.nextStep | md). Owner: \(.owner | md)." end),
    "## Human-owned decisions",
    (if ($b.humanDecisions | length) == 0 then "None declared; existing authority boundaries still apply." else
      $b.humanDecisions[] | "- \(.question | md) Owner: \(.owner | md). Resolution: \((.resolution // "OPEN") | md)." end)
  ] | join("\n\n") + "\n";

need(type == "array" and length == 1; "supply exactly one JSON brief with jq -s")
| .[0] | validate
| if $mode == "check" then {
    status: "STRUCTURALLY_VALID", semanticReview: "REQUIRED", authority: "none",
    synthetic, decisionId: .decision.id, revision: .decision.revision,
    unknowns: (.unknowns | length), openHumanDecisions: ([.humanDecisions[] | select(.resolution == null)] | length)
  }
  elif $mode == "render" then render
  else error("expected mode check or render") end
