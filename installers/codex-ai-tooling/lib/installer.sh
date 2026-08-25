# POSIX helper functions for codex-ai-tooling deterministic tests.
# Source this file; do not execute it directly.

qbit_codex_begin_marker='# qbit-toolkit:codex-ai-tooling:start'
qbit_codex_end_marker='# qbit-toolkit:codex-ai-tooling:end'
qbit_codex_agents_begin_marker='<!-- qbit-toolkit:codex-ai-tooling:start -->'
qbit_codex_agents_end_marker='<!-- qbit-toolkit:codex-ai-tooling:end -->'

normalize_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[ _]+/-/g; s/[^a-z0-9-]/-/g; s/-+/-/g; s/^-//; s/-$//' | cut -c1-50 | sed -E 's/-$//'
}

reject_empty_slug() {
  slug=$(normalize_slug "$1")
  [ -n "$slug" ] || return 1
  printf '%s' "$slug"
}

resolve_profile() {
  requested=$1
  root=$2
  if [ "$requested" != auto ]; then printf '%s' "$requested"; return 0; fi
  if [ -f "$root/tsconfig.json" ] || { [ -f "$root/package.json" ] && grep -Eq '"typescript"[[:space:]]*:' "$root/package.json"; }; then
    printf '%s' typescript
  elif [ -f "$root/Cargo.toml" ]; then
    printf '%s' rust
  else
    printf '%s' generic
  fi
}

validate_origin_value() {
  origin=$1
  explicit=${2:-true}
  case "$origin" in http://*|https://*) ;; *) return 1 ;; esac
  authority=$(printf '%s' "$origin" | sed -E 's#^(https?://[^/\?#]+).*$#\1#')
  host=$(printf '%s' "$authority" | sed -E 's#^https?://([^@:]+@)?([^:]+)(:.*)?$#\2#')
  case "$origin" in *'#'*) return 1 ;; esac
  case "$authority" in *@*) return 1 ;; esac
  case "$host" in *'*'*) return 1 ;; esac
  if [ "$explicit" = false ] && [ "$host" != localhost ] && [ "$host" != 127.0.0.1 ]; then return 1; fi
  printf '%s' "$authority"
}

validate_origin() {
  validate_origin_value "$@"
}

safe_relative_path() {
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9._/-]+$' || return 1
  case "$1" in ""|/*|*'\'*|*'|'*|*:*|*'"'*|*'<'*|*'>'*|*'?'*|*'*'*|*//*|*/|.|./*|*/./*|*/.|..|../*|*/../*|*/..) return 1 ;; esac
  [ -n "$1" ] || return 1
  return 0
}

assert_safe_destination_path() {
  asd_root=$1
  asd_relative=$2
  safe_relative_path "$asd_relative" || return 1
  asd_root_device=$(stat -c '%d' "$asd_root" 2>/dev/null || stat -f '%d' "$asd_root" 2>/dev/null) || return 1
  asd_current=$asd_root
  asd_old_ifs=$IFS
  IFS=/
  set -- $asd_relative
  IFS=$asd_old_ifs
  asd_index=0
  asd_count=$#
  for asd_component in "$@"; do
    asd_index=$((asd_index+1))
    asd_current=$asd_current/$asd_component
    [ ! -L "$asd_current" ] || return 1
    if [ "$asd_index" -lt "$asd_count" ] && [ -e "$asd_current" ]; then
      [ -d "$asd_current" ] || return 1
      asd_device=$(stat -c '%d' "$asd_current" 2>/dev/null || stat -f '%d' "$asd_current" 2>/dev/null) || return 1
      [ "$asd_device" = "$asd_root_device" ] || return 1
    elif [ "$asd_index" -eq "$asd_count" ] && [ -e "$asd_current" ]; then
      [ -f "$asd_current" ] || [ -d "$asd_current" ] || return 1
    fi
  done
}

