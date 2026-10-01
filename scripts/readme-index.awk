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
{
  sub(/\r$/, "")
  # A shorter run or the other fence character inside a code example is data.
  # Track fences outside Skills too, so example headings cannot create a section.
  stripped=$0; sub(/^ */, "", stripped)
  indent=length($0)-length(stripped); mark=substr(stripped, 1, 1)
  width=0
  if (indent <= 3 && (mark == "`" || mark == "~")) {
    while (substr(stripped, width+1, 1) == mark) width++
  }
  if (width >= 3) {
    if (!fence) { fence=mark; fence_width=width }
    else if (mark == fence && width >= fence_width && trim(substr(stripped, width+1)) == "") fence=""
    next
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
  if (!seen_section || !count) { print "error: no skills found in README index" > "/dev/stderr"; bad=1 }
  if (bad) exit 1
  if (mode == "rows") print row_count
  else for (identity in entries) print entries[identity]
}
