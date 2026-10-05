#!/usr/bin/env bash
# Refuse literal NUL and lone surrogate escapes before shell/JSON decoding.
validate_json_unicode_escapes() {
  local input=$1 data char escape hex low i=0 length in_string=0 backslash=$'\\'
  local LC_ALL=C

  # The sentinel prevents command substitution from stripping input newlines.
  data=$(cat -- "$input" && printf x) || return 1
  data=${data%x}
  length=${#data}

  while ((i < length)); do
    char=${data:i:1}
    if ((in_string == 0)); then
      [[ $char == '"' ]] && in_string=1
      i=$((i + 1))
      continue
    fi
    if [[ $char == '"' ]]; then
      in_string=0
      i=$((i + 1))
      continue
    fi
    if [[ $char != "$backslash" ]]; then
      i=$((i + 1))
      continue
    fi

    # Non-Unicode escapes, including an escaped backslash, consume two bytes.
    if ((i + 1 >= length)); then
      i=$((i + 1))
      continue
    fi
    escape=${data:i+1:1}
    if [[ $escape != u ]]; then
      i=$((i + 2))
      continue
    fi

    # jq reports malformed escapes. This boundary only prevents valid JSON
    # syntax from being decoded into different text.
    hex=${data:i+2:4}
    if [[ ! $hex =~ ^[0-9A-Fa-f]{4}$ ]]; then
      i=$((i + 2))
      continue
    fi
    if [[ $hex =~ ^[dD][89AaBb][0-9A-Fa-f]{2}$ ]]; then
      if ((i + 12 > length)) || [[ ${data:i+6:2} != "${backslash}u" ]]; then
        return 1
      fi
      low=${data:i+8:4}
      [[ $low =~ ^[dD][cCdDeEfF][0-9A-Fa-f]{2}$ ]] || return 1
      i=$((i + 12))
      continue
    fi
    [[ ! $hex =~ ^[dD][cCdDeEfF][0-9A-Fa-f]{2}$ ]] || return 1
    i=$((i + 6))
  done
}

[[ $# == 1 ]] || exit 2
input=$1
[[ $input == /* ]] || input="./$input"
[[ -f $input && -r $input ]] || exit 2
umask 077
work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT
# Retain one complete named-file observation before Bash can strip literal NUL.
cat -- "$input" > "$work/input" || exit 2
LC_ALL=C tr -d '\000' < "$work/input" > "$work/without-nul" || exit 2
cmp -s "$work/input" "$work/without-nul" || {
  printf 'input contains a literal NUL byte or could not be fully read\n' >&2
  exit 2
}
# The comparison copy never becomes evidence; inspect the original snapshot.
validate_json_unicode_escapes "$work/input"