validate_portable_ownership_state() {
  vpo_root=$1
  vpo_files=$2
  vpo_blocks=$3
  vpo_relative=.qbit-toolkit/codex-ai-tooling/manifest.json
  vpo_expected_hash=$(awk -F '|' -v path="$vpo_relative" '$1==path {print $2; exit}' "$vpo_files")
  [ -n "$vpo_expected_hash" ] || return 0
  vpo_manifest=$vpo_root/$vpo_relative
  [ -f "$vpo_manifest" ] && [ ! -L "$vpo_manifest" ] || return 1
  if command -v sha256sum >/dev/null 2>&1; then vpo_actual_hash=$(sha256sum "$vpo_manifest" | awk '{print $1}'); else vpo_actual_hash=$(shasum -a 256 "$vpo_manifest" | awk '{print $1}'); fi
  [ "$vpo_actual_hash" = "$vpo_expected_hash" ] || return 1
  vpo_tmp=${vpo_files}.portable.$$
  vpo_expected=$vpo_tmp.expected
  vpo_actual=$vpo_tmp.actual
  awk -F '|' -v path="$vpo_relative" '$1!=path {print $1}' "$vpo_files" | LC_ALL=C sort > "$vpo_expected"
  awk '
    /"installed_entries"[[:space:]]*:/ {section=1; next}
    /"managed_blocks"[[:space:]]*:/ {section=2; next}
    section==1 && /"relative_path"[[:space:]]*:/ {
      line=$0; sub(/^.*"relative_path"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); print line
    }
  ' "$vpo_manifest" | LC_ALL=C sort > "$vpo_actual"
  cmp -s "$vpo_expected" "$vpo_actual" || { rm -f "$vpo_expected" "$vpo_actual"; return 1; }
  awk -F '|' '{print $1 "|" $2}' "$vpo_blocks" | LC_ALL=C sort > "$vpo_expected"
  awk '
    /"managed_blocks"[[:space:]]*:/ {section=1; next}
    /"generated_state_entries"[[:space:]]*:/ {section=0}
    section && /"relative_path"[[:space:]]*:/ {
      line=$0; sub(/^.*"relative_path"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); path=line
    }
    section && /"sha256"[[:space:]]*:/ {
      line=$0; sub(/^.*"sha256"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); print path "|" line; path=""
    }
  ' "$vpo_manifest" | LC_ALL=C sort > "$vpo_actual"
  cmp -s "$vpo_expected" "$vpo_actual" || { rm -f "$vpo_expected" "$vpo_actual"; return 1; }
  rm -f "$vpo_expected" "$vpo_actual"
}

render_template_text() {
  text=$1
  key=$2
  value=$3
  printf '%s' "$text" | sed "s/{{${key}}}/$(printf '%s' "$value" | sed 's/[\\/&]/\\&/g')/g"
}

merge_managed_block_text() {
  existing_file=$1
  body_file=$2
  output_file=$3
  meta_file=
  if [ "$#" -ge 6 ]; then
    meta_file=$4
    begin=$5
    end=$6
  else
    begin=${4:-$qbit_codex_begin_marker}
    end=${5:-$qbit_codex_end_marker}
  fi
  created_file=false
  [ -f "$existing_file" ] || created_file=true
  block_file=$output_file.block.$$
  write_managed_block_text "$body_file" "$block_file" "$begin" "$end"
  if [ ! -f "$existing_file" ]; then
    cat "$block_file" > "$output_file"
    [ -n "$meta_file" ] && printf '%s\n%s\n' "$created_file" 0 > "$meta_file"
    rm -f "$block_file"
    return 0
  fi
  if managed_block_has_valid_block "$existing_file" "$begin" "$end"; then
    managed_block_replace_file "$existing_file" "$block_file" "$output_file" "$begin" "$end"
    [ -n "$meta_file" ] && printf '%s\n%s\n' false 0 > "$meta_file"
  else
    managed_block_assert_absent_or_valid "$existing_file" "$begin" "$end" || { rm -f "$block_file"; return 1; }
    sep=$(managed_block_append_separator_count "$existing_file")
    cat "$existing_file" > "$output_file"
    i=0; while [ "$i" -lt "$sep" ]; do printf '\n' >> "$output_file"; i=$((i+1)); done
    cat "$block_file" >> "$output_file"
    [ -n "$meta_file" ] && printf '%s\n%s\n' "$created_file" "$sep" > "$meta_file"
  fi
  rm -f "$block_file"
}

