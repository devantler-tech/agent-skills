# The table is the catalogue. Prose examples, fenced tables and other sections
# are not entries. Validate every row before returning any result.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { if (s ~ /^`.*`$/) return substr(s, 2, length(s)-2); return s }
function identifier(s) { return s ~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/ }
function repository(s, a) { return split(s, a, "/") == 2 && identifier(a[1]) && identifier(a[2]) }
function refuse(reason) { print "error: README index line " NR ": " reason > "/dev/stderr"; bad=1 }
function path_ok(s, a, n, i) {
  n=split(s, a, "/")
  for (i=1; i<=n; i++) if (a[i] !~ /^[A-Za-z0-9_.-]+$/ || a[i] == "." || a[i] == "..") return 0
  return n > 0
}
function comment_start(s, i,j,k,width,closing) {
  for (i=1;i<=length(s);i++) {
    if (substr(s,i,1) == "\\") { i++; continue }
    if (substr(s,i,1) == "`") {
      width=1; while (substr(s,i+width,1) == "`") width++
      closing=0
      for (j=i+width;j<=length(s);j++) {
        if (substr(s,j,1) != "`") continue
        k=j; while (substr(s,k,1) == "`") k++
        if (k-j == width) { closing=k-1; break }
        j=k-1
      }
      if (closing) { i=closing; continue }
      i+=width-1
    }
    if (substr(s,i,4) == "<!--") return i
  }
  return 0
}
function html_end(s) {
  if (html == "blank") return s ~ /^[ \t]*$/
  if (html == "processing") return index(s, "?>") > 0
  if (html == "declaration") return index(s, ">") > 0
  if (html == "cdata") return index(s, "]]>") > 0
  return index(tolower(s), "</" html ">") > 0
}
function html_start(s, lower, tags, attr, open_tag) {
  lower=tolower(s); sub(/^ {0,3}/, "", lower)
  if (lower ~ /^<(script|pre|style|textarea)([ \t>]|$)/) {
    sub(/^</, "", lower); sub(/[ \t>].*$/, "", lower); return lower
  }
  if (s ~ /^ ? ? ?<\?/) return "processing"
  if (s ~ /^ ? ? ?<![A-Z]/) return "declaration"
  if (s ~ /^ ? ? ?<!\[CDATA\[/) return "cdata"
  tags="address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul"
  if (lower ~ ("^</?(" tags ")([ \t>]|/>|$)")) return "blank"
  # A complete custom tag starts a block only outside a paragraph.
  attr="[a-z_:][a-z0-9_.:-]*([ \t]*=[ \t]*(\"[^\"]*\"|'[^']*'|[^ \t\"'=<>`]+))?"
  open_tag="<[a-z][a-z0-9-]*([ \t]+" attr ")*[ \t]*/?>"
  if (!paragraph && lower ~ ("^(" open_tag "|</[a-z][a-z0-9-]*[ \t]*>)[ \t]*$")) return "blank"
  return ""
}
{
  sub(/\r$/, "")
  if (html) {
    if (html_end($0)) html=""
    paragraph=0
    next
  }
  if (!fence && !comment) {
    html=html_start($0)
    if (html) {
      if (html_end($0)) html=""
      paragraph=0
      next
    }
  }
  # Hidden Markdown comments never describe installable catalogue entries. Do
  # this outside code fences: example comment delimiters are literal code.
  if (!fence && (comment || $0 !~ /^ ? ? ?(```|~~~)/)) {
    visible=""; remaining=$0
    while (length(remaining)) {
      if (comment) {
        end=index(remaining, "-->")
        if (!end) { remaining=""; break }
        remaining=substr(remaining,end+3); comment=0
      } else {
        start=comment_start(remaining)
        if (!start) { visible=visible remaining; remaining=""; break }
        visible=visible substr(remaining,1,start-1)
        remaining=substr(remaining,start+4); comment=1
      }
    }
    $0=visible
  }
  paragraph=($0 !~ /^[ \t]*$/ && $0 !~ /^ *(#+[ \t]|\||>|[-+*] |[0-9]+[.)] )/)
  # A shorter run or the other fence character inside a code example is data.
  # Track fences outside Skills too, so example headings cannot create a section.
  stripped=$0; sub(/^ */, "", stripped)
  indent=length($0)-length(stripped); mark=substr(stripped, 1, 1)
  width=0
  if (indent <= 3 && (mark == "`" || mark == "~")) {
    while (substr(stripped, width+1, 1) == mark) width++
  }
  if (width >= 3) {
    if (!fence) {
      if (mark == "~" || index(substr(stripped, width+1), "`") == 0) {
        fence=mark; fence_width=width; paragraph=0; next
      }
    } else {
      if (mark == fence && width >= fence_width && trim(substr(stripped, width+1)) == "") { fence=""; paragraph=0 }
      next
    }
  }
  if (fence) next
}
/^## Skills[ \t]*$/ {
  if (seen_section++) refuse("multiple Skills sections")
  in_skills=1; next
}
/^## / { in_skills=0 }
!in_skills { next }
!/^\|/ { next }
{
  n=split($0, cell, "|")
  if (n != 5 || trim(cell[1]) != "" || trim(cell[5]) != "") {
    refuse("expected three table cells"); next
  }
  name=plain(trim(cell[2])); upstream=trim(cell[3]); command=plain(trim(cell[4]))
  if (name == "Skill" && upstream == "Upstream" && command == "Install") next
  if (name ~ /^:?-+:?$/ && upstream ~ /^:?-+:?$/ && command ~ /^:?-+:?$/) next
  if (!identifier(name)) { refuse("invalid skill name"); next }
  if (upstream !~ /^\[[^]]+\]\(https:\/\/github\.com\/[^)]+\)$/) {
    refuse("expected a github.com Upstream tree link"); next
  }
  display=upstream; sub(/^\[/, "", display); sub(/\].*$/, "", display); display=plain(display)
  url=upstream; sub(/^.*\]\(https:\/\/github\.com\//, "", url); sub(/\)$/, "", url)
  segments=split(url, part, "/")
  source=part[1] "/" part[2]; ref=part[4]; path=part[5]
  for (i=6; i<=segments; i++) path=path "/" part[i]
  if (segments < 5 || part[3] != "tree" || !repository(source) || !identifier(ref) || !path_ok(path)) {
    refuse("invalid Upstream repository, single-segment ref or path"); next
  }
  words=split(command, arg, /[ \t]+/)
  if (words < 5 || arg[1] != "gh" || arg[2] != "skill" || arg[3] != "install" ||
      !repository(arg[4]) || !identifier(arg[5])) {
    refuse("expected gh skill install <repository> <skill>"); next
  }
  if (tolower(display) != tolower(source) || tolower(arg[4]) != tolower(source) ||
      arg[5] != name || part[segments] != name) {
    refuse("Skill, Upstream and Install columns disagree"); next
  }
  # Install flags are documentation only: the installer constructs its own argv.
  # A command suffix without an option is a malformed example, not another entry.
  if (words > 5 && arg[6] !~ /^--[A-Za-z]/) { refuse("unexpected install command suffix"); next }
  identity=tolower(source) SUBSEP name
  if (name in destination && destination[name] != tolower(source)) {
    refuse("skill name " name " is shared by " destination[name] " and " tolower(source)); next
  }
  destination[name]=tolower(source)
  target=ref "/" path
  if (identity in targets && targets[identity] != target) {
    refuse("conflicting Upstream targets for " name); next
  }
  targets[identity]=target
  row_count++
  if (!(identity in entries)) {
    entries[identity]=(mode == "targets" ? source " " ref " " path " " name : arg[4] " " name)
    count++
  }
}
END {
  if (comment) refuse("unterminated HTML comment")
  if (!seen_section || !count) { print "error: no skills found in README index" > "/dev/stderr"; bad=1 }
  if (bad) exit 1
  if (mode == "rows") print row_count
  else for (identity in entries) print entries[identity]
}
