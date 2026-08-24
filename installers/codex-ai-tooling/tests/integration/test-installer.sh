#!/usr/bin/env sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
installer_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
. "$installer_root/lib/installer.sh"
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-toolkit-sh)
cleanup(){ rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM
pass=0
fail=0
scenario(){ scenario_name=$1; shift; case "$scenario_name" in *"${QBIT_TOOLKIT_TEST_FILTER:-}"*) ;; *) [ -z "${QBIT_TOOLKIT_TEST_FILTER:-}" ] || return 0 ;; esac; if "$@"; then pass=$((pass+1)); echo "PASS $scenario_name"; else fail=$((fail+1)); echo "FAIL $scenario_name" >&2; fi; }
new_repo(){ mkdir -p "$tmp/$1"; git -C "$tmp/$1" init -q; printf '%s' "$tmp/$1"; }
snapshot(){ find "$1" -path "$1/.git" -prune -o -type f -print | sort | while IFS= read -r f; do if command -v sha256sum >/dev/null 2>&1; then h=$(sha256sum "$f" | awk '{print $1}'); else h=$(shasum -a 256 "$f" | awk '{print $1}'); fi; printf '%s:%s\n' "${f#"$1/"}" "$h"; done; }
uninstall_backup_count(){ if [ -d "$1/.qbit-toolkit/codex-ai-tooling/backups" ]; then find "$1/.qbit-toolkit/codex-ai-tooling/backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; else printf 0; fi; }
install_backup_count(){ if [ -d "$1/.qbit-toolkit/codex-ai-tooling/backups" ]; then find "$1/.qbit-toolkit/codex-ai-tooling/backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; else printf 0; fi; }
complete_snapshot(){ find "$1" -path "$1/.git" -prune -o -type d -print -o -type f -print | sort | while IFS= read -r path; do rel=${path#"$1"}; if [ -d "$path" ]; then printf 'd:%s\n' "$rel"; elif command -v sha256sum >/dev/null 2>&1; then printf 'f:%s:%s\n' "$rel" "$(sha256sum "$path" | awk '{print $1}')"; else printf 'f:%s:%s\n' "$rel" "$(shasum -a 256 "$path" | awk '{print $1}')"; fi; done; }
test_sha_file(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
json_document_valid(){ LC_ALL=C awk '
  function ws(){while(pos<=length(s) && substr(s,pos,1) ~ /[ \t\r\n]/) pos++}
  function string( c,e,h){if(substr(s,pos,1)!="\"")return 0;pos++;while(pos<=length(s)){c=substr(s,pos++,1);if(c=="\"")return 1;if(c ~ /[[:cntrl:]]/)return 0;if(c=="\\"){if(pos>length(s))return 0;e=substr(s,pos++,1);if(e=="u"){h=substr(s,pos,4);if(length(h)!=4||h~/[^0-9a-fA-F]/)return 0;pos+=4}else if(e!~/^["\\\/bfnrt]$/)return 0}}return 0}
  function number( rest,n){rest=substr(s,pos);if(!match(rest,/^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/))return 0;n=RLENGTH;pos+=n;return 1}
  function array(){pos++;ws();if(substr(s,pos,1)=="]"){pos++;return 1}while(1){if(!value())return 0;ws();if(substr(s,pos,1)=="]"){pos++;return 1}if(substr(s,pos,1)!=",")return 0;pos++;ws()}}
  function object(){pos++;ws();if(substr(s,pos,1)=="}"){pos++;return 1}while(1){if(!string())return 0;ws();if(substr(s,pos,1)!=":")return 0;pos++;if(!value())return 0;ws();if(substr(s,pos,1)=="}"){pos++;return 1}if(substr(s,pos,1)!=",")return 0;pos++;ws()}}
  function value( c){ws();c=substr(s,pos,1);if(c=="\"")return string();if(c=="{")return object();if(c=="[")return array();if(substr(s,pos,4)=="true"||substr(s,pos,4)=="null"){pos+=4;return 1}if(substr(s,pos,5)=="false"){pos+=5;return 1}return number()}
  {s=s $0 "\n"}
  END{pos=1;if(!value())exit 1;ws();if(pos<=length(s))exit 1}
' "$1"; }
transaction_count(){ if [ -d "$1/.qbit-toolkit/codex-ai-tooling/transactions" ]; then find "$1/.qbit-toolkit/codex-ai-tooling/transactions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; else printf 0; fi; }
convert_to_valid_legacy_agents_fixture(){
  fixture_repo=$1
  fixture_agents=$fixture_repo/AGENTS.md
  fixture_state=$fixture_repo/.qbit/toolkit/installed/codex-ai-tooling.json
  fixture_manifest=$fixture_repo/.qbit-toolkit/codex-ai-tooling/manifest.json
  fixture_current=$tmp/fixture-current-block
  fixture_legacy=$tmp/fixture-legacy-block
  managed_block_extract_file "$fixture_agents" "$fixture_current" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"
  fixture_current_hash=$(test_sha_file "$fixture_current")
  fixture_old_manifest_hash=$(test_sha_file "$fixture_manifest")
  sed -e 's/<!-- qbit-toolkit:codex-ai-tooling:start -->/<!-- >>> qbit-toolkit:codex-ai-tooling -->/' -e 's/<!-- qbit-toolkit:codex-ai-tooling:end -->/<!-- <<< qbit-toolkit:codex-ai-tooling -->/' "$fixture_agents" > "$fixture_agents.tmp"
  mv "$fixture_agents.tmp" "$fixture_agents"
  managed_block_extract_file "$fixture_agents" "$fixture_legacy" '<!-- >>> qbit-toolkit:codex-ai-tooling -->' '<!-- <<< qbit-toolkit:codex-ai-tooling -->'
  fixture_legacy_hash=$(test_sha_file "$fixture_legacy")
  sed "s/$fixture_current_hash/$fixture_legacy_hash/g" "$fixture_manifest" > "$fixture_manifest.tmp"; mv "$fixture_manifest.tmp" "$fixture_manifest"
  sed "s/$fixture_current_hash/$fixture_legacy_hash/g" "$fixture_state" > "$fixture_state.tmp"; mv "$fixture_state.tmp" "$fixture_state"
  fixture_digest=$tmp/fixture-digest
  awk '
    /"installed_entries"[[:space:]]*:/ { section=1; next }
    /"managed_blocks"[[:space:]]*:/ { section=2; next }
    /"generated_state_entries"[[:space:]]*:/ { section=0 }
    section==1 && /"relative_path"/ { line=$0; sub(/^.*"relative_path"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); path=line; line=$0; sub(/^.*"expected_sha256"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); print path "\t" line }
    section==2 && /"relative_path"/ { line=$0; sub(/^.*"relative_path"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); path=line; line=$0; sub(/^.*"sha256"[[:space:]]*:[[:space:]]*"/,"",line); sub(/".*$/,"",line); print path "\t" line }
  ' "$fixture_manifest" > "$fixture_digest"
  fixture_payload_hash=$(test_sha_file "$fixture_digest")
  fixture_old_payload_hash=$(sed -n 's/^  "payload_manifest_sha256": "\([0-9a-f][0-9a-f]*\)",$/\1/p' "$fixture_manifest")
  sed "s/$fixture_old_payload_hash/$fixture_payload_hash/" "$fixture_manifest" > "$fixture_manifest.tmp"; mv "$fixture_manifest.tmp" "$fixture_manifest"
  fixture_new_manifest_hash=$(test_sha_file "$fixture_manifest")
  sed "s/$fixture_old_manifest_hash/$fixture_new_manifest_hash/" "$fixture_state" > "$fixture_state.tmp"; mv "$fixture_state.tmp" "$fixture_state"
  bash "$installer_root/install.sh" --operation plan --target "$fixture_repo" --profile generic --format json --non-interactive >/dev/null
}
assert_legacy_replace_failure(){
  failure_repo=$1; failure_code=$2; failure_name=$3
  failure_before=$tmp/$failure_name-before; failure_after=$tmp/$failure_name-after; failure_json=$tmp/$failure_name.json
  complete_snapshot "$failure_repo" > "$failure_before"
  failure_backups=$(install_backup_count "$failure_repo"); failure_transactions=$(transaction_count "$failure_repo")
  if bash "$installer_root/install.sh" --operation plan --target "$failure_repo" --profile generic --owned-modified replace --format json --non-interactive > "$failure_json" 2>/dev/null; then return 1; else failure_actual=$?; fi
  [ "$failure_actual" -eq "$failure_code" ] && grep -Fq "\"exit_code\":$failure_code" "$failure_json"
  complete_snapshot "$failure_repo" > "$failure_after"; cmp -s "$failure_before" "$failure_after"
  [ "$(install_backup_count "$failure_repo")" = "$failure_backups" ] && [ "$(transaction_count "$failure_repo")" = "$failure_transactions" ]
  [ ! -e "$failure_repo/.qbit-toolkit/codex-ai-tooling/lock.json" ]
}
fresh_generic(){ repo=$(new_repo fresh-generic); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
fresh_rust(){ repo=$(new_repo fresh-rust); echo '[package]' > "$repo/Cargo.toml"; bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; grep -q '"profile": "rust"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; grep -Eq '^[[:space:]]*-[[:space:]]*powershell[[:space:]]*$' "$repo/.serena/project.yml"; grep -Eq '^[[:space:]]*-[[:space:]]*bash[[:space:]]*$' "$repo/.serena/project.yml"; grep -Eq '^[[:space:]]*-[[:space:]]*python[[:space:]]*$' "$repo/.serena/project.yml"; [ -f "$repo/.ai/tooling/language-servers/package.json" ]; }
auto_rust(){ repo=$(new_repo auto-rust); echo '[package]' > "$repo/Cargo.toml"; bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null; grep -q '"profile": "rust"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; }
typescript_wins(){ repo=$(new_repo ts-rust); echo '[package]' > "$repo/Cargo.toml"; echo '{}' > "$repo/tsconfig.json"; bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null; grep -q '"profile": "typescript"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; }
dryrun(){ repo=$(new_repo dryrun); before=$(find "$repo" -path "$repo/.git" -prune -o -type f -print | sort); bash "$installer_root/install.sh" --target "$repo" --profile generic --dry-run --skip-bootstrap --skip-doctor >/dev/null; after=$(find "$repo" -path "$repo/.git" -prune -o -type f -print | sort); [ "$before" = "$after" ]; }
conflict(){ repo=$(new_repo conflict); mkdir -p "$repo/.codex"; echo user > "$repo/.codex/config.toml"; ! bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null 2>&1; }
agents_preserved(){ repo=$(new_repo agents-preserved); expected=$tmp/agents-preserved-expected; printf '# Repository Guidelines\n\n## Architecture\nProject-owned architecture stays here.\n' > "$expected"; cp "$expected" "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; grep -q 'Project-owned architecture stays here' "$repo/AGENTS.md"; [ "$(grep -F '<!-- qbit-toolkit:codex-ai-tooling:start -->' "$repo/AGENTS.md" | wc -l | tr -d ' ')" = 1 ]; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; cmp -s "$expected" "$repo/AGENTS.md"; ! grep -q 'qbit-toolkit:codex-ai-tooling' "$repo/AGENTS.md"; }
agents_roundtrip_variants(){ for name in no-final one-final blanks empty; do repo=$(new_repo "agents-$name"); expected=$tmp/"expected-$name"; case "$name" in no-final) printf 'Repo trailing spaces  ' > "$expected" ;; one-final) printf 'Repo trailing spaces  \n' > "$expected" ;; blanks) printf 'Repo trailing spaces  \n\n\n' > "$expected" ;; empty) : > "$expected" ;; esac; cp "$expected" "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; cmp -s "$expected" "$repo/AGENTS.md" || return 1; done; repo=$(new_repo agents-absent); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ ! -e "$repo/AGENTS.md" ]; }
agents_reversed_snapshot(){ repo=$(new_repo agents-reversed); printf '<!-- qbit-toolkit:codex-ai-tooling:end -->\nbody\n<!-- qbit-toolkit:codex-ai-tooling:start -->\n' > "$repo/AGENTS.md"; before=$tmp/reversed-before; after=$tmp/reversed-after; snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null 2>&1; snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
agents_malformed_uninstall_snapshot(){ repo=$(new_repo agents-malformed-uninstall); printf '# Repo\n' > "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; sed "s/<!-- qbit-toolkit:codex-ai-tooling:end -->/<!-- qbit-toolkit:codex-ai-tooling:start -->/" "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; ! bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null 2>&1; [ -f "$repo/AGENTS.md" ]; [ -f "$repo/.qbit/toolkit/installed/codex-ai-tooling.json" ]; grep -Fq '<!-- qbit-toolkit:codex-ai-tooling:start -->' "$repo/AGENTS.md"; }
verify_block_modified(){ repo=$(new_repo verify-block-modified); printf '# Repo\n' > "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; sed 's/Qbit AI tooling/Modified AI tooling/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; ! bash "$installer_root/verify.sh" --target "$repo" >/dev/null 2>&1; }
verify_outside_block_edit(){ repo=$(new_repo verify-outside-edit); printf '# Repo\n' > "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; sed '1s/# Repo/# Repo updated outside block/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
managed_block_default_conflict(){
  repo=$(new_repo managed-block-default)
  printf 'prefix trailing  \n' > "$repo/AGENTS.md"
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  printf 'suffix trailing  ' >> "$repo/AGENTS.md"
  sed 's/Qbit AI tooling/Modified owned block/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  before=$tmp/managed-block-default-before; after=$tmp/managed-block-default-after
  complete_snapshot "$repo" > "$before"
  backups=$(install_backup_count "$repo")
  transactions=$(find "$repo/.qbit-toolkit/codex-ai-tooling/transactions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  if bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --format json --non-interactive > "$tmp/managed-block-default.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]
  grep -Fq '"exit_code":4' "$tmp/managed-block-default.json"
  grep -Fq 'AGENTS.md' "$tmp/managed-block-default.json"
  if bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --format text --non-interactive > "$tmp/managed-block-default.txt" 2>&1; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; grep -Fq 'AGENTS.md' "$tmp/managed-block-default.txt"
  complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
  [ "$(install_backup_count "$repo")" = "$backups" ]
  [ "$(find "$repo/.qbit-toolkit/codex-ai-tooling/transactions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "$transactions" ]
  [ ! -e "$repo/.qbit-toolkit/codex-ai-tooling/lock.json" ]
}
managed_block_replace(){
  repo=$(new_repo managed-block-replace)
  printf 'prefix trailing  \n' > "$repo/AGENTS.md"
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  printf 'suffix trailing  ' >> "$repo/AGENTS.md"
  sed 's/Qbit AI tooling/Modified owned block/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  cp "$repo/AGENTS.md" "$tmp/managed-block-replace-prior"
  start=$(managed_block_begin_offset "$repo/AGENTS.md" "$qbit_codex_agents_begin_marker")
  finish=$(managed_block_end_offset "$repo/AGENTS.md" "$qbit_codex_agents_end_marker")
  dd if="$repo/AGENTS.md" bs=1 count="$start" 2>/dev/null > "$tmp/managed-block-prefix"
  size=$(wc -c < "$repo/AGENTS.md" | tr -d ' ')
  dd if="$repo/AGENTS.md" bs=1 skip="$finish" count=$((size-finish)) 2>/dev/null > "$tmp/managed-block-suffix"
  backups=$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')
  bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --owned-modified replace --non-interactive >/dev/null
  [ "$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')" -eq $((backups+1)) ]
  find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' -exec sh -c 'cmp -s "$1" "$2"' sh {} "$tmp/managed-block-replace-prior" \; -print | grep . >/dev/null
  new_start=$(managed_block_begin_offset "$repo/AGENTS.md" "$qbit_codex_agents_begin_marker")
  new_finish=$(managed_block_end_offset "$repo/AGENTS.md" "$qbit_codex_agents_end_marker")
  dd if="$repo/AGENTS.md" bs=1 count="$new_start" 2>/dev/null > "$tmp/managed-block-prefix-after"
  new_size=$(wc -c < "$repo/AGENTS.md" | tr -d ' ')
  dd if="$repo/AGENTS.md" bs=1 skip="$new_finish" count=$((new_size-new_finish)) 2>/dev/null > "$tmp/managed-block-suffix-after"
  cmp -s "$tmp/managed-block-prefix" "$tmp/managed-block-prefix-after"
  cmp -s "$tmp/managed-block-suffix" "$tmp/managed-block-suffix-after"
  grep -Fq 'Qbit AI tooling' "$repo/AGENTS.md"
  ! grep -Fq 'Modified owned block' "$repo/AGENTS.md"
  bash "$installer_root/verify.sh" --target "$repo" >/dev/null
}
plan_replace_owned_content(){
  repo=$(new_repo plan-replace-owned)
  printf 'prefix\n' > "$repo/AGENTS.md"
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  sed 's/Qbit AI tooling/Modified owned block/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  printf '\nmodified owned file\n' >> "$repo/.env.ai.example"
  before=$tmp/plan-replace-before; after=$tmp/plan-replace-after
  complete_snapshot "$repo" > "$before"
  backups=$(install_backup_count "$repo")
  transactions=$(find "$repo/.qbit-toolkit/codex-ai-tooling/transactions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/plan-replace.json"
  grep -Fq '"exit_code":0' "$tmp/plan-replace.json"
  grep -Fq '"planned_actions":["update .env.ai.example","update .qbit-toolkit/codex-ai-tooling/manifest.json","update .qbit/toolkit/installed/codex-ai-tooling.json","update AGENTS.md"]' "$tmp/plan-replace.json"
  complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
  [ "$(install_backup_count "$repo")" = "$backups" ]
  [ "$(find "$repo/.qbit-toolkit/codex-ai-tooling/transactions" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "$transactions" ]
  [ ! -e "$repo/.qbit-toolkit/codex-ai-tooling/lock.json" ]
}
replace_rejects_unowned_and_malformed_markers(){
  repo=$(new_repo replace-unowned-marker)
  printf '<!-- qbit-toolkit:codex-ai-tooling:start -->\nunowned\n<!-- qbit-toolkit:codex-ai-tooling:end -->\n' > "$repo/AGENTS.md"
  before=$tmp/unowned-marker-before; after=$tmp/unowned-marker-after; complete_snapshot "$repo" > "$before"
  if bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/unowned-marker.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; grep -Fq 'AGENTS.md' "$tmp/unowned-marker.json"; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
  repo=$(new_repo replace-malformed-marker)
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  sed 's/<!-- qbit-toolkit:codex-ai-tooling:end -->/<!-- qbit-toolkit:codex-ai-tooling:start -->/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  before=$tmp/malformed-marker-before; after=$tmp/malformed-marker-after; complete_snapshot "$repo" > "$before"
  if bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/malformed-marker.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
  repo=$(new_repo replace-missing-state)
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  rm -f "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"
  before=$tmp/missing-state-before; after=$tmp/missing-state-after; complete_snapshot "$repo" > "$before"
  if bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/missing-state.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
  repo=$(new_repo replace-corrupt-state)
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  printf 'not-json\n' >> "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"
  before=$tmp/corrupt-state-before; after=$tmp/corrupt-state-after; complete_snapshot "$repo" > "$before"
  if bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/corrupt-state.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 5 ]; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"
}
legacy_unchanged_owned_migration(){
  for policy in fail replace; do
    repo=$(new_repo "legacy-unchanged-$policy")
    prefix=$tmp/legacy-prefix-$policy; suffix=$tmp/legacy-suffix-$policy
    printf 'prefix trailing  \n' > "$prefix"; printf 'suffix trailing  ' > "$suffix"; cp "$prefix" "$repo/AGENTS.md"
    bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
    cat "$suffix" >> "$repo/AGENTS.md"
    convert_to_valid_legacy_agents_fixture "$repo"
    prior=$tmp/legacy-unchanged-prior-$policy; cp "$repo/AGENTS.md" "$prior"
    backups=$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')
    index_before=$(git -C "$repo" ls-files --stage)
    bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --owned-modified "$policy" --non-interactive >/dev/null
    [ "$(grep -F -x "$qbit_codex_agents_begin_marker" "$repo/AGENTS.md" | wc -l | tr -d ' ')" = 1 ]
    [ "$(grep -F -x "$qbit_codex_agents_end_marker" "$repo/AGENTS.md" | wc -l | tr -d ' ')" = 1 ]
    ! grep -Fq '<!-- >>> qbit-toolkit:codex-ai-tooling -->' "$repo/AGENTS.md"; ! grep -Fq '<!-- <<< qbit-toolkit:codex-ai-tooling -->' "$repo/AGENTS.md"
    start=$(managed_block_begin_offset "$repo/AGENTS.md" "$qbit_codex_agents_begin_marker"); finish=$(managed_block_end_offset "$repo/AGENTS.md" "$qbit_codex_agents_end_marker"); size=$(wc -c < "$repo/AGENTS.md" | tr -d ' ')
    dd if="$repo/AGENTS.md" bs=1 count="$start" 2>/dev/null > "$tmp/legacy-prefix-after"; dd if="$repo/AGENTS.md" bs=1 skip="$finish" count=$((size-finish)) 2>/dev/null > "$tmp/legacy-suffix-after"
    cmp -s "$prefix" "$tmp/legacy-prefix-after"; cmp -s "$suffix" "$tmp/legacy-suffix-after"
    [ "$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')" -eq $((backups+1)) ]
    find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' -exec sh -c 'cmp -s "$1" "$2"' sh {} "$prior" \; -print | grep . >/dev/null
    managed_block_extract_file "$repo/AGENTS.md" "$tmp/legacy-current-block" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"
    current_hash=$(test_sha_file "$tmp/legacy-current-block"); grep -Fq "\"sha256\": \"$current_hash\"" "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"
    [ "$(git -C "$repo" ls-files --stage)" = "$index_before" ]
    bash "$installer_root/verify.sh" --target "$repo" >/dev/null
  done
}
legacy_modified_default_conflict(){
  repo=$(new_repo legacy-modified-default); printf 'prefix\n' > "$repo/AGENTS.md"
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  convert_to_valid_legacy_agents_fixture "$repo"
  sed 's/Qbit AI tooling/Modified legacy body/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  before=$tmp/legacy-default-before; after=$tmp/legacy-default-after; complete_snapshot "$repo" > "$before"; backups=$(install_backup_count "$repo"); transactions=$(transaction_count "$repo")
  if bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --format json --non-interactive > "$tmp/legacy-default.json" 2>/dev/null; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; grep -Fq '"exit_code":4' "$tmp/legacy-default.json"; grep -Fq 'AGENTS.md' "$tmp/legacy-default.json"
  if bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --format text --non-interactive > "$tmp/legacy-default.txt" 2>&1; then return 1; else code=$?; fi
  [ "$code" -eq 4 ]; grep -Fq 'AGENTS.md' "$tmp/legacy-default.txt"
  complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = "$backups" ]; [ "$(transaction_count "$repo")" = "$transactions" ]; [ ! -e "$repo/.qbit-toolkit/codex-ai-tooling/lock.json" ]
}
legacy_modified_replace_migration(){
  repo=$(new_repo legacy-modified-replace); prefix=$tmp/legacy-replace-prefix; suffix=$tmp/legacy-replace-suffix
  printf 'prefix trailing  \n' > "$prefix"; printf 'suffix trailing  ' > "$suffix"; cp "$prefix" "$repo/AGENTS.md"
  bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null; cat "$suffix" >> "$repo/AGENTS.md"
  convert_to_valid_legacy_agents_fixture "$repo"; sed 's/Qbit AI tooling/Modified legacy body/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  prior=$tmp/legacy-replace-prior; cp "$repo/AGENTS.md" "$prior"; index_before=$(git -C "$repo" ls-files --stage)
  backups=$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')
  bash "$installer_root/install.sh" --operation update --target "$repo" --profile generic --owned-modified replace --non-interactive >/dev/null
  [ "$(find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | wc -l | tr -d ' ')" -eq $((backups+1)) ]
  find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' -exec sh -c 'cmp -s "$1" "$2"' sh {} "$prior" \; -print | grep . >/dev/null
  start=$(managed_block_begin_offset "$repo/AGENTS.md" "$qbit_codex_agents_begin_marker"); finish=$(managed_block_end_offset "$repo/AGENTS.md" "$qbit_codex_agents_end_marker"); size=$(wc -c < "$repo/AGENTS.md" | tr -d ' ')
  dd if="$repo/AGENTS.md" bs=1 count="$start" 2>/dev/null > "$tmp/legacy-replace-prefix-after"; dd if="$repo/AGENTS.md" bs=1 skip="$finish" count=$((size-finish)) 2>/dev/null > "$tmp/legacy-replace-suffix-after"
  cmp -s "$prefix" "$tmp/legacy-replace-prefix-after"; cmp -s "$suffix" "$tmp/legacy-replace-suffix-after"
  grep -Fq "$qbit_codex_agents_begin_marker" "$repo/AGENTS.md"; ! grep -Fq '<!-- >>> qbit-toolkit:codex-ai-tooling -->' "$repo/AGENTS.md"; ! grep -Fq 'Modified legacy body' "$repo/AGENTS.md"; grep -Fq 'Qbit AI tooling' "$repo/AGENTS.md"
  managed_block_extract_file "$repo/AGENTS.md" "$tmp/legacy-replace-current" "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; current_hash=$(test_sha_file "$tmp/legacy-replace-current"); grep -Fq "\"sha256\": \"$current_hash\"" "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"
  [ "$(git -C "$repo" ls-files --stage)" = "$index_before" ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null
}
legacy_modified_plan_replace(){
  repo=$(new_repo legacy-plan-replace); printf 'prefix\n' > "$repo/AGENTS.md"; bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null
  convert_to_valid_legacy_agents_fixture "$repo"; sed 's/Qbit AI tooling/Modified legacy body/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  before=$tmp/legacy-plan-before; after=$tmp/legacy-plan-after; complete_snapshot "$repo" > "$before"; backups=$(install_backup_count "$repo"); transactions=$(transaction_count "$repo")
  bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --owned-modified replace --format json --non-interactive > "$tmp/legacy-plan.json"
  grep -Fq '"exit_code":0' "$tmp/legacy-plan.json"; grep -Fq '"success":true' "$tmp/legacy-plan.json"
  grep -Fq '"planned_actions":["update .qbit-toolkit/codex-ai-tooling/manifest.json","update .qbit/toolkit/installed/codex-ai-tooling.json","update AGENTS.md"]' "$tmp/legacy-plan.json"
  complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = "$backups" ]; [ "$(transaction_count "$repo")" = "$transactions" ]; [ ! -e "$repo/.qbit-toolkit/codex-ai-tooling/lock.json" ]
}
legacy_negative_replace_cases(){
  legacy_begin='<!-- >>> qbit-toolkit:codex-ai-tooling -->'; legacy_end='<!-- <<< qbit-toolkit:codex-ai-tooling -->'
  repo=$(new_repo legacy-unowned); printf '%s\nunowned\n%s\n' "$legacy_begin" "$legacy_end" > "$repo/AGENTS.md"; assert_legacy_replace_failure "$repo" 4 legacy-unowned
  repo=$(new_repo legacy-missing-end); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; sed "\|$legacy_end|d" "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; assert_legacy_replace_failure "$repo" 4 legacy-missing-end
  repo=$(new_repo legacy-reversed); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; sed -e "s|$legacy_begin|LEGACY-TEMP|" -e "s|$legacy_end|$legacy_begin|" -e "s|LEGACY-TEMP|$legacy_end|" "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; assert_legacy_replace_failure "$repo" 4 legacy-reversed
  repo=$(new_repo legacy-duplicate); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; managed_block_extract_file "$repo/AGENTS.md" "$tmp/legacy-duplicate-block" "$legacy_begin" "$legacy_end"; cat "$tmp/legacy-duplicate-block" >> "$repo/AGENTS.md"; assert_legacy_replace_failure "$repo" 4 legacy-duplicate
  repo=$(new_repo legacy-simultaneous); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; printf '%s\ncurrent\n%s\n' "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker" >> "$repo/AGENTS.md"; assert_legacy_replace_failure "$repo" 4 legacy-simultaneous
  repo=$(new_repo legacy-missing-state); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; rm -f "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; assert_legacy_replace_failure "$repo" 4 legacy-missing-state
  repo=$(new_repo legacy-corrupt-state); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; convert_to_valid_legacy_agents_fixture "$repo"; printf 'not-json\n' >> "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; assert_legacy_replace_failure "$repo" 5 legacy-corrupt-state
}
uninstall_block_modified_force(){ repo=$(new_repo uninstall-block-modified); printf '# Repo\n' > "$repo/AGENTS.md"; bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; sed 's/Qbit AI tooling/Modified AI tooling/' "$repo/AGENTS.md" > "$repo/AGENTS.tmp"; mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"; ! bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null 2>&1; bash "$installer_root/uninstall.sh" --target "$repo" --owned-modified replace >/dev/null; ! grep -q 'qbit-toolkit:codex-ai-tooling' "$repo/AGENTS.md"; find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/AGENTS.md' | grep . >/dev/null; }
project_owned_hidden_survives(){ repo=$(new_repo hidden-survives); mkdir -p "$repo/.ai" "$repo/.codex" "$repo/.serena" "$repo/docs/ai-tooling" "$repo/.qbit"; echo keep > "$repo/.ai/custom-project-file.txt"; echo keep > "$repo/.codex/custom-project-file.toml"; echo keep > "$repo/.serena/custom-project-file.yml"; echo keep > "$repo/docs/ai-tooling/custom-project-file.md"; echo keep > "$repo/.qbit/custom-project-file.txt"; bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ -f "$repo/.ai/custom-project-file.txt" ] && [ -f "$repo/.codex/custom-project-file.toml" ] && [ -f "$repo/.serena/custom-project-file.yml" ] && [ -f "$repo/docs/ai-tooling/custom-project-file.md" ] && [ -f "$repo/.qbit/custom-project-file.txt" ]; }
modified_file_verify_uninstall_force(){ repo=$(new_repo modified-file); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; echo modified >> "$repo/.env.ai.example"; ! bash "$installer_root/verify.sh" --target "$repo" >/dev/null 2>&1; ! bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null 2>&1; bash "$installer_root/uninstall.sh" --target "$repo" --owned-modified replace >/dev/null; find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path '*/.env.ai.example' | grep . >/dev/null; }
missing_managed_file_preflight(){ repo=$(new_repo missing-managed-file); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; rel=$(awk '/"managedFiles"[[:space:]]*:[[:space:]]*\{/ { active=1; next } active && /^[[:space:]]*\}/ { exit } active && /"[^"]+"[[:space:]]*:[[:space:]]*"[0-9a-f]+"/ { line=$0; sub(/^[[:space:]]*"/, "", line); sub(/".*/, "", line); print line; exit }' "$state"); [ -n "$rel" ]; rm -f "$repo/$rel"; [ -f "$state" ]; before=$tmp/missing-managed-file-before; after=$tmp/missing-managed-file-after; snapshot "$repo" > "$before"; backups=$(uninstall_backup_count "$repo"); ! bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null 2>&1; snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(uninstall_backup_count "$repo")" = "$backups" ]; ! bash "$installer_root/uninstall.sh" --target "$repo" --owned-modified replace >/dev/null 2>&1; snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(uninstall_backup_count "$repo")" = "$backups" ]; [ -f "$state" ]; }
missing_managed_block_file_preflight(){ repo=$(new_repo missing-managed-block-file); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; rel=$(awk '/"managedBlocks"[[:space:]]*:[[:space:]]*\{/ { active=1; next } active && /^[[:space:]]*"AGENTS.md"[[:space:]]*:[[:space:]]*\{/ { print "AGENTS.md"; exit }' "$state"); [ -n "$rel" ]; rm -f "$repo/$rel"; [ -f "$state" ]; before=$tmp/missing-managed-block-before; after=$tmp/missing-managed-block-after; snapshot "$repo" > "$before"; backups=$(uninstall_backup_count "$repo"); ! bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null 2>&1; snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(uninstall_backup_count "$repo")" = "$backups" ]; ! bash "$installer_root/uninstall.sh" --target "$repo" --owned-modified replace >/dev/null 2>&1; snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(uninstall_backup_count "$repo")" = "$backups" ]; [ -f "$state" ]; }
corrupt_invalid_managed_file_hash(){ awk 'BEGIN{inside=0;done=0} $0=="  \"managedFiles\": {"{inside=1} inside && !done && /^    "[^"]+": "[^"]+"/{sub(/"[^"]+"[,]?$/, "\"invalid-hash\","); done=1} {print}' "$1" > "$2"; }
corrupt_missing_managed_files_section(){ awk '$0=="  \"managedFiles\": {"{skip=1;next} skip && $0=="  },"{skip=0;next} !skip{print}' "$1" > "$2"; }
corrupt_incomplete_managed_block_record(){ awk '!done && /"insertedSeparatorLfCount"/{done=1;next} {print}' "$1" > "$2"; }
corrupt_invalid_managed_block_hash(){ awk '$0=="  \"managedBlocks\": {"{inside=1} inside && !done && /"sha256": /{sub(/"sha256": "[^"]+"/, "\"sha256\": \"invalid-hash\""); done=1} {print}' "$1" > "$2"; }
corrupt_missing_required_block_record(){ awk '$0=="    \".gitattributes\": {"{skip=1;next} skip && $0 ~ /^    }[,]?$/{skip=0;next} !skip{print}' "$1" > "$2"; }
corrupt_duplicate_managed_file_path(){ awk '$0=="  \"managedFiles\": {"{inside=1} inside && !done && /^    "[^"]+": "[^"]+",$/{print; print; done=1; next} {print}' "$1" > "$2"; }
corrupt_duplicate_managed_block_path(){ awk '$0=="    \".gitattributes\": {"{dup=1;buf=$0 ORS;print;next} dup{buf=buf $0 ORS;print;if($0 ~ /^    }[,]?$/){printf "%s",buf;dup=0}next} {print}' "$1" > "$2"; }
corrupt_truncated_ownership_state(){ awk '$0=="  \"managedFiles\": {"{inside=1} {print} inside && /^    "[^"]+": "[^"]+"/{exit}' "$1" > "$2"; }
corrupt_leading_garbage(){ { printf 'not-json\n'; cat "$1"; } > "$2"; }
corrupt_trailing_garbage(){ { cat "$1"; printf 'not-json\n'; } > "$2"; }
corrupt_duplicate_top_level_key(){ awk '{print} !done && /^  "installerId":/{print;done=1}' "$1" > "$2"; }
corrupt_missing_top_level_field(){ awk '!/^  "dockerImageName":/' "$1" > "$2"; }
corrupt_malformed_json_escape(){ awk '!done && /^  "projectDisplayName":/{print "  \"projectDisplayName\": \"bad\\q\",";done=1;next} {print}' "$1" > "$2"; }
corrupt_duplicate_installed_path(){ awk '$0=="  \"installedRelativePaths\": ["{inside=1} inside && !done && /^    "[^"]+",$/{print;print;done=1;next} {print}' "$1" > "$2"; }
corrupt_missing_state_installed_path(){ awk '!/^    "\.qbit\/toolkit\/installed\/codex-ai-tooling.json"[,]?$/' "$1" > "$2"; }
corrupt_unexpected_installed_path(){ awk '{print} $0=="  \"installedRelativePaths\": [" && !done{print "    \"unexpected-owned.txt\",";done=1}' "$1" > "$2"; }
corrupt_managed_removed_only(){ awk '$0=="  \"managedFiles\": {"{inside=1;print;next} inside && !done && /^    "[^"]+": "[0-9a-f]+",$/{done=1;next} {print}' "$1" > "$2"; }
corrupt_managed_removed_both(){ target=$(awk '$0=="  \"managedFiles\": {"{inside=1;next} inside && /^    "[^"]+": "[0-9a-f]+",$/{line=$0;sub(/^    "/,"",line);sub(/".*/,"",line);print line;exit}' "$1"); [ -n "$target" ]; awk -v target="$target" 'index($0,"\"" target "\"")==0{print}' "$1" > "$2"; }
corrupt_managed_outside_expected(){ awk '
  {print}
  $0=="  \"installedRelativePaths\": ["{print "    \"unexpected-owned.txt\","}
  $0=="  \"managedFiles\": {"{print "    \"unexpected-owned.txt\": \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\","}
' "$1" > "$2"; }
corrupt_escaped_display_newline(){ awk '!done && /^  "projectDisplayName":/{print "  \"projectDisplayName\": \"Qbit\\nCLI\",";done=1;next}{print}' "$1" > "$2"; }
corrupt_escaped_display_tab(){ awk '!done && /^  "projectDisplayName":/{print "  \"projectDisplayName\": \"Qbit\\u0009CLI\",";done=1;next}{print}' "$1" > "$2"; }
corrupt_duplicate_origin(){ awk '$0=="  \"allowedOrigins\": ["{inside=1;print;next} inside && !done && /^    "[^"]+",$/{print;print;done=1;next}{print}' "$1" > "$2"; }
corrupt_duplicate_ipv6_origin(){ awk '$0=="  \"allowedOrigins\": ["{print;print "    \"http://[::1]:3000\",";print "    \"http://[::1]:3000\",";print "    \"http://localhost:3000\"";inside=1;next} inside && $0=="  ],"{inside=0;print;next} !inside{print}' "$1" > "$2"; }
corrupt_invalid_calendar_timestamp(){ awk '!done && /^  "installedAtUtc":/{print "  \"installedAtUtc\": \"2026-02-30T00:00:00Z\",";done=1;next}{print}' "$1" > "$2"; }
corrupt_wrong_case_managed(){ awk '$0=="  \"managedFiles\": {"{inside=1} inside && !done && /^    "[^"]+":/{line=$0; key=line; sub(/^    "/,"",key); sub(/".*/,"",key); rest=line; sub(/^    "[^"]+": /,"",rest); print "    \"" toupper(key) "\": " rest;done=1;next}{print}' "$1" > "$2"; }
corrupt_wrong_case_installed(){ awk '$0=="  \"installedRelativePaths\": ["{inside=1} inside{gsub(/"\.env\.ai\.example"/,"\".ENV.AI.EXAMPLE\"")} {print} inside && $0=="  ],"{inside=0}' "$1" > "$2"; }
corrupt_wrong_case_block(){ awk '{gsub(/"\.gitignore": \{/,"\".GitIgnore\": {");print}' "$1" > "$2"; }
corrupt_non_ascii_managed(){ awk '$0=="  \"managedFiles\": {"{inside=1} inside && !done && /^    "[^"]+":/{line=$0;rest=line;sub(/^    "[^"]+": /,"",rest);print "    \"owned/café.txt\": " rest;done=1;next}{print}' "$1" > "$2"; }
corrupt_non_ascii_installed(){ awk '$0=="  \"installedRelativePaths\": ["{inside=1} inside{gsub(/"\.env\.ai\.example"/,"\"owned/café.txt\"")} {print} inside && $0=="  ],"{inside=0}' "$1" > "$2"; }
corrupt_non_ascii_block(){ awk '{gsub(/"\.gitignore": \{/,"\"café.block\": {");print}' "$1" > "$2"; }
corrupt_state_preflight(){ case_name=$1; mutator=$2; repo=$(new_repo "state-$case_name"); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; "$mutator" "$state" "$state.tmp"; mv "$state.tmp" "$state"; before=$tmp/"$case_name-before"; after=$tmp/"$case_name-after"; log=$tmp/"$case_name.log"; complete_snapshot "$repo" > "$before"; uninstall_backups=$(uninstall_backup_count "$repo"); install_backups=$(install_backup_count "$repo"); for command in verify uninstall uninstall-replace reinstall reinstall-replace; do case "$command" in verify) bash "$installer_root/verify.sh" --target "$repo" >"$log" 2>&1 && return 1 ;; uninstall) bash "$installer_root/uninstall.sh" --target "$repo" >"$log" 2>&1 && return 1 ;; uninstall-replace) bash "$installer_root/uninstall.sh" --target "$repo" --owned-modified replace >"$log" 2>&1 && return 1 ;; reinstall) bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >"$log" 2>&1 && return 1 ;; reinstall-replace) bash "$installer_root/install.sh" --target "$repo" --profile generic --owned-modified replace --skip-bootstrap --skip-doctor >"$log" 2>&1 && return 1 ;; esac; grep -q 'State ownership metadata is invalid.' "$log"; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(uninstall_backup_count "$repo")" = "$uninstall_backups" ]; [ "$(install_backup_count "$repo")" = "$install_backups" ]; [ -f "$state" ]; done; }
invalid_managed_file_hash_state(){ corrupt_state_preflight invalid-managed-file-hash corrupt_invalid_managed_file_hash; }
missing_managed_files_section_state(){ corrupt_state_preflight missing-managed-files-section corrupt_missing_managed_files_section; }
incomplete_managed_block_record_state(){ corrupt_state_preflight incomplete-managed-block-record corrupt_incomplete_managed_block_record; }
invalid_managed_block_hash_state(){ corrupt_state_preflight invalid-managed-block-hash corrupt_invalid_managed_block_hash; }
missing_required_block_record_state(){ corrupt_state_preflight missing-required-block-record corrupt_missing_required_block_record; }
duplicate_managed_file_path_state(){ corrupt_state_preflight duplicate-managed-file-path corrupt_duplicate_managed_file_path; }
duplicate_managed_block_path_state(){ corrupt_state_preflight duplicate-managed-block-path corrupt_duplicate_managed_block_path; }
truncated_ownership_state(){ corrupt_state_preflight truncated-ownership-state corrupt_truncated_ownership_state; }
leading_garbage_state(){ corrupt_state_preflight leading-garbage corrupt_leading_garbage; }
trailing_garbage_state(){ corrupt_state_preflight trailing-garbage corrupt_trailing_garbage; }
duplicate_top_level_key_state(){ corrupt_state_preflight duplicate-top-level-key corrupt_duplicate_top_level_key; }
missing_top_level_field_state(){ corrupt_state_preflight missing-top-level-field corrupt_missing_top_level_field; }
malformed_json_escape_state(){ corrupt_state_preflight malformed-json-escape corrupt_malformed_json_escape; }
duplicate_installed_path_state(){ corrupt_state_preflight duplicate-installed-path corrupt_duplicate_installed_path; }
missing_state_installed_path_state(){ corrupt_state_preflight missing-state-installed-path corrupt_missing_state_installed_path; }
unexpected_installed_path_state(){ corrupt_state_preflight unexpected-installed-path corrupt_unexpected_installed_path; }
managed_removed_only_state(){ corrupt_state_preflight managed-removed-only corrupt_managed_removed_only; }
managed_removed_both_state(){ corrupt_state_preflight managed-removed-both corrupt_managed_removed_both; }
managed_outside_expected_state(){ corrupt_state_preflight managed-outside-expected corrupt_managed_outside_expected; }
escaped_display_newline_state(){ corrupt_state_preflight escaped-display-newline corrupt_escaped_display_newline; }
escaped_display_tab_state(){ corrupt_state_preflight escaped-display-tab corrupt_escaped_display_tab; }
duplicate_origin_state(){ corrupt_state_preflight duplicate-origin corrupt_duplicate_origin; }
duplicate_ipv6_origin_state(){ corrupt_state_preflight duplicate-ipv6-origin corrupt_duplicate_ipv6_origin; }
invalid_calendar_timestamp_state(){ corrupt_state_preflight invalid-calendar-timestamp corrupt_invalid_calendar_timestamp; }
wrong_case_managed_state(){ corrupt_state_preflight wrong-case-managed corrupt_wrong_case_managed; }
wrong_case_installed_state(){ corrupt_state_preflight wrong-case-installed corrupt_wrong_case_installed; }
wrong_case_block_state(){ corrupt_state_preflight wrong-case-block corrupt_wrong_case_block; }
non_ascii_managed_state(){ corrupt_state_preflight non-ascii-managed corrupt_non_ascii_managed; }
non_ascii_installed_state(){ corrupt_state_preflight non-ascii-installed corrupt_non_ascii_installed; }
non_ascii_block_state(){ corrupt_state_preflight non-ascii-block corrupt_non_ascii_block; }
uninstall_ignores_undeclared_paths(){ repo=$(new_repo undeclared-paths); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; echo keep > "$repo/.ai/undeclared-after-install.txt"; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ -f "$repo/.ai/undeclared-after-install.txt" ]; }
no_mcp(){ repo=$(new_repo no-mcp); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; ! grep -Eq 'mcp_servers\.(graphify|playwright)' "$repo/.codex/config.toml"; }
json_display_name_roundtrip(){ repo=$(new_repo json-display); display='Qbit "CLI" \ Tooling'; bash "$installer_root/install.sh" --target "$repo" --profile typescript --project-display-name "$display" --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; parse_and_validate_state "$state" "$tmp/json-files" "$tmp/json-blocks" "$tmp/json-installed" "$tmp/json-metadata" "$installer_root"; grep -F '"projectDisplayName": "Qbit \"CLI\" \\ Tooling"' "$state" >/dev/null; for json in "$repo/.ai/tooling/language-servers/package.json" "$repo/.ai/tooling/language-servers/package-lock.json" "$repo/.qbit-toolkit/codex-ai-tooling/manifest.json"; do json_document_valid "$json" || return 1; done; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; }
display_name_control_rejected(){ repo=$(new_repo display-control); before=$tmp/display-control-before; after=$tmp/display-control-after; complete_snapshot "$repo" > "$before"; bad=$(printf 'bad\tname'); ! bash "$installer_root/install.sh" --target "$repo" --profile generic --project-display-name "$bad" --skip-bootstrap --skip-doctor >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = 0 ]; }
assert_display_install_rejected(){ name=$1; value=$2; repo=$(new_repo "display-$name"); before=$tmp/"display-$name-before"; after=$tmp/"display-$name-after"; complete_snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --target "$repo" --profile generic --project-display-name "$value" --skip-bootstrap --skip-doctor >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = 0 ]; }
assert_display_reinstall_rejected(){ name=$1; value=$2; repo=$3; before=$tmp/"display-reinstall-$name-before"; after=$tmp/"display-reinstall-$name-after"; complete_snapshot "$repo" > "$before"; backups=$(install_backup_count "$repo"); ! bash "$installer_root/install.sh" --target "$repo" --profile generic --project-display-name "$value" --skip-bootstrap --skip-doctor >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = "$backups" ]; }
display_name_all_controls_rejected(){ tab=$(printf '\t'); cr=$(printf '\r'); bs=$(printf '\b'); ff=$(printf '\f'); del=$(printf '\177'); embedded_lf='bad
name'; trailing_lf='bad
'; assert_display_install_rejected tab "bad${tab}name"; assert_display_install_rejected embedded-lf "$embedded_lf"; assert_display_install_rejected trailing-lf "$trailing_lf"; assert_display_install_rejected cr "bad${cr}name"; assert_display_install_rejected backspace "bad${bs}name"; assert_display_install_rejected form-feed "bad${ff}name"; assert_display_install_rejected del "bad${del}name"; repo=$(new_repo display-reinstall); bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; assert_display_reinstall_rejected tab "bad${tab}name" "$repo"; assert_display_reinstall_rejected embedded-lf "$embedded_lf" "$repo"; assert_display_reinstall_rejected trailing-lf "$trailing_lf" "$repo"; assert_display_reinstall_rejected cr "bad${cr}name" "$repo"; assert_display_reinstall_rejected backspace "bad${bs}name" "$repo"; assert_display_reinstall_rejected form-feed "bad${ff}name" "$repo"; assert_display_reinstall_rejected del "bad${del}name" "$repo"; }
duplicate_origins_deduplicated(){ repo=$(new_repo origin-deduplicate); bash "$installer_root/install.sh" --target "$repo" --profile generic --allowed-origin http://localhost:3000/ --allowed-origin http://localhost:3000 --allowed-origin http://localhost:3000 --allowed-origin http://127.0.0.1:3000 --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; [ "$(grep -Fxc '    "http://localhost:3000",' "$state")" = 1 ]; [ "$(grep -Fxc '    "http://127.0.0.1:3000"' "$state")" = 1 ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
ipv6_origins_deduplicated(){ repo=$(new_repo origin-ipv6-deduplicate); bash "$installer_root/install.sh" --target "$repo" --profile generic --allowed-origin 'http://[::1]:3000' --allowed-origin http://localhost:3000 --allowed-origin 'http://[::1]:3000' --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; actual=$(awk '$0=="  \"allowedOrigins\": ["{inside=1;next} inside && $0=="  ],"{exit} inside{line=$0;sub(/^    "/,"",line);sub(/"[,]?$/,"",line);print line}' "$state"); [ "$actual" = 'http://[::1]:3000
http://localhost:3000' ]; [ "$(grep -Fxc '    "http://[::1]:3000",' "$state")" = 1 ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
state_installed_at(){ sed -n 's/^  "installedAtUtc": "\([^"]*\)",$/\1/p' "$1/.qbit/toolkit/installed/codex-ai-tooling.json"; }
installed_at_policy(){ repo=$(new_repo installed-at-policy); bash "$installer_root/install.sh" --target "$repo" --profile typescript --project-display-name First --skip-bootstrap --skip-doctor >/dev/null; first=$(state_installed_at "$repo"); bash "$installer_root/install.sh" --target "$repo" --profile typescript --project-display-name First --skip-bootstrap --skip-doctor >/dev/null; [ "$(state_installed_at "$repo")" = "$first" ]; bash "$installer_root/install.sh" --target "$repo" --profile typescript --allowed-origin http://localhost:3000 --skip-bootstrap --skip-doctor >/dev/null; [ "$(state_installed_at "$repo")" = "$first" ]; bash "$installer_root/install.sh" --target "$repo" --profile typescript --project-display-name Second --allowed-origin http://localhost:3000 --skip-bootstrap --skip-doctor >/dev/null; [ "$(state_installed_at "$repo")" = "$first" ]; bash "$installer_root/install.sh" --target "$repo" --profile rust --project-display-name Second --allowed-origin http://localhost:3000 --skip-bootstrap --skip-doctor >/dev/null; [ "$(state_installed_at "$repo")" = "$first" ]; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; sleep 1; bash "$installer_root/install.sh" --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; [ "$(state_installed_at "$repo")" != "$first" ]; }
installed_paths_exact(){ repo=$(new_repo installed-paths); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; state=$repo/.qbit/toolkit/installed/codex-ai-tooling.json; files=$tmp/manifest-files; blocks=$tmp/manifest-blocks; installed=$tmp/manifest-installed; metadata=$tmp/manifest-metadata; expected=$tmp/manifest-expected; parse_and_validate_state "$state" "$files" "$blocks" "$installed" "$metadata" "$installer_root"; expected_managed_paths "$installer_root" typescript "$tmp/manifest-managed"; cp "$tmp/manifest-managed" "$expected"; printf '%s\n' .gitignore .gitattributes AGENTS.md .qbit/toolkit/installed/codex-ai-tooling.json >> "$expected"; LC_ALL=C sort -o "$expected" "$expected"; cmp -s "$expected" "$installed"; [ "$(grep -Fxc '.qbit/toolkit/installed/codex-ai-tooling.json' "$installed")" = 1 ]; [ "$(LC_ALL=C sort -u "$installed" | wc -l | tr -d ' ')" = "$(wc -l < "$installed" | tr -d ' ')" ]; }
migrate_typescript_to(){ target_profile=$1; repo=$(new_repo "migration-ts-$target_profile"); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/install.sh" --target "$repo" --profile "$target_profile" --skip-bootstrap --skip-doctor >/dev/null; [ -f "$repo/.ai/tooling/language-servers/package.json" ]; [ -f "$repo/.ai/tooling/language-servers/package-lock.json" ]; grep -F "\"profile\": \"$target_profile\"" "$repo/.qbit/toolkit/installed/codex-ai-tooling.json" >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ ! -e "$repo/.ai/tooling/language-servers/package.json" ]; }
migration_typescript_rust(){ migrate_typescript_to rust; }
migration_typescript_generic(){ migrate_typescript_to generic; }
migration_rust_typescript(){ repo=$(new_repo migration-rust-ts); bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; [ -f "$repo/.ai/tooling/language-servers/package.json" ]; [ -f "$repo/.ai/tooling/language-servers/package-lock.json" ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
modified_stale_blocks_migration(){ repo=$(new_repo migration-modified-block); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; printf '\nproject edit\n' >> "$repo/.ai/tooling/language-servers/package.json"; before=$tmp/migration-modified-before; after=$tmp/migration-modified-after; complete_snapshot "$repo" > "$before"; backups=$(install_backup_count "$repo"); ! bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ "$(install_backup_count "$repo")" = "$backups" ]; }
modified_stale_force_migration(){ repo=$(new_repo migration-modified-replace); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; owned=.codex/config.toml; printf '\nproject edit\n' >> "$repo/$owned"; bash "$installer_root/install.sh" --target "$repo" --profile rust --owned-modified replace --skip-bootstrap --skip-doctor >/dev/null; find "$repo/.qbit-toolkit/codex-ai-tooling/backups" -type f -path "*/$owned" | grep . >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
missing_stale_blocks_migration(){ repo=$(new_repo migration-missing); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; canonical=$(test_sha_file "$repo/.ai/tooling/language-servers/package.json"); rm -f "$repo/.ai/tooling/language-servers/package.json"; bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; [ -f "$repo/.ai/tooling/language-servers/package.json" ]; [ "$(test_sha_file "$repo/.ai/tooling/language-servers/package.json")" = "$canonical" ]; grep -F '"profile": "rust"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json" >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
migration_dryrun(){ repo=$(new_repo migration-dryrun); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; before=$tmp/migration-dryrun-before; after=$tmp/migration-dryrun-after; log=$tmp/migration-dryrun.log; complete_snapshot "$repo" > "$before"; bash "$installer_root/install.sh" --target "$repo" --profile rust --dry-run --skip-bootstrap --skip-doctor > "$log"; ! grep -F 'remove .ai/tooling/language-servers/package.json' "$log" >/dev/null; ! grep -F 'remove .ai/tooling/language-servers/package-lock.json' "$log" >/dev/null; [ -f "$repo/.ai/tooling/language-servers/package.json" ]; [ -f "$repo/.ai/tooling/language-servers/package-lock.json" ]; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
migration_rollback(){ repo=$(new_repo migration-rollback); printf 'project owned\n' > "$repo/PROJECT.txt"; bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; before=$tmp/migration-rollback-before; after=$tmp/migration-rollback-after; complete_snapshot "$repo" > "$before"; QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES=1; export QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; if bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null 2>&1; then unset QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; return 1; fi; unset QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
migration_creation_rollback(){ repo=$(new_repo migration-create-rollback); bash "$installer_root/install.sh" --target "$repo" --profile rust --skip-bootstrap --skip-doctor >/dev/null; shared=$repo/.ai/tooling/language-servers/package.json; before_hash=$(test_sha_file "$shared"); before=$tmp/migration-create-rollback-before; after=$tmp/migration-create-rollback-after; complete_snapshot "$repo" > "$before"; QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES=1; export QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; if bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null 2>&1; then unset QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; return 1; fi; unset QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; [ -f "$shared" ]; [ "$(test_sha_file "$shared")" = "$before_hash" ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; }
rollback_failure_then_recovery(){ repo=$(new_repo rollback-failure-recovery); QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES=1 QBIT_TOOLKIT_TEST_FAIL_ROLLBACK=1 bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --format json --non-interactive > "$tmp/rollback-failure.json" 2>/dev/null && return 1; grep -Fq '"exit_code":7' "$tmp/rollback-failure.json"; bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --non-interactive >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; grep -Fl '"status": "recovered"' "$repo/.qbit-toolkit/codex-ai-tooling/transactions"/*/journal.json >/dev/null; }
root_node_modules_allowed(){ repo=$(new_repo root-node-modules); mkdir -p "$repo/node_modules"; printf 'application dependency state\n' > "$repo/node_modules/application-sentinel.txt"; before=$(test_sha_file "$repo/node_modules/application-sentinel.txt"); bash "$installer_root/install.sh" --target "$repo" --profile typescript --skip-bootstrap --skip-doctor >/dev/null; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; [ "$(test_sha_file "$repo/node_modules/application-sentinel.txt")" = "$before" ]; }
adopt_matching(){ repo=$(new_repo adopt-matching); cp "$installer_root/templates/common/.graphifyignore" "$repo/.graphifyignore"; bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --adopt-matching --skip-bootstrap --skip-doctor >/dev/null; grep -Fq '".graphifyignore"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; }
recognized_legacy_migration(){ repo=$(new_repo recognized-legacy); mkdir -p "$repo/.ai/scripts"; printf '%s\n' 'param([Parameter(Mandatory = $true)][string]$Scope)' '$ErrorActionPreference = '\''Stop'\''' '& (Join-Path $PSScriptRoot '\''graphify-sidecar.ps1'\'') -Action ensure -Scope $Scope' > "$repo/.ai/scripts/graphify-build.ps1"; before=$tmp/recognized-legacy-before; after=$tmp/recognized-legacy-after; complete_snapshot "$repo" > "$before"; bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --migrate-legacy --format json --non-interactive >/dev/null; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --migrate-legacy --skip-bootstrap --skip-doctor >/dev/null; [ "$(install_backup_count "$repo")" -ge 1 ]; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; complete_snapshot "$repo" > "$before"; bash "$installer_root/install.sh" --operation install --target "$repo" --profile generic --migrate-legacy --skip-bootstrap --skip-doctor >/dev/null; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
recognized_legacy_custom_conflicts(){ repo=$(new_repo legacy-custom-codex); mkdir -p "$repo/.ai/scripts" "$repo/.codex"; printf '%s\n' 'param([Parameter(Mandatory = $true)][string]$Scope)' '$ErrorActionPreference = '\''Stop'\''' '& (Join-Path $PSScriptRoot '\''graphify-sidecar.ps1'\'') -Action ensure -Scope $Scope' > "$repo/.ai/scripts/graphify-build.ps1"; printf 'custom = true\n' > "$repo/.codex/config.toml"; before=$tmp/legacy-custom-before; after=$tmp/legacy-custom-after; complete_snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --migrate-legacy --format json --non-interactive >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
recognized_legacy_custom_readme_conflicts(){ repo=$(new_repo legacy-custom-readme); mkdir -p "$repo/.ai/scripts" "$repo/.ai/tooling"; printf '%s\n' 'param([Parameter(Mandatory = $true)][string]$Scope)' '$ErrorActionPreference = '\''Stop'\''' '& (Join-Path $PSScriptRoot '\''graphify-sidecar.ps1'\'') -Action ensure -Scope $Scope' > "$repo/.ai/scripts/graphify-build.ps1"; printf 'custom documentation\n' > "$repo/.ai/tooling/README.md"; before=$tmp/legacy-readme-before; after=$tmp/legacy-readme-after; complete_snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --migrate-legacy --format json --non-interactive >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
recognized_partial_unknown_path_conflicts(){ repo=$(new_repo legacy-unknown-path); mkdir -p "$repo/.ai/scripts"; printf '%s\n' 'param([Parameter(Mandatory = $true)][string]$Scope)' '$ErrorActionPreference = '\''Stop'\''' '& (Join-Path $PSScriptRoot '\''graphify-sidecar.ps1'\'') -Action ensure -Scope $Scope' > "$repo/.ai/scripts/graphify-build.ps1"; printf 'unknown managed content\n' > "$repo/.env.ai.example"; before=$tmp/legacy-unknown-before; after=$tmp/legacy-unknown-after; complete_snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --migrate-legacy --format json --non-interactive >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
unknown_legacy_migration_fails(){ repo=$(new_repo unknown-legacy); mkdir -p "$repo/.codex"; printf 'custom = true\n' > "$repo/.codex/config.toml"; before=$tmp/unknown-legacy-before; after=$tmp/unknown-legacy-after; complete_snapshot "$repo" > "$before"; ! bash "$installer_root/install.sh" --operation plan --target "$repo" --profile generic --migrate-legacy --format json --non-interactive >/dev/null 2>&1; complete_snapshot "$repo" > "$after"; cmp -s "$before" "$after"; }
scenario 'fresh generic POSIX install' fresh_generic
scenario 'fresh rust POSIX install' fresh_rust
scenario 'auto POSIX detects Rust' auto_rust
scenario 'POSIX TypeScript precedence over Rust' typescript_wins
scenario 'dry run POSIX writes nothing' dryrun
scenario 'conflicting POSIX file fails' conflict
scenario 'POSIX AGENTS content preserved' agents_preserved
scenario 'POSIX AGENTS boundary variants round trip' agents_roundtrip_variants
scenario 'POSIX reversed AGENTS markers leave snapshot unchanged' agents_reversed_snapshot
scenario 'POSIX malformed AGENTS uninstall leaves snapshot unchanged' agents_malformed_uninstall_snapshot
scenario 'POSIX verify detects managed-block hash changes' verify_block_modified
scenario 'POSIX verify ignores outside-block AGENTS edits' verify_outside_block_edit
scenario 'POSIX default policy rejects modified owned AGENTS block without mutation' managed_block_default_conflict
scenario 'POSIX replace policy backs up and replaces only modified owned AGENTS block' managed_block_replace
scenario 'POSIX plan plus replace reports exact owned file and block actions without mutation' plan_replace_owned_content
scenario 'POSIX replace rejects unowned and malformed managed markers without mutation' replace_rejects_unowned_and_malformed_markers
scenario 'POSIX unchanged owned legacy AGENTS migrates under fail and replace policies' legacy_unchanged_owned_migration
scenario 'POSIX modified owned legacy AGENTS default policy fails without mutation' legacy_modified_default_conflict
scenario 'POSIX modified owned legacy AGENTS replace migrates transactionally' legacy_modified_replace_migration
scenario 'POSIX modified owned legacy AGENTS plan plus replace is write-free' legacy_modified_plan_replace
scenario 'POSIX legacy negative cases fail closed under replace' legacy_negative_replace_cases
scenario 'POSIX replace-policy uninstall backs up modified block' uninstall_block_modified_force
scenario 'POSIX project-owned hidden files survive uninstall' project_owned_hidden_survives
scenario 'POSIX modified managed file blocks verify/uninstall and replace policy backs up' modified_file_verify_uninstall_force
scenario 'POSIX missing state-declared managed file blocks normal and forced uninstall preflight' missing_managed_file_preflight
scenario 'POSIX missing state-declared managed-block file blocks normal and forced uninstall preflight' missing_managed_block_file_preflight
scenario 'POSIX invalid managed-file hash state fails closed' invalid_managed_file_hash_state
scenario 'POSIX missing managedFiles section state fails closed' missing_managed_files_section_state
scenario 'POSIX incomplete managed-block record state fails closed' incomplete_managed_block_record_state
scenario 'POSIX invalid managed-block hash state fails closed' invalid_managed_block_hash_state
scenario 'POSIX missing required block record state fails closed' missing_required_block_record_state
scenario 'POSIX duplicate managed-file path state fails closed' duplicate_managed_file_path_state
scenario 'POSIX duplicate managed-block path state fails closed' duplicate_managed_block_path_state
scenario 'POSIX truncated ownership state fails closed' truncated_ownership_state
scenario 'POSIX leading non-JSON garbage state fails every consumer closed' leading_garbage_state
scenario 'POSIX trailing garbage state fails every consumer closed' trailing_garbage_state
scenario 'POSIX duplicate top-level key state fails every consumer closed' duplicate_top_level_key_state
scenario 'POSIX missing required top-level field state fails every consumer closed' missing_top_level_field_state
scenario 'POSIX malformed JSON string escape state fails every consumer closed' malformed_json_escape_state
scenario 'POSIX duplicate installedRelativePaths entry fails every consumer closed' duplicate_installed_path_state
scenario 'POSIX missing state path from installedRelativePaths fails every consumer closed' missing_state_installed_path_state
scenario 'POSIX unexpected installedRelativePaths entry fails every consumer closed' unexpected_installed_path_state
scenario 'POSIX managed file removed only from managedFiles fails every consumer closed' managed_removed_only_state
scenario 'POSIX managed file removed from managedFiles and installedRelativePaths fails every consumer closed' managed_removed_both_state
scenario 'POSIX managed file outside expected profile manifest fails every consumer closed' managed_outside_expected_state
scenario 'POSIX escaped newline display-name state fails every consumer closed' escaped_display_newline_state
scenario 'POSIX escaped Unicode tab display-name state fails every consumer closed' escaped_display_tab_state
scenario 'POSIX duplicate allowed origin state fails every consumer closed' duplicate_origin_state
scenario 'POSIX duplicate IPv6 origin state fails every consumer closed' duplicate_ipv6_origin_state
scenario 'POSIX impossible UTC timestamp state fails every consumer closed' invalid_calendar_timestamp_state
scenario 'POSIX wrong-cased managedFiles path fails every consumer closed' wrong_case_managed_state
scenario 'POSIX wrong-cased installedRelativePaths path fails every consumer closed' wrong_case_installed_state
scenario 'POSIX wrong-cased managed-block path fails every consumer closed' wrong_case_block_state
scenario 'POSIX non-ASCII managedFiles path fails every consumer closed' non_ascii_managed_state
scenario 'POSIX non-ASCII installedRelativePaths path fails every consumer closed' non_ascii_installed_state
scenario 'POSIX non-ASCII managed-block path fails every consumer closed' non_ascii_block_state
scenario 'POSIX JSON display name escaping preserves decoded values' json_display_name_roundtrip
scenario 'POSIX project display name control characters fail before mutation' display_name_control_rejected
scenario 'POSIX all display-name controls fail before fresh install or reinstall mutation' display_name_all_controls_rejected
scenario 'POSIX duplicate normalized origins are written once' duplicate_origins_deduplicated
scenario 'POSIX IPv6 origins are literally deduplicated in first-occurrence order' ipv6_origins_deduplicated
scenario 'POSIX installedAtUtc is preserved for valid reinstall and reset after uninstall' installed_at_policy
scenario 'POSIX installedRelativePaths is unique deterministic expected union' installed_paths_exact
scenario 'POSIX profile migration typescript to rust preserves shared files' migration_typescript_rust
scenario 'POSIX profile migration typescript to generic preserves shared files' migration_typescript_generic
scenario 'POSIX profile migration rust to typescript preserves shared files' migration_rust_typescript
scenario 'POSIX modified shared file blocks migration before mutation' modified_stale_blocks_migration
scenario 'POSIX replace-policy migration backs up and restores modified shared file' modified_stale_force_migration
scenario 'POSIX missing shared file is recreated during profile migration' missing_stale_blocks_migration
scenario 'POSIX migration DryRun preserves shared files and writes nothing' migration_dryrun
scenario 'POSIX migration injected failure restores complete snapshot' migration_rollback
scenario 'POSIX migration creation failure preserves shared baseline' migration_creation_rollback
scenario 'POSIX rollback failure leaves evidence and the next mutation recovers' rollback_failure_then_recovery
scenario 'POSIX root node_modules is allowed and untouched' root_node_modules_allowed
scenario 'POSIX explicit matching adoption records ownership' adopt_matching
scenario 'POSIX recognized legacy migration is backed up and idempotent' recognized_legacy_migration
scenario 'POSIX recognized legacy cannot replace custom Codex configuration' recognized_legacy_custom_conflicts
scenario 'POSIX recognized legacy cannot replace custom tooling README' recognized_legacy_custom_readme_conflicts
scenario 'POSIX recognized partial legacy rejects unknown managed path' recognized_partial_unknown_path_conflicts
scenario 'POSIX unknown legacy migration is write-free and fail-closed' unknown_legacy_migration_fails
scenario 'POSIX uninstall ignores undeclared paths' uninstall_ignores_undeclared_paths
scenario 'Graphify and Playwright not POSIX MCP servers' no_mcp
echo "RESULT passed=$pass failed=$fail skipped=0"
[ "$fail" -eq 0 ]