write_managed_block_text() {
  w_body_file=$1
  w_output_file=$2
  w_begin=${3:-$qbit_codex_begin_marker}
  w_end=${4:-$qbit_codex_end_marker}
  printf '%s\n' "$w_begin" > "$w_output_file"
  cat "$w_body_file" >> "$w_output_file"
  w_last=$(tail -c 1 "$w_output_file" 2>/dev/null | od -An -t u1 | tr -d ' ')
  [ "$w_last" = 10 ] || printf '\n' >> "$w_output_file"
  printf '%s\n' "$w_end" >> "$w_output_file"
}

managed_block_line_count() {
  file=$1; marker=$2
  grep -F -x "$marker" "$file" 2>/dev/null | wc -l | tr -d ' '
}

managed_block_embedded_count() {
  file=$1; marker=$2
  grep -F "$marker" "$file" 2>/dev/null | grep -F -v -x "$marker" | wc -l | tr -d ' '
}

managed_block_assert_absent_or_valid() {
  file=$1; begin=$2; end=$3
  [ "$(managed_block_embedded_count "$file" "$begin")" = 0 ] || { echo "Managed block begin marker is embedded in non-marker text: $file" >&2; return 1; }
  [ "$(managed_block_embedded_count "$file" "$end")" = 0 ] || { echo "Managed block end marker is embedded in non-marker text: $file" >&2; return 1; }
  bc=$(managed_block_line_count "$file" "$begin")
  ec=$(managed_block_line_count "$file" "$end")
  if [ "$bc" = 0 ] && [ "$ec" = 0 ]; then return 0; fi
  [ "$bc" -ne 0 ] || { echo "Managed block begin marker is missing: $file" >&2; return 1; }
  [ "$ec" -ne 0 ] || { echo "Managed block end marker is missing: $file" >&2; return 1; }
  [ "$bc" -eq 1 ] || { echo "Managed block begin marker is duplicated: $file" >&2; return 1; }
  [ "$ec" -eq 1 ] || { echo "Managed block end marker is duplicated: $file" >&2; return 1; }
  bo=$(managed_block_begin_offset "$file" "$begin")
  eo=$(managed_block_begin_offset "$file" "$end")
  [ "$bo" -lt "$eo" ] || { echo "Managed block markers are reversed: $file" >&2; return 1; }
}

managed_block_has_valid_block() {
  file=$1; begin=$2; end=$3
  managed_block_assert_absent_or_valid "$file" "$begin" "$end" || return 1
  [ "$(managed_block_line_count "$file" "$begin")" -eq 1 ]
}

managed_block_begin_offset() {
  file=$1; marker=$2
  grep -a -b -F -x "$marker" "$file" | sed -n '1s/:.*//p'
}

