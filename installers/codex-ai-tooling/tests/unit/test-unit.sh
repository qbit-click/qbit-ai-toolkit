#!/usr/bin/env sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
installer_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
. "$installer_root/lib/installer.sh"
pass=0
fail=0
skip=0
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-unit-sh)
cleanup(){ rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM
assert_eq(){ expected=$1; actual=$2; message=$3; [ "$expected" = "$actual" ] || { echo "$message expected=[$expected] actual=[$actual]" >&2; return 1; }; }
assert_fail(){ message=$1; shift; if "$@" >/dev/null 2>&1; then echo "$message" >&2; return 1; fi; }
assert_file_eq(){ expected=$1; actual=$2; message=$3; cmp -s "$expected" "$actual" || { echo "$message" >&2; echo "expected bytes:" >&2; od -An -t u1 "$expected" >&2; echo "actual bytes:" >&2; od -An -t u1 "$actual" >&2; return 1; }; }
file_sha256(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
scenario(){ name=$1; shift; if "$@"; then pass=$((pass+1)); echo "PASS $name"; else fail=$((fail+1)); echo "FAIL $name" >&2; fi; }
slug_normalizes(){ actual=$(normalize_slug ' My_Project Name!! '); assert_eq 'my-project-name' "$actual" 'slug normalization failed'; }
slug_rejects_empty(){ assert_fail 'empty slug accepted' reject_empty_slug '___!!!'; }
slug_max_length(){ actual=$(normalize_slug 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'); [ ${#actual} -eq 50 ]; }
profile_tsconfig(){ repo=$tmp/tsconfig; mkdir -p "$repo"; echo '{}' > "$repo/tsconfig.json"; actual=$(resolve_profile auto "$repo"); assert_eq typescript "$actual" 'tsconfig profile failed'; }
profile_dependencies(){ repo=$tmp/deps; mkdir -p "$repo"; printf '{"dependencies":{"typescript":"5.9.3"}}' > "$repo/package.json"; actual=$(resolve_profile auto "$repo"); assert_eq typescript "$actual" 'dependencies profile failed'; }
profile_devdependencies(){ repo=$tmp/devdeps; mkdir -p "$repo"; printf '{"devDependencies":{"typescript":"5.9.3"}}' > "$repo/package.json"; actual=$(resolve_profile auto "$repo"); assert_eq typescript "$actual" 'devDependencies profile failed'; }
profile_generic(){ repo=$tmp/generic; mkdir -p "$repo"; actual=$(resolve_profile auto "$repo"); assert_eq generic "$actual" 'generic fallback failed'; }
profile_rust(){ repo=$tmp/rust; mkdir -p "$repo"; echo '[package]' > "$repo/Cargo.toml"; actual=$(resolve_profile auto "$repo"); assert_eq rust "$actual" 'Cargo.toml profile failed'; }
profile_explicit_rust(){ repo=$tmp/explicit-rust; mkdir -p "$repo"; actual=$(resolve_profile rust "$repo"); assert_eq rust "$actual" 'explicit rust failed'; }
profile_ts_precedence(){ repo=$tmp/ts-rust; mkdir -p "$repo"; echo '[package]' > "$repo/Cargo.toml"; echo '{}' > "$repo/tsconfig.json"; actual=$(resolve_profile auto "$repo"); assert_eq typescript "$actual" 'TypeScript did not win over Rust'; }
profile_nested_cargo_generic(){ repo=$tmp/nested-rust; mkdir -p "$repo/crates/app"; echo '[package]' > "$repo/crates/app/Cargo.toml"; actual=$(resolve_profile auto "$repo"); assert_eq generic "$actual" 'nested Cargo.toml activated Rust'; }
origin_accepts_http(){ actual=$(validate_origin_value 'http://localhost:3000/path' true); assert_eq 'http://localhost:3000' "$actual" 'http origin failed'; }
origin_accepts_ipv6(){ actual=$(validate_origin_value 'http://[::1]:3000/path' true); assert_eq 'http://[::1]:3000' "$actual" 'IPv6 origin failed'; }
origin_rejects_scheme(){ assert_fail 'non-http scheme accepted' validate_origin_value 'ftp://localhost' true; }
origin_rejects_relative(){ assert_fail 'relative origin accepted' validate_origin_value '/relative' true; }
origin_rejects_credentials(){ assert_fail 'credential origin accepted' validate_origin_value 'http://user:pass@localhost:3000' true; }
origin_rejects_fragment(){ assert_fail 'fragment origin accepted' validate_origin_value 'http://localhost:3000/#frag' true; }
origin_rejects_wildcard(){ assert_fail 'wildcard origin accepted' validate_origin_value 'http://*.example.test' true; }
path_rejects_traversal(){ assert_fail 'traversal path accepted' safe_relative_path '../escape'; }
path_accepts_nested(){ safe_relative_path 'a/b.txt'; }
path_rejects_non_ascii(){ assert_fail 'non-ASCII managed path accepted' safe_relative_path 'ascii/café.txt'; }
render_replaces_placeholder(){ placeholder='{{''NAME''}}'; actual=$(render_template_text "Hello $placeholder" NAME Qbit); assert_eq 'Hello Qbit' "$actual" 'render failed'; }
block_insert(){ existing=$tmp/existing; body=$tmp/body; out=$tmp/out; echo alpha > "$existing"; echo beta > "$body"; merge_managed_block_text "$existing" "$body" "$out"; grep -q alpha "$out" && grep -q beta "$out" && grep -q 'qbit-toolkit:codex-ai-tooling' "$out"; }
block_replace(){ existing=$tmp/existing2; body=$tmp/body2; out=$tmp/out2; printf 'before\n%s\nold\n%s\nafter\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; echo new > "$body"; merge_managed_block_text "$existing" "$body" "$out"; grep -q before "$out" && grep -q after "$out" && grep -q new "$out" && ! grep -q old "$out"; }
block_duplicate_rejected(){ existing=$tmp/existing3; body=$tmp/body3; out=$tmp/out3; printf '%s\na\n%s\n%s\nb\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; echo body > "$body"; assert_fail 'duplicate marker accepted' merge_managed_block_text "$existing" "$body" "$out"; }
agents_block_insert(){ existing=$tmp/agents; body=$tmp/agents_body; out=$tmp/agents_out; printf '# Repo\n\nBuild commands stay here.\n' > "$existing"; echo 'AI tooling only.' > "$body"; merge_managed_block_text "$existing" "$body" "$out" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; grep -q '# Repo' "$out" && grep -q 'Build commands stay here' "$out" && grep -q 'AI tooling only' "$out"; }
agents_block_replace(){ existing=$tmp/agents2; body=$tmp/agents_body2; out=$tmp/agents_out2; printf '# Repo\n%s\nold\n%s\nKeep this.\n' "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker" > "$existing"; echo new > "$body"; merge_managed_block_text "$existing" "$body" "$out" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; grep -q '# Repo' "$out" && grep -q 'Keep this' "$out" && grep -q new "$out" && ! grep -q old "$out"; }
agents_block_duplicate_rejected(){ existing=$tmp/agents3; body=$tmp/agents_body3; out=$tmp/agents_out3; printf '%s\na\n%s\n%s\nb\n%s\n' "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker" > "$existing"; echo body > "$body"; assert_fail 'duplicate AGENTS marker accepted' merge_managed_block_text "$existing" "$body" "$out" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; }
agents_block_unbalanced_rejected(){ existing=$tmp/agents4; body=$tmp/agents_body4; out=$tmp/agents_out4; printf '%s\na\n' "$qbit_codex_agents_begin_marker" > "$existing"; echo body > "$body"; assert_fail 'unbalanced AGENTS marker accepted' merge_managed_block_text "$existing" "$body" "$out" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; }
block_exact_line_marker_rejected(){ existing=$tmp/exact_marker; body=$tmp/exact_body; out=$tmp/exact_out; printf 'prefix %s suffix\n' "$qbit_codex_begin_marker" > "$existing"; echo body > "$body"; assert_fail 'embedded begin marker accepted' merge_managed_block_text "$existing" "$body" "$out"; printf 'prefix %s suffix\n' "$qbit_codex_end_marker" > "$existing"; assert_fail 'embedded end marker accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_reversed_rejected(){ existing=$tmp/reversed; body=$tmp/reversed_body; out=$tmp/reversed_out; printf '%s\nbody\n%s\n' "$qbit_codex_end_marker" "$qbit_codex_begin_marker" > "$existing"; echo new > "$body"; assert_fail 'reversed markers accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_duplicate_begin_rejected(){ existing=$tmp/dup_begin; body=$tmp/dup_begin_body; out=$tmp/dup_begin_out; printf '%s\none\n%s\ntwo\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; echo new > "$body"; assert_fail 'duplicate begin accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_duplicate_end_rejected(){ existing=$tmp/dup_end; body=$tmp/dup_end_body; out=$tmp/dup_end_out; printf '%s\none\n%s\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" "$qbit_codex_end_marker" > "$existing"; echo new > "$body"; assert_fail 'duplicate end accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_missing_begin_rejected(){ existing=$tmp/missing_begin; body=$tmp/missing_begin_body; out=$tmp/missing_begin_out; printf 'one\n%s\n' "$qbit_codex_end_marker" > "$existing"; echo new > "$body"; assert_fail 'missing begin accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_missing_end_rejected(){ existing=$tmp/missing_end; body=$tmp/missing_end_body; out=$tmp/missing_end_out; printf '%s\none\n' "$qbit_codex_begin_marker" > "$existing"; echo new > "$body"; assert_fail 'missing end accepted' merge_managed_block_text "$existing" "$body" "$out"; }
block_extract_exact(){ existing=$tmp/extract_existing; out=$tmp/extract_out; expected=$tmp/extract_expected; printf 'prefix\n%s\nbody\n%s\nsuffix\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; printf '%s\nbody\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$expected"; managed_block_extract_file "$existing" "$out" "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; assert_file_eq "$expected" "$out" 'extracted block changed'; }
block_hash_stable(){ body=$tmp/hash_body; block1=$tmp/hash_block1; block2=$tmp/hash_block2; echo body > "$body"; write_managed_block_text "$body" "$block1"; write_managed_block_text "$body" "$block2"; [ "$(file_sha256 "$block1")" = "$(file_sha256 "$block2")" ]; }
block_insertion_metadata(){ existing=$tmp/meta_existing; body=$tmp/meta_body; out=$tmp/meta_out; meta=$tmp/meta; printf prefix > "$existing"; echo body > "$body"; merge_managed_block_text "$existing" "$body" "$out" "$meta" "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; sep=$(sed -n '2p' "$meta"); assert_eq 2 "$sep" 'no-final-LF separator metadata failed'; printf 'prefix\n' > "$existing"; merge_managed_block_text "$existing" "$body" "$out" "$meta" "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; sep=$(sed -n '2p' "$meta"); assert_eq 1 "$sep" 'final-LF separator metadata failed'; : > "$existing"; merge_managed_block_text "$existing" "$body" "$out" "$meta" "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; sep=$(sed -n '2p' "$meta"); created=$(sed -n '1p' "$meta"); assert_eq 0 "$sep" 'empty-file separator metadata failed'; assert_eq false "$created" 'existing empty file marked created'; }
block_replace_preserves_exact_text(){ existing=$tmp/preserve_existing; body=$tmp/preserve_body; out=$tmp/preserve_out; expected=$tmp/preserve_expected; printf 'prefix trailing  \n%s\nold\n%s\n\n\nsuffix trailing  \n\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; echo new > "$body"; merge_managed_block_text "$existing" "$body" "$out"; printf 'prefix trailing  \n%s\nnew\n%s\n\n\nsuffix trailing  \n\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$expected"; assert_file_eq "$expected" "$out" 'replacement changed prefix/suffix bytes'; }
block_remove_preserves_exact_text(){ existing=$tmp/remove_existing; out=$tmp/remove_out; expected=$tmp/remove_expected; printf 'prefix trailing  \n\n%s\nbody\n%s\n\nsuffix trailing  \n\n\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker" > "$existing"; managed_block_remove_file "$existing" "$out" "$qbit_codex_begin_marker" "$qbit_codex_end_marker" 0 false; printf 'prefix trailing  \n\n\nsuffix trailing  \n\n\n' > "$expected"; assert_file_eq "$expected" "$out" 'removal changed prefix/suffix bytes'; }
block_remove_recorded_separator(){ existing=$tmp/remove_sep_existing; body=$tmp/remove_sep_body; merged=$tmp/remove_sep_merged; meta=$tmp/remove_sep_meta; out=$tmp/remove_sep_out; expected=$tmp/remove_sep_expected; printf prefix > "$existing"; echo body > "$body"; merge_managed_block_text "$existing" "$body" "$merged" "$meta" "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; sep=$(sed -n '2p' "$meta"); managed_block_remove_file "$merged" "$out" "$qbit_codex_begin_marker" "$qbit_codex_end_marker" "$sep" false; printf prefix > "$expected"; assert_file_eq "$expected" "$out" 'recorded separator was not removed exactly'; }
sha_deterministic(){ a=$(text_sha256 abc); b=$(text_sha256 abc); c=$(text_sha256 abcd); [ "$a" = "$b" ] && [ "$a" != "$c" ]; }
write_valid_state_fixture(){
  fixture=$1; hash=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; managed=$tmp/fixture-managed; installed=$tmp/fixture-installed; unsorted=$tmp/fixture-unsorted
  expected_managed_paths "$installer_root" generic "$managed"
  cat "$managed" > "$unsorted"; printf '%s\n' .gitignore .gitattributes AGENTS.md .qbit/toolkit/installed/codex-ai-tooling.json >> "$unsorted"; LC_ALL=C sort "$unsorted" > "$installed"
  {
    printf '{\n  "schemaVersion": "1.0",\n  "installerId": "installer.codex-ai-tooling",\n  "installerVersion": "1.0.0",\n  "toolkitSchemaVersion": "1.0",\n  "profile": "generic",\n  "projectSlug": "demo",\n  "projectDisplayName": "Demo",\n  "allowedOrigins": [\n    "http://localhost:3000"\n  ],\n  "dockerImageName": "demo-image",\n  "installedAtUtc": "2026-01-01T00:00:00Z",\n  "installedRelativePaths": [\n'
    count=$(wc -l < "$installed" | tr -d ' '); index=0; while IFS= read -r rel; do index=$((index+1)); printf '    "%s"' "$rel"; [ "$index" -lt "$count" ] && printf ','; printf '\n'; done < "$installed"
    printf '  ],\n  "managedFiles": {\n'; count=$(wc -l < "$managed" | tr -d ' '); index=0; while IFS= read -r rel; do index=$((index+1)); printf '    "%s": "%s"' "$rel" "$hash"; [ "$index" -lt "$count" ] && printf ','; printf '\n'; done < "$managed"
    printf '  },\n  "managedBlocks": {\n    ".gitattributes": {\n      "sha256": "%s",\n      "createdFile": true,\n      "insertedSeparatorLfCount": 0\n    },\n    ".gitignore": {\n      "sha256": "%s",\n      "createdFile": true,\n      "insertedSeparatorLfCount": 0\n    },\n    "AGENTS.md": {\n      "sha256": "%s",\n      "createdFile": true,\n      "insertedSeparatorLfCount": 0\n    }\n  },\n  "stateFile": ".qbit/toolkit/installed/codex-ai-tooling.json"\n}\n' "$hash" "$hash" "$hash"
  } > "$fixture"
}
strict_state_parser_accepts_canonical_ownership(){ fixture=$tmp/parser-valid.json; files=$tmp/parser-files; blocks=$tmp/parser-blocks; installed=$tmp/parser-installed; metadata=$tmp/parser-metadata; actual=$tmp/parser-actual; write_valid_state_fixture "$fixture"; parse_and_validate_state "$fixture" "$files" "$blocks" "$installed" "$metadata" "$installer_root"; awk -F '|' '{print $1}' "$files" > "$actual"; cmp -s "$tmp/fixture-managed" "$actual" && [ "$(wc -l < "$blocks" | tr -d ' ')" = 3 ]; }
strict_state_parser_rejects_malformed_ownership(){ fixture=$tmp/parser-invalid.json; files=$tmp/parser-invalid-files; blocks=$tmp/parser-invalid-blocks; installed=$tmp/parser-invalid-installed; metadata=$tmp/parser-invalid-metadata; write_valid_state_fixture "$fixture"; awk '!done && /"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/{sub(/"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"/,"\"invalid-hash\"");done=1} {print}' "$fixture" > "$fixture.tmp"; mv "$fixture.tmp" "$fixture"; assert_fail 'strict parser accepted malformed managed-file hash' parse_and_validate_state "$fixture" "$files" "$blocks" "$installed" "$metadata" "$installer_root"; }
json_escape_quotes_backslashes(){ actual=$(json_escape 'Qbit "CLI" \ Tooling'); assert_eq 'Qbit \"CLI\" \\ Tooling' "$actual" 'JSON escaping failed'; }
display_name_rejects_controls(){
  tab=$(printf '\t'); cr=$(printf '\r'); bs=$(printf '\b'); ff=$(printf '\f'); del=$(printf '\177'); c1=$(printf '\302\200')
  assert_fail 'display-name tab accepted' validate_project_display_name "bad${tab}name"
  assert_fail 'display-name embedded LF accepted' validate_project_display_name "bad
name"
  assert_fail 'display-name trailing LF accepted' validate_project_display_name "bad
"
  assert_fail 'display-name CR accepted' validate_project_display_name "bad${cr}name"
  assert_fail 'display-name backspace accepted' validate_project_display_name "bad${bs}name"
  assert_fail 'display-name form feed accepted' validate_project_display_name "bad${ff}name"
  assert_fail 'display-name DEL accepted' validate_project_display_name "bad${del}name"
  assert_fail 'display-name C1 control accepted' validate_project_display_name "bad${c1}name"
  validate_project_display_name 'Qbit "CLI" \ Tooling'
}
expected_manifest_is_deterministic(){ a=$tmp/manifest-a; b=$tmp/manifest-b; expected_managed_paths "$installer_root" typescript "$a"; expected_managed_paths "$installer_root" typescript "$b"; cmp -s "$a" "$b" && grep -F -x '.ai/tooling/language-servers/package.json' "$a" >/dev/null; }
strict_state_rejects_escaped_controls(){
  for kind in newline tab nul del c1; do
    fixture=$tmp/state-$kind.json; write_valid_state_fixture "$fixture"
    case "$kind" in newline) escaped='Qbit\\nCLI' ;; tab) escaped='Qbit\\u0009CLI' ;; nul) escaped='Qbit\\u0000CLI' ;; del) escaped='Qbit\\u007fCLI' ;; c1) escaped='Qbit\\u0080CLI' ;; esac
    awk -v escaped="$escaped" '!done && /^  "projectDisplayName":/{print "  \"projectDisplayName\": \"" escaped "\",";done=1;next}{print}' "$fixture" > "$fixture.tmp"
    mv "$fixture.tmp" "$fixture"
    assert_fail "$kind escaped-control state accepted" parse_and_validate_state "$fixture" "$tmp/$kind-files" "$tmp/$kind-blocks" "$tmp/$kind-installed" "$tmp/$kind-metadata" "$installer_root" || return 1
  done
}
strict_state_rejects_invalid_calendar_timestamps(){ for stamp in 2026-00-01T00:00:00Z 2026-13-01T00:00:00Z 2026-02-30T00:00:00Z 2026-01-01T24:00:00Z 2026-01-01T00:60:00Z 2026-01-01T00:00:60Z; do fixture=$tmp/stamp.json; write_valid_state_fixture "$fixture"; awk -v stamp="$stamp" '!done && /^  "installedAtUtc":/{print "  \"installedAtUtc\": \"" stamp "\",";done=1;next}{print}' "$fixture" > "$fixture.tmp"; mv "$fixture.tmp" "$fixture"; assert_fail "invalid timestamp accepted: $stamp" parse_and_validate_state "$fixture" "$tmp/stamp-files" "$tmp/stamp-blocks" "$tmp/stamp-installed" "$tmp/stamp-metadata" "$installer_root" || return 1; done; }
template_manifest_contract(){ root=$tmp/template-contract; mkdir -p "$root/templates/common" "$root/templates/profiles/generic"; printf common > "$root/templates/common/shared.txt"; printf profile > "$root/templates/profiles/generic/shared.txt"; build_template_source_manifest "$root" generic "$tmp/override-map"; [ "$(wc -l < "$tmp/override-map" | tr -d ' ')" = 1 ]; grep -F "$root/templates/profiles/generic/shared.txt" "$tmp/override-map" >/dev/null; rm -f "$root/templates/profiles/generic/shared.txt"; printf collision > "$root/templates/profiles/generic/Shared.txt"; assert_fail 'case-fold template collision accepted' build_template_source_manifest "$root" generic "$tmp/collision-map" || return 1; rm -f "$root/templates/profiles/generic/Shared.txt"; printf duplicate > "$root/templates/common/shared.txt.tpl"; assert_fail 'same-root duplicate destination accepted' build_template_source_manifest "$root" generic "$tmp/duplicate-map" || return 1; }
template_non_ascii_destination_rejected(){ root=$tmp/template-non-ascii; mkdir -p "$root/templates/common" "$root/templates/profiles/generic"; printf invalid > "$root/templates/common/café.txt"; assert_fail 'non-ASCII template destination accepted' build_template_source_manifest "$root" generic "$tmp/non-ascii-map"; }
scenario 'slug normalizes' slug_normalizes
scenario 'slug rejects empty' slug_rejects_empty
scenario 'slug max length' slug_max_length
scenario 'profile detects tsconfig' profile_tsconfig
scenario 'profile detects dependencies' profile_dependencies
scenario 'profile detects devDependencies' profile_devdependencies
scenario 'profile generic fallback' profile_generic
scenario 'profile detects root Cargo.toml as Rust' profile_rust
scenario 'explicit rust profile' profile_explicit_rust
scenario 'TypeScript precedence over Rust' profile_ts_precedence
scenario 'nested Cargo.toml remains generic' profile_nested_cargo_generic
scenario 'origin accepts http' origin_accepts_http
scenario 'origin accepts and normalizes IPv6 authority' origin_accepts_ipv6
scenario 'origin rejects scheme' origin_rejects_scheme
scenario 'origin rejects relative' origin_rejects_relative
scenario 'origin rejects credentials' origin_rejects_credentials
scenario 'origin rejects fragment' origin_rejects_fragment
scenario 'origin rejects wildcard' origin_rejects_wildcard
scenario 'path rejects traversal' path_rejects_traversal
scenario 'path accepts nested' path_accepts_nested
scenario 'path rejects non-ASCII managed destination' path_rejects_non_ascii
scenario 'template renders placeholder' render_replaces_placeholder
scenario 'managed block inserts' block_insert
scenario 'managed block replaces' block_replace
scenario 'managed block duplicate rejected' block_duplicate_rejected
scenario 'AGENTS block inserts' agents_block_insert
scenario 'AGENTS block replaces' agents_block_replace
scenario 'AGENTS duplicate marker rejected' agents_block_duplicate_rejected
scenario 'AGENTS unbalanced marker rejected' agents_block_unbalanced_rejected
scenario 'managed block exact-line marker recognition' block_exact_line_marker_rejected
scenario 'managed block reversed markers rejected' block_reversed_rejected
scenario 'managed block duplicate begin rejected' block_duplicate_begin_rejected
scenario 'managed block duplicate end rejected' block_duplicate_end_rejected
scenario 'managed block missing begin rejected' block_missing_begin_rejected
scenario 'managed block missing end rejected' block_missing_end_rejected
scenario 'managed block extracts exact block' block_extract_exact
scenario 'managed block hash stable' block_hash_stable
scenario 'managed block insertion metadata' block_insertion_metadata
scenario 'managed block replacement preserves bytes' block_replace_preserves_exact_text
scenario 'managed block removal preserves bytes' block_remove_preserves_exact_text
scenario 'managed block removal uses recorded separator' block_remove_recorded_separator
scenario 'sha deterministic' sha_deterministic
scenario 'strict state parser accepts canonical ownership metadata' strict_state_parser_accepts_canonical_ownership
scenario 'strict state parser rejects malformed ownership metadata' strict_state_parser_rejects_malformed_ownership
scenario 'JSON string escaping handles quotes and backslashes' json_escape_quotes_backslashes
scenario 'project display name rejects control characters' display_name_rejects_controls
scenario 'expected profile manifest is deterministic' expected_manifest_is_deterministic
scenario 'strict state parser rejects decoded escaped controls' strict_state_rejects_escaped_controls
scenario 'strict state parser rejects impossible UTC timestamps' strict_state_rejects_invalid_calendar_timestamps
scenario 'template override and collision contract is portable' template_manifest_contract
scenario 'template manifest rejects non-ASCII destination' template_non_ascii_destination_rejected
echo "RESULT passed=$pass failed=$fail skipped=$skip"
[ "$fail" -eq 0 ]
