# The table is the catalogue. Prose examples, fenced tables and other sections
# are not entries. Validate every row before returning any result.
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { if (s ~ /^`.*`$/) return substr(s, 2, length(s)-2); return s }
function identifier(s) { return s ~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/ }
# Skill names become directory identities on every supported filesystem.
function skill_name(s) { return length(s) <= 64 && s ~ /^[a-z0-9]+(-[a-z0-9]+)*$/ }
# Check separate owner/repository components; leading repository punctuation is
# legal, but the literal dot traversal components never identify a repository.
function repository(s, a) {
  return split(s, a, "/") == 2 && identifier(a[1]) &&
    a[2] ~ /^[A-Za-z0-9_.-]+$/ && a[2] != "." && a[2] != ".."
}
# Validate the complete literal option grammar and bind any explicit pin to the
# advertised source ref, without executing or forwarding catalogue arguments.
function options_ok(arg, words, ref, i, flag, value, equal, seen) {
  for (i=6; i<=words; i++) {
    flag=arg[i]; value=""; equal=index(flag,"=")
    if (equal) { value=substr(flag,equal+1); flag=substr(flag,1,equal-1) }
    if (flag == "-f") flag="--force"
    if (flag in seen) return 0
    seen[flag]=1
    if (flag == "--force" || flag == "--allow-hidden-dirs") {
      if (equal) return 0
      continue
    }
    if (flag != "--agent" && flag != "--scope" && flag != "--pin" && flag != "--dir") return 0
    if (!equal) { if (++i > words) return 0; value=arg[i] }
    if (value == "" || value ~ /^-/) return 0
    if (flag == "--agent" && !identifier(value)) return 0
    if (flag == "--scope" && value != "project" && value != "user") return 0
    if (flag == "--pin" && value != ref) return 0
    if (flag == "--dir" && value !~ /^[A-Za-z0-9_.~\/+][A-Za-z0-9_.~\/+\-]*$/) return 0
  }
  return 1
}
function refuse(reason) { print "error: README index line " NR ": " reason > "/dev/stderr"; bad=1 }
function path_ok(s, a, n, i) {
  # Paths are CLI operands; an option-leading path cannot retain that meaning.
  if (s ~ /^-/) return 0
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
  if (html == "comment") return index(s, "-->") > 0
  if (html == "processing") return index(s, "?>") > 0
  if (html == "declaration") return index(s, ">") > 0
  if (html == "cdata") return index(s, "]]>") > 0
  return tolower(s) ~ /<\/(pre|script|style|textarea)>/
}
function html_start(s, lower, tags, attr, open_tag) {
  lower=tolower(s); sub(/^ {0,3}/, "", lower)
  if (lower ~ /^<(script|pre|style|textarea)([ \t>]|$)/) {
    sub(/^</, "", lower); sub(/[ \t>].*$/, "", lower); return lower
  }
  if (s ~ /^ ? ? ?<\?/) return "processing"
  if (s ~ /^ ? ? ?<!--/) return "comment"
  if (s ~ /^ ? ? ?<![A-Za-z]/) return "declaration"
  if (s ~ /^ ? ? ?<!\[CDATA\[/) return "cdata"
  tags="address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul"
  if (lower ~ ("^</?(" tags ")([ \t>]|/>|$)")) return "blank"
  # A complete custom tag starts a block only outside a paragraph.
  attr="[a-z_:][a-z0-9_.:-]*([ \t]*=[ \t]*(\"[^\"]*\"|'[^']*'|[^ \t\"'=<>`]+))?"
  open_tag="<[a-z][a-z0-9-]*([ \t]+" attr ")*[ \t]*/?>"
  if (!paragraph && lower ~ ("^(" open_tag "|</[a-z][a-z0-9-]*[ \t]*>)[ \t]*$") &&
      lower !~ /^<(pre|script|style|textarea)([ \t\/>]|$)/) return "blank"
  return ""
}
function clear_paragraph() {
  paragraph=0; paragraph_text=""; quote_paragraph=0; list_paragraph=0; table=0; catalogue_table=0
  pipe_columns=0; pipe_catalogue=0; reference_paragraph=0
}
function column_width(s, i, width) {
  width=0
  for (i=1; i<=length(s); i++)
    width += (substr(s,i,1) == "\t" ? 4-width%4 : 1)
  return width
}
# Expand only copied classification text at its original column. Removing
# container markers first would change the width of tabs inside nested items.
function expand_tabs(s, i, width, ch, out, padding) {
  width=0; out=""
  for (i=1; i<=length(s); i++) {
    ch=substr(s,i,1)
    if (ch == "\t") {
      padding=4-width%4
      while (padding--) { out=out " "; width++ }
    } else { out=out ch; width++ }
  }
  return out
}
function indent_width(s, i) {
  for (i=1; i<=length(s); i++) if (substr(s,i,1) !~ /[ \t]/) break
  return column_width(substr(s,1,i-1))
}
function remove_indent(s, columns, offset, i, width, extra) {
  width=offset; i=1
  while (substr(s,i,1) ~ /[ \t]/) {
    width += (substr(s,i,1) == "\t" ? 4-width%4 : 1); i++
  }
  extra=""; while (width-- > columns+offset) extra=extra " "
  return extra substr(s,i)
}
# GFM marker padding of one to four columns is a separator. Greater padding
# consumes only one column, leaving an indented block as actual item content.
function marker_content(s, prefix, marker, padding) {
  marker_indent=0
  if (!match(s,/^ ? ? ?([-+*]|[0-9]{1,9}[.)])([ \t]+|$)/)) return s
  prefix=substr(s,1,RLENGTH); marker=prefix; sub(/[ \t]+$/, "", marker)
  padding=column_width(prefix)-column_width(marker)
  if (padding >= 1 && padding <= 4) {
    marker_indent=column_width(prefix)
    return substr(s,length(prefix)+1)
  }
  marker_indent=column_width(marker)+1
  return remove_indent(substr(s,length(marker)+1),1,column_width(marker))
}
# Recognize visible ATX headings and Setext underlines after a real paragraph.
# The enclosing block and list checks decide whether this is a document heading.
function rendered_heading(s, previous, text, stripped, width) {
  heading_text=""
  if (indent_width(s) > 3) return 0
  stripped=s; sub(/^ */, "", stripped)
  if (match(stripped,/^#{1,6}([ \t]|$)/)) {
    width=0; while (substr(stripped,width+1,1) == "#") width++
    heading_text=substr(stripped,width+1)
    sub(/[ \t]+#+[ \t]*$/, "", heading_text)
    heading_text=trim(heading_text)
    return width
  }
  if (previous && text != "" && !quote_paragraph &&
      (!list_indent || indent_width(s) >= list_indent) && stripped ~ /^(=+|-+)[ \t]*$/) {
    heading_text=text
    return substr(stripped,1,1) == "=" ? 1 : 2
  }
  return 0
}
function pipe_header_columns(s, i, last, n) {
  if (indent_width(s) > 3) return 0
  s=trim(s); n=0
  for (i=1; i<=length(s); i++) {
    if (substr(s,i,1) == "\\") { i++; continue }
    if (substr(s,i,1) == "|") { n++; last=i }
  }
  if (!n) return 0
  return n + 1 - (substr(s,1,1) == "|") - (last == length(s))
}
function table_separator_columns(s, cells, n, i) {
  if (indent_width(s) > 3) return 0
  s=trim(s); sub(/^\|/, "", s); sub(/\|$/, "", s)
  n=split(s,cells,"|")
  for (i=1; i<=n; i++) if (trim(cells[i]) !~ /^:?-+:?$/) return 0
  return n
}
function thematic_line(s, compact) {
  compact=s; gsub(/[ \t]/, "", compact)
  return compact ~ /^(-{3,}|\*{3,}|_{3,})$/ && indent_width(s) <= 3
}
function fence_start(s, stripped, mark, width) {
  if (indent_width(s) > 3) return 0
  stripped=s; sub(/^ */, "", stripped); mark=substr(stripped,1,1)
  if (mark != "`" && mark != "~") return 0
  width=0; while (substr(stripped,width+1,1) == mark) width++
  return width >= 3 && (mark == "~" || index(substr(stripped,width+1),"`") == 0)
}
function paragraph_line(s, previous) {
  if (s ~ /^[ \t]*$/ || s ~ /^ ? ? ?(#{1,6}([ \t]|$)|>)/) return 0
  if (thematic_line(s)) return 0
  if (previous && s ~ /^ ? ? ?(=+|-+)[ \t]*$/) return 0
  if (!previous && indent_width(s) >= 4) return 0
  if (s ~ /^ ? ? ?[-+*]([ \t]|$)/ &&
      (!previous || s ~ /^ ? ? ?[-+*][ \t]+[^ \t]/)) return 0
  if (s ~ /^ ? ? ?[0-9]{1,9}[.)]([ \t]|$)/ &&
      (!previous || s ~ /^ ? ? ?0*1[.)][ \t]+[^ \t]/)) return 0
  return 1
}
# Preserve paragraph ownership through a block quote's unmarked lazy lines.
# A quoted heading, fence or raw block cannot own such a continuation.
function content_paragraph(s, previous, saved_paragraph, block, prefix, saved_title, saved_end, reference) {
  # Container markers expose the content that can actually own lazy text.
  while (1) {
    if (match(s,/^ ? ? ?>[ \t]?/)) s=substr(s,RLENGTH+1)
    else if (s ~ /^ ? ? ?([-+*]|[0-9]{1,9}[.)])([ \t]+|$)/) s=marker_content(s)
    else break
    previous=0
  }
  saved_paragraph=paragraph; paragraph=previous
  block=html_start(s); paragraph=saved_paragraph
  if (fence_start(s) || block) return 0
  if (!previous && (prefix=reference_prefix(s))) {
    saved_title=reference_title; saved_end=reference_title_end
    reference=reference_destination_line(trim(substr(s,prefix+1)))
    reference_title=saved_title; reference_title_end=saved_end
    if (reference) return 0
  }
  return paragraph_line(s,previous)
}
function quoted_paragraph(s, quoted) {
  s=expand_tabs(s)
  quoted=0
  while (match(s,/^ ? ? ?>[ \t]?/)) { quoted=1; s=substr(s,RLENGTH+1) }
  if (!quoted) return -1
  return content_paragraph(s,quote_paragraph)
}
# Reference definitions are block content, including a following destination
# and optional multiline title. Their quoted content is not inline Markdown.
function title_close(s, closing, i) {
  for (i=1; i<=length(s); i++) {
    if (substr(s,i,1) == "\\") { i++; continue }
    if (substr(s,i,1) == closing)
      return substr(s,i+1) ~ /^[ \t]*$/ ? 1 : -1
  }
  return 0
}
function reference_title_line(s, opening, closing, result) {
  s=trim(s); opening=substr(s,1,1)
  if (opening != "\"" && opening != "'" && opening != "(") return 0
  closing=(opening == "(" ? ")" : opening)
  result=title_close(substr(s,2), closing)
  if (result < 0) return 0
  reference_title_end=(result ? "" : closing)
  return 1
}
function reference_destination_line(s, tail, angled, i, ch, depth, closed) {
  s=trim(s)
  angled=(substr(s,1,1) == "<")
  depth=0; closed=0
  for (i=(angled ? 2 : 1); i<=length(s); i++) {
    ch=substr(s,i,1)
    if (ch == "\\" && substr(s,i+1,1) ~ /[[:punct:]]/) { i++; continue }
    if (ch ~ /[[:cntrl:]]/ && ch != "\t") return 0
    if (angled) {
      if (ch == "<") return 0
      if (ch == ">") { closed=1; i++; break }
    } else {
      if (ch ~ /[ \t]/) break
      if (ch == "<" || ch == ">") return 0
      if (ch == "(") depth++
      if (ch == ")" && --depth < 0) return 0
    }
  }
  if ((angled && !closed) || (!angled && (i == 1 || depth))) return 0
  tail=substr(s,i)
  if (tail != "" && tail !~ /^[ \t]/) return 0
  if (tail !~ /^[ \t]*$/ && !reference_title_line(tail)) return 0
  reference_title=(tail ~ /^[ \t]*$/)
  return 1
}
function reference_prefix(s, i, start, ch, label) {
  if (!match(s,/^ ? ? ?\[/)) return 0
  start=RLENGTH+1
  for (i=start; i<=length(s); i++) {
    ch=substr(s,i,1)
    if (ch == "\\" && substr(s,i+1,1) ~ /[[:punct:]]/) { i++; continue }
    if (ch == "[") return 0
    if (ch == "]") {
      label=substr(s,start,i-start)
      if (length(label) > 999 || label ~ /^[ \t]*$/ || substr(s,i+1,1) != ":") return 0
      return i+1
    }
  }
  return 0
}
function reference_line(s, result, tail, prefix) {
  if (reference_title_end) {
    if (s ~ /^[ \t]*$/) { refuse("unterminated reference title"); reference_title_end=""; return 0 }
    if (!paragraph_line(s,1) || html_start(s) || fence_start(s)) {
      reference_title_end=""; return 0
    }
    result=title_close(s,reference_title_end)
    if (result < 0) refuse("invalid reference title ending")
    if (result) reference_title_end=""
    return result >= 0
  }
  if (reference_destination_pending) {
    reference_destination_pending=0
    return reference_destination_line(s)
  }
  if (reference_title) {
    reference_title=0
    if (reference_title_line(s)) return 1
  }
  if ((!paragraph || reference_paragraph) && (prefix=reference_prefix(s))) {
    tail=trim(substr(s,prefix+1))
    if (tail == "") { reference_destination_pending=1; return 1 }
    return reference_destination_line(tail)
  }
  return 0
}
{
  sub(/\r$/, "")
  # An unclosed fence also ends when its enclosing list container ends.
  if (fence && fence_container && $0 !~ /^[ \t]*$/ &&
      indent_width($0) < fence_container) {
    fence=""; fence_container=0; list_indent=0; list_blank=0
    clear_paragraph()
  }
  # A list-owned HTML block ends before the first line outside that container.
  if (html && html_container && $0 !~ /^[ \t]*$/ &&
      indent_width($0) < html_container) {
    if (html == "comment") refuse("unterminated HTML comment")
    html=""; html_container=0; list_indent=0; list_blank=0
    clear_paragraph()
  }
  if (html) {
    if (list_indent && $0 ~ /^[ \t]*$/) list_blank=1
    if (html_end($0)) { html=""; html_container=0 }
    clear_paragraph()
    next
  }
  if (!fence && !comment) {
    if (list_indent) {
      if ($0 ~ /^[ \t]*$/) list_blank=1
      else if (list_blank) {
        if (indent_width($0) < list_indent) list_indent=0
        list_blank=0
      }
    }
    if (!table && reference_line($0)) {
      # Definitions are removed from a paragraph when it closes; until then,
      # a custom HTML tag cannot interrupt the surrounding paragraph.
      paragraph=1; paragraph_text=""; reference_paragraph=1; table=0; pipe_columns=0; next
    }
    reference_paragraph=0
    # GitHub ends a list container before a deindented standalone HTML block.
    # Ordinary text can still lazily continue the list paragraph.
    if (list_indent && indent_width($0) < list_indent) {
      previous_paragraph=paragraph; paragraph=0
      if (!html_start($0)) paragraph=previous_paragraph
      else list_indent=0
    }
    html=html_start($0)
    if (html) {
      html_container=(list_indent && indent_width($0) >= list_indent ? list_indent : 0)
      if (html_end($0)) { html=""; html_container=0 }
      clear_paragraph()
      next
    }
  }
  # Validate the raw fence before deciding that comment delimiters are code.
  # Invalid backtick info remains ordinary Markdown and can start a comment.
  stripped=$0; sub(/^ */, "", stripped)
  indent=length($0)-length(stripped); mark=substr(stripped, 1, 1)
  width=0
  if (!comment && indent <= 3 && (mark == "`" || mark == "~")) {
    while (substr(stripped, width+1, 1) == mark) width++
  }
  if (width >= 3) {
    if (!fence) {
      if (mark == "~" || index(substr(stripped, width+1), "`") == 0) {
        fence=mark; fence_width=width
        fence_container=(list_indent && indent_width($0) >= list_indent ? list_indent : 0)
        if (indent < list_indent) list_indent=0
        clear_paragraph(); next
      }
    } else {
      if (mark == fence && width >= fence_width && trim(substr(stripped, width+1)) == "") {
        fence=""; fence_container=0; clear_paragraph()
      }
      next
    }
  }
  if (fence) next
  # Hidden Markdown comments never describe installable catalogue entries.
  paragraph_before_comments=paragraph; nonblank_before_comments=($0 !~ /^[ \t]*$/)
  if (!fence) {
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
  if (list_indent && !list_paragraph && $0 !~ /^[ \t]*$/ &&
      indent_width($0) < list_indent) list_indent=0
  heading=rendered_heading($0,paragraph,paragraph_text)
  if (heading) {
    if (!list_indent || indent_width($0) < list_indent) {
      list_indent=0; list_blank=0
      if (heading <= 2) {
        in_skills=(heading == 2 && heading_text == "Skills")
        if (in_skills && seen_section++) refuse("multiple Skills sections")
      }
    }
    clear_paragraph(); next
  }
  previous_text=paragraph_text; previous_paragraph=paragraph
  list_item=match($0,/^ ? ? ?([-+*]|[0-9]{1,9}[.)])[ \t]+[^ \t]/)
  if (list_item && (thematic_line($0) || (paragraph && paragraph_line($0,1)))) list_item=0
  if (!list_item && !paragraph && $0 ~ /^ ? ? ?([-+*]|[0-9]{1,9}[.)])[ \t]*$/) list_item=1
  if (list_item) { item_content=marker_content(expand_tabs($0)); list_indent=marker_indent }
  if (table && paragraph_line($0, 0)) paragraph=0
  else if (pipe_columns && table_separator_columns($0) == pipe_columns) {
    table=1; catalogue_table=pipe_catalogue; paragraph=0
  }
  else { table=0; catalogue_table=0; paragraph=paragraph_line($0, paragraph) }
  if (paragraph_before_comments && nonblank_before_comments && $0 ~ /^[ \t]*$/) paragraph=1
  if (!table && paragraph) {
    paragraph_text=(previous_paragraph ? previous_text : "")
    if (trim($0) != "") paragraph_text=paragraph_text (paragraph_text != "" ? " " : "") trim($0)
  } else paragraph_text=""
  quoted=quoted_paragraph($0)
  if (quoted >= 0) quote_paragraph=quoted
  else if (!paragraph) quote_paragraph=0
  if (list_item) {
    list_paragraph=content_paragraph(item_content,0)
  } else if (list_indent) {
    if (indent_width($0) >= list_indent)
      list_paragraph=content_paragraph(remove_indent(expand_tabs($0),list_indent),list_paragraph)
    else list_paragraph=(paragraph || quote_paragraph)
  }
  pipe_columns=(!table && paragraph ? pipe_header_columns($0) : 0)
  pipe_catalogue=(!table && pipe_columns == 3)
  if (list_indent && !list_item && !paragraph && $0 !~ /^[ \t]*$/ &&
      indent_width($0) < list_indent) list_indent=0
}
!in_skills { next }
!table { next }
# Other rendered tables retain block context but do not advertise skills.
!catalogue_table { next }
!/\|/ { next }
{
  row=trim($0); sub(/^\|/, "", row); sub(/\|$/, "", row)
  n=split(row, cell, "|")
  if (n != 3) {
    refuse("expected three table cells"); next
  }
  name=plain(trim(cell[1])); upstream=trim(cell[2]); command=plain(trim(cell[3]))
  if (name == "Skill" && upstream == "Upstream" && command == "Install") next
  if (name ~ /^:?-+:?$/ && upstream ~ /^:?-+:?$/ && command ~ /^:?-+:?$/) next
  if (!skill_name(name)) { refuse("invalid skill name"); next }
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
  # Documented options are data. Validate their full grammar and source pin;
  # the batch installer still constructs its own agent and scope arguments.
  if (!options_ok(arg,words,ref)) { refuse("invalid or contradictory install command options"); next }
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
  if (comment || html == "comment") refuse("unterminated HTML comment")
  if (reference_title_end) refuse("unterminated reference title")
  if (!seen_section || !count) { print "error: no skills found in README index" > "/dev/stderr"; bad=1 }
  if (bad) exit 1
  if (mode == "rows") print row_count
  else for (identity in entries) print entries[identity]
}