managed_block_end_offset() {
  file=$1; end=$2
  eo=$(managed_block_begin_offset "$file" "$end")
  end_len=${#end}
  line_end=$((eo + end_len))
  byte=$(dd if="$file" bs=1 skip="$line_end" count=1 2>/dev/null | od -An -t u1 | tr -d ' ')
  if [ "$byte" = 10 ]; then echo $((line_end + 1)); else echo "$line_end"; fi
}

managed_block_append_separator_count() {
  file=$1
  [ -s "$file" ] || { echo 0; return 0; }
  byte=$(tail -c 1 "$file" | od -An -t u1 | tr -d ' ')
  if [ "$byte" = 10 ]; then echo 1; else echo 2; fi
}

managed_block_replace_file() {
  existing_file=$1; block_file=$2; output_file=$3; begin=$4; end=$5
  start=$(managed_block_begin_offset "$existing_file" "$begin")
  finish=$(managed_block_end_offset "$existing_file" "$end")
  : > "$output_file"
  [ "$start" -gt 0 ] && dd if="$existing_file" bs=1 count="$start" 2>/dev/null >> "$output_file"
  cat "$block_file" >> "$output_file"
  size=$(wc -c < "$existing_file" | tr -d ' ')
  [ "$finish" -lt "$size" ] && dd if="$existing_file" bs=1 skip="$finish" 2>/dev/null >> "$output_file"
  return 0
}

managed_block_extract_file() {
  existing_file=$1; output_file=$2; begin=$3; end=$4
  managed_block_assert_absent_or_valid "$existing_file" "$begin" "$end" || return 1
  [ "$(managed_block_line_count "$existing_file" "$begin")" -eq 1 ] || return 1
  start=$(managed_block_begin_offset "$existing_file" "$begin")
  finish=$(managed_block_end_offset "$existing_file" "$end")
  dd if="$existing_file" bs=1 skip="$start" count=$((finish - start)) 2>/dev/null > "$output_file"
  last=$(tail -c 1 "$output_file" | od -An -t u1 | tr -d ' ')
  [ "$last" = 10 ] || printf '\n' >> "$output_file"
}

managed_block_remove_file() {
  mbr_existing_file=$1; mbr_output_file=$2; mbr_begin=$3; mbr_end=$4; mbr_sep=$5; mbr_force=${6:-false}
  managed_block_assert_absent_or_valid "$mbr_existing_file" "$mbr_begin" "$mbr_end" || return 1
  mbr_start=$(managed_block_begin_offset "$mbr_existing_file" "$mbr_begin")
  mbr_finish=$(managed_block_end_offset "$mbr_existing_file" "$mbr_end")
  mbr_remove_start=$mbr_start
  if [ "$mbr_sep" -gt 0 ]; then
    if [ "$mbr_start" -lt "$mbr_sep" ]; then [ "$mbr_force" = true ] || return 1; else
      mbr_check=$(dd if="$mbr_existing_file" bs=1 skip=$((mbr_start - mbr_sep)) count="$mbr_sep" 2>/dev/null | od -An -t u1 | tr -d ' \n')
      mbr_expected=''; mbr_i=0; while [ "$mbr_i" -lt "$mbr_sep" ]; do mbr_expected=${mbr_expected}10; mbr_i=$((mbr_i+1)); done
      if [ "$mbr_check" = "$mbr_expected" ]; then mbr_remove_start=$((mbr_start - mbr_sep)); else [ "$mbr_force" = true ] || return 1; fi
    fi
  fi
  : > "$mbr_output_file"
  [ "$mbr_remove_start" -gt 0 ] && dd if="$mbr_existing_file" bs=1 count="$mbr_remove_start" 2>/dev/null >> "$mbr_output_file"
  mbr_size=$(wc -c < "$mbr_existing_file" | tr -d ' ')
  [ "$mbr_finish" -lt "$mbr_size" ] && dd if="$mbr_existing_file" bs=1 skip="$mbr_finish" 2>/dev/null >> "$mbr_output_file"
  return 0
}

text_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum | awk '{print $1}'; else printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; fi
}

validate_project_display_name() {
  LC_ALL=C printf '%s\001' "$1" | od -An -t u1 | awk '
    { for (i=1; i<=NF; i++) bytes[++count]=$i }
    END {
      if (count == 0 || bytes[count] != 1) exit 1
      for (i=1; i<count; i++) {
        if (bytes[i] < 32 || bytes[i] == 127) exit 1
        if (bytes[i] == 194 && i+1 < count && bytes[i+1] >= 128 && bytes[i+1] <= 159) exit 1
      }
    }
  '
}

json_escape() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { first=1; for (i=1; i<32; i++) control[sprintf("%c", i)]=i; hex="0123456789abcdef" }
    {
      if (!first) printf "\\n"
      first=0
      for (i=1; i<=length($0); i++) {
        c=substr($0,i,1)
        if (c == "\\") printf "\\\\"
        else if (c == "\"") printf "\\\""
        else if (c == "\b") printf "\\b"
        else if (c == "\f") printf "\\f"
        else if (c == "\r") printf "\\r"
        else if (c == "\t") printf "\\t"
        else if (c in control) printf "\\u00%s%s", substr(hex,int(control[c]/16)+1,1),substr(hex,(control[c]%16)+1,1)
        else printf "%s", c
      }
    }
  '
}

json_quote() { printf '"%s"' "$(json_escape "$1")"; }

build_template_source_manifest() {
  bts_installer=$1; bts_profile=$2; bts_output=$3
  case "$bts_profile" in generic|typescript|rust) ;; *) return 1 ;; esac
  bts_tmp=$bts_output.build.$$
  bts_raw=$bts_tmp.raw
  bts_unsorted=$bts_tmp.unsorted
  : > "$bts_raw"
  bts_priority=0
  for bts_root in "$bts_installer/templates/common" "$bts_installer/templates/profiles/$bts_profile"; do
    [ -d "$bts_root" ] || { rm -f "$bts_raw" "$bts_unsorted"; return 1; }
    find "$bts_root" -type f | LC_ALL=C sort > "$bts_tmp.files"
    while IFS= read -r bts_source; do
      bts_rel=${bts_source#"$bts_root/"}
      [ "$bts_rel" = README.md ] && continue
      case "$bts_rel" in *.tpl) bts_rel=${bts_rel%'.tpl'} ;; esac
      safe_relative_path "$bts_rel" || { rm -f "$bts_raw" "$bts_unsorted" "$bts_tmp.files"; return 1; }
      printf '%s|%s|%s\n' "$bts_priority" "$bts_rel" "$bts_source" >> "$bts_raw"
    done < "$bts_tmp.files"
    bts_priority=$((bts_priority+1))
  done
  rm -f "$bts_tmp.files"
  if ! awk -F '|' '
    {
      key=$1 SUBSEP $2
      folded=tolower($2)
      if (seen[key]++) exit 1
      if ((folded in case_path) && case_path[folded] != $2) exit 1
      case_path[folded]=$2
      source[$2]=$3
    }
    END { if (bad) exit 1; for (rel in source) print rel "|" source[rel] }
  ' "$bts_raw" > "$bts_unsorted"; then rm -f "$bts_raw" "$bts_unsorted"; return 1; fi
  LC_ALL=C sort "$bts_unsorted" > "$bts_output"
  rm -f "$bts_raw" "$bts_unsorted"
}

expected_managed_paths() {
  emp_installer=$1; emp_profile=$2; emp_output=$3
  emp_sources=$emp_output.sources.$$
  build_template_source_manifest "$emp_installer" "$emp_profile" "$emp_sources" || { rm -f "$emp_sources"; return 1; }
  awk -F '|' '{print $1}' "$emp_sources" > "$emp_output"
  rm -f "$emp_sources"
}

parse_and_validate_state() {
  pvs_state=$1
  pvs_files=$2
  pvs_blocks=$3
  pvs_installed=$4
  pvs_metadata=$5
  pvs_installer=$6
  pvs_files_tmp=$pvs_files.tmp.$$
  pvs_blocks_tmp=$pvs_blocks.tmp.$$
  pvs_installed_tmp=$pvs_installed.tmp.$$
  pvs_metadata_tmp=$pvs_metadata.tmp.$$
  if LC_ALL=C awk -v files_out="$pvs_files_tmp" -v blocks_out="$pvs_blocks_tmp" -v installed_out="$pvs_installed_tmp" -v metadata_out="$pvs_metadata_tmp" '
    function invalid() { bad=1; exit 1 }
    function safe_path(path, count, parts, i) {
      if (path == "" || path ~ /[^A-Za-z0-9._\/-]/ || path ~ /^\// || path ~ /[|\\:"<>?*]/) return 0
      count=split(path, parts, "/")
      for (i=1; i<=count; i++) if (parts[i] == "" || parts[i] == "." || parts[i] == "..") return 0
      return 1
    }
    function valid_hash(hash) { return length(hash) == 64 && hash !~ /[^0-9a-f]/ }
    function valid_json_string(value, i, c, escape, hexpart) {
      if (length(value) < 2 || substr(value,1,1) != "\"" || substr(value,length(value),1) != "\"") return 0
      for (i=2; i<length(value); i++) {
        c=substr(value,i,1)
        if (c == "\"") return 0
        if (c ~ /[[:cntrl:]]/) return 0
        if (c == "\\") {
          i++; if (i >= length(value)) return 0
          escape=substr(value,i,1)
          if (escape == "u") { hexpart=substr(value,i+1,4); if (length(hexpart) != 4 || hexpart ~ /[^0-9a-fA-F]/) return 0; i+=4 }
          else if (escape !~ /^["\\\/bfnrt]$/) return 0
        }
      }
      return 1
    }
    function json_string_has_decoded_control(value, i, c, escape, hexpart, lowerhex, current_byte, next_byte) {
      for (i=2; i<length(value); i++) {
        c=substr(value,i,1)
        current_byte=byte_value[c]
        next_byte=byte_value[substr(value,i+1,1)]
        if (current_byte == 194 && next_byte >= 128 && next_byte <= 159) return 1
        if (c != "\\") continue
        i++; escape=substr(value,i,1)
        if (escape ~ /^[bfnrt]$/) return 1
        if (escape == "u") {
          hexpart=substr(value,i+1,4); lowerhex=tolower(hexpart)
          if (lowerhex ~ /^00(0[0-9a-f]|1[0-9a-f]|7f|8[0-9a-f]|9[0-9a-f])$/) return 1
          i+=4
        }
      }
      return 0
    }
    function valid_utc_timestamp(value, year, month, day, hour, minute, second, maxday, leap) {
      if (value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) return 0
      year=substr(value,1,4)+0; month=substr(value,6,2)+0; day=substr(value,9,2)+0
      hour=substr(value,12,2)+0; minute=substr(value,15,2)+0; second=substr(value,18,2)+0
      if (year < 1 || month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59) return 0
      if (month == 2) { leap=(year%4==0 && (year%100!=0 || year%400==0)); maxday=leap ? 29 : 28 }
      else if (month==4 || month==6 || month==9 || month==11) maxday=30
      else maxday=31
      return day >= 1 && day <= maxday
    }
    function plain_json_string(value) { return valid_json_string(value) && value !~ /\\/ ? substr(value,2,length(value)-2) : "" }
    function array_value(line, value) { value=line; sub(/^    /,"",value); sub(/,$/,"",value); return value }
    BEGIN {
      phase=0
      for (byte_index=1; byte_index<256; byte_index++) byte_value[sprintf("%c",byte_index)]=byte_index
      printf "%s", "" > files_out
      close(files_out)
      printf "%s", "" > blocks_out
      close(blocks_out)
      printf "%s", "" > installed_out
      close(installed_out)
      printf "%s", "" > metadata_out
      close(metadata_out)
    }
    {
      line=$0
      if (phase == 0) { if (line != "{") invalid(); phase=1; next }
      if (phase == 1) { if (line != "  \"schemaVersion\": \"1.0\",") invalid(); phase=2; next }
      if (phase == 2) { if (line != "  \"installerId\": \"installer.codex-ai-tooling\",") invalid(); phase=3; next }
      if (phase == 3) { if (line != "  \"installerVersion\": \"1.0.0\"," && line != "  \"installerVersion\": \"1.1.0\"," && line != "  \"installerVersion\": \"1.1.1\"," && line != "  \"installerVersion\": \"1.1.2\"," && line != "  \"installerVersion\": \"1.1.3\",") invalid(); phase=4; next }
      if (phase == 4) { if (line != "  \"toolkitSchemaVersion\": \"1.0\",") invalid(); phase=5; next }
      if (phase == 5) {
        if (line !~ /^  "profile": "(generic|typescript|rust)",$/) invalid()
        profile=line; sub(/^  "profile": "/,"",profile); sub(/",$/,"",profile)
        print "profile|" profile > metadata_out; phase=6; next
      }
      if (phase == 6) {
        if (line !~ /^  "projectSlug": "[a-z0-9]+(-[a-z0-9]+)*",$/) invalid()
        slug=line; sub(/^  "projectSlug": "/,"",slug); sub(/",$/,"",slug); if (length(slug)>50) invalid(); print "projectSlug|" slug >> metadata_out; phase=7; next
      }
      if (phase == 7) {
        value=line; sub(/^  "projectDisplayName": /,"",value); sub(/,$/,"",value)
        if (line !~ /^  "projectDisplayName": .*,$/ || !valid_json_string(value) || json_string_has_decoded_control(value)) invalid(); phase=8; next
      }
      if (phase == 8) { if (line != "  \"allowedOrigins\": [") invalid(); phase=9; next }
      if (phase == 9) {
        if (line == "  ],") { if (origin_count == 0 || origin_had_comma) invalid(); phase=10; next }
        value=array_value(line); origin=plain_json_string(value)
        if (origin == "" || origin !~ /^https?:\/\/[^ \/?#@*]+$/ || seen_origin[origin]++ || (origin_count>0 && !origin_had_comma)) invalid()
        origin_had_comma=(line ~ /,$/); origin_count++; next
      }
      if (phase == 10) {
        value=line; sub(/^  "dockerImageName": /,"",value); sub(/,$/,"",value); docker=plain_json_string(value)
        if (line !~ /^  "dockerImageName": .*,$/ || docker == "") invalid(); print "dockerImageName|" docker >> metadata_out; phase=11; next
      }
      if (phase == 11) {
        if (line !~ /^  "installedAtUtc": "[^"]+",$/) invalid()
        installed_at=line; sub(/^  "installedAtUtc": "/,"",installed_at); sub(/",$/,"",installed_at)
        if (!valid_utc_timestamp(installed_at)) invalid()
        print "installedAtUtc|" installed_at >> metadata_out; phase=12; next
      }
      if (phase == 12) { if (line != "  \"installedRelativePaths\": [") invalid(); phase=13; next }
      if (phase == 13) {
        if (line == "  ],") { if (installed_count == 0 || installed_had_comma) invalid(); phase=14; next }
        value=array_value(line); path=plain_json_string(value)
        if (!safe_path(path) || seen_installed[path]++ || (installed_count>0 && !installed_had_comma) || (previous_installed != "" && path <= previous_installed)) invalid()
        print path >> installed_out; previous_installed=path; installed_had_comma=(line ~ /,$/); installed_count++; next
      }
      if (phase == 14) { if (line != "  \"managedFiles\": {") invalid(); phase=15; next }
      if (phase == 15) {
        if (line == "  },") {
          if (file_count == 0 || file_had_comma) invalid()
          phase=16; next
        }
        if (line !~ /^    "[^"]+": "[^"]+"[,]?$/) invalid()
        if (file_count > 0 && !file_had_comma) invalid()
        value=line; sub(/^    "/, "", value); path=value; sub(/".*/, "", path)
        value=line; sub(/^    "[^"]+": "/, "", value); hash=value; sub(/"[,]?$/, "", hash)
        if (!safe_path(path) || path == "AGENTS.md" || seen_file[path]++ || !valid_hash(hash) || (previous_file != "" && path <= previous_file)) invalid()
        print path "|" hash >> files_out
        previous_file=path
        file_had_comma=(line ~ /,$/)
        file_count++
        next
      }
      if (phase == 16) { if (line != "  \"managedBlocks\": {") invalid(); phase=17; next }
      if (phase == 17) {
        if (!in_record) {
          if (line == "  },") {
            if (block_count != 3 || block_had_comma) invalid()
            phase=18; next
          }
          if (line !~ /^    "[^"]+": \{$/) invalid()
          if (block_count > 0 && !block_had_comma) invalid()
          value=line; sub(/^    "/, "", value); path=value; sub(/".*/, "", path)
          if (!safe_path(path) || (path != ".gitignore" && path != ".gitattributes" && path != "AGENTS.md") || seen_block[path]++ || (previous_block != "" && path <= previous_block)) invalid()
          block_path=path; sha=""; created=""; sep=""; sha_count=0; created_count=0; sep_count=0; in_record=1
          previous_block=path
          next
        }
        if (line ~ /^      "sha256": "[^"]+",$/) {
          sha=line; sub(/^      "sha256": "/, "", sha); sub(/",$/, "", sha); sha_count++; next
        }
        if (line ~ /^      "createdFile": (true|false),$/) {
          created=line; sub(/^      "createdFile": /, "", created); sub(/,$/, "", created); created_count++; next
        }
        if (line ~ /^      "insertedSeparatorLfCount": [0-9]+$/) {
          sep=line; sub(/^      "insertedSeparatorLfCount": /, "", sep); sep_count++; next
        }
        if (line ~ /^    }[,]?$/) {
          if (sha_count != 1 || created_count != 1 || sep_count != 1 || !valid_hash(sha) || (created != "true" && created != "false") || (sep != "0" && sep != "1" && sep != "2")) invalid()
          print block_path "|" sha "|" created "|" sep >> blocks_out
          block_had_comma=(line ~ /,$/)
          block_count++
          in_record=0
          next
        }
        invalid()
      }
      if (phase == 18) { if (line != "  \"stateFile\": \".qbit/toolkit/installed/codex-ai-tooling.json\"") invalid(); phase=19; next }
      if (phase == 19) { if (line != "}") invalid(); phase=20; next }
      invalid()
    }
    END {
      if (bad || phase != 20 || in_record || !seen_block[".gitignore"] || !seen_block[".gitattributes"] || !seen_block["AGENTS.md"]) exit 1
    }
  ' "$pvs_state"; then
    pvs_actual=$pvs_files.actual.$$
    pvs_expected_installed=$pvs_installed.expected.$$
    awk -F '|' '{print $1}' "$pvs_files_tmp" > "$pvs_actual"
    pvs_expected_unsorted=$pvs_expected_installed.unsorted
    cat "$pvs_actual" > "$pvs_expected_unsorted"
    printf '%s\n' .gitignore .gitattributes AGENTS.md .qbit/toolkit/installed/codex-ai-tooling.json >> "$pvs_expected_unsorted"
    LC_ALL=C sort "$pvs_expected_unsorted" > "$pvs_expected_installed"
    rm -f "$pvs_expected_unsorted"
    if ! cmp -s "$pvs_expected_installed" "$pvs_installed_tmp"; then rm -f "$pvs_files_tmp" "$pvs_blocks_tmp" "$pvs_installed_tmp" "$pvs_metadata_tmp" "$pvs_actual" "$pvs_expected_installed"; return 1; fi
    mv "$pvs_files_tmp" "$pvs_files"; mv "$pvs_blocks_tmp" "$pvs_blocks"; mv "$pvs_installed_tmp" "$pvs_installed"; mv "$pvs_metadata_tmp" "$pvs_metadata"
    rm -f "$pvs_actual" "$pvs_expected_installed"
    return 0
  fi
  rm -f "$pvs_files_tmp" "$pvs_blocks_tmp" "$pvs_installed_tmp" "$pvs_metadata_tmp"
  return 1
}
