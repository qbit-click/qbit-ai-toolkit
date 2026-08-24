#!/usr/bin/env sh
set -eu

installer_id=installer.codex-ai-tooling
installer_version=1.1.1
state_path=.qbit/toolkit/installed/codex-ai-tooling.json
begin_marker='# qbit-toolkit:codex-ai-tooling:start'
end_marker='# qbit-toolkit:codex-ai-tooling:end'
agents_begin_marker='<!-- qbit-toolkit:codex-ai-tooling:start -->'
agents_end_marker='<!-- qbit-toolkit:codex-ai-tooling:end -->'
profile=auto
target=
project_slug=
project_display_name=
allowed_origins=
dry_run=false
owned_modified_policy=fail
adopt_matching=false
migrate_legacy=false
skip_bootstrap=false
skip_doctor=false

usage() { echo 'Usage: install-engine.sh --target <path> [--profile auto|generic|typescript|rust] [--project-slug <slug>] [--project-display-name <name>] [--allowed-origin <origin>]... [--dry-run] [--owned-modified fail|replace] [--adopt-matching] [--migrate-legacy] [--skip-bootstrap] [--skip-doctor]' >&2; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) target=${2:-}; shift 2 ;;
    --profile) profile=${2:-}; shift 2 ;;
    --project-slug) project_slug=${2:-}; shift 2 ;;
    --project-display-name) project_display_name=${2:-}; shift 2 ;;
    --allowed-origin) allowed_origins=${allowed_origins}${allowed_origins:+,}${2:-}; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --owned-modified) owned_modified_policy=${2:-}; shift 2 ;;
    --adopt-matching) adopt_matching=true; shift ;;
    --migrate-legacy) migrate_legacy=true; shift ;;
    --skip-bootstrap) skip_bootstrap=true; shift ;;
    --skip-doctor) skip_doctor=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$target" ] || { usage; exit 2; }
case "$profile" in auto|generic|typescript|rust) ;; *) echo 'Invalid profile.' >&2; exit 2 ;; esac
case "$owned_modified_policy" in fail|replace) ;; *) echo 'Invalid owned-modified policy.' >&2; exit 2 ;; esac
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$script_dir/lib/installer.sh"
toolkit_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
target_root=$(CDPATH= cd -- "$target" && pwd) || { echo "Target directory does not exist: $target" >&2; exit 1; }
case "$target_root" in /|"$HOME") echo 'Refusing to target filesystem root or home root.' >&2; exit 1 ;; esac
[ "$target_root" != "$toolkit_root" ] || { echo 'Refusing to install qbit-toolkit into itself.' >&2; exit 1; }
git -C "$target_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'Target must be a Git work tree.' >&2; exit 1; }
git_top=$(git -C "$target_root" rev-parse --show-toplevel)
git_top_compare=$git_top
target_root_compare=$target_root
if command -v cygpath >/dev/null 2>&1; then
  git_top_compare=$(cygpath -aw "$git_top")
  target_root_compare=$(cygpath -aw "$target_root")
fi
[ "$git_top_compare" = "$target_root_compare" ] || { echo "Target must be the Git work tree root. Git root is: $git_top" >&2; exit 1; }
initial_git_index=$(git -C "$target_root" ls-files --stage) || { echo 'Could not read initial Git index state.' >&2; exit 1; }
if [ -n "$(git -C "$target_root" status --porcelain)" ]; then echo 'Warning: target has uncommitted changes; installer will not stage, reset, stash, commit, or clean them.' >&2; fi

runtime_root=$target_root/.qbit-toolkit/codex-ai-tooling
transactions_root=$runtime_root/transactions
backups_root=$runtime_root/backups
recovery_root=$runtime_root/recovery
lock_file=$runtime_root/lock.json
host_identity=$(hostname 2>/dev/null || uname -n)
if [ "$dry_run" = false ] && { [ -f "$lock_file" ] || { [ -d "$transactions_root" ] && grep -Fl '"status": "active"' "$transactions_root"/*/journal.json >/dev/null 2>&1; }; }; then
  mkdir -p "$recovery_root" || { echo 'Could not initialize installer recovery state.' >&2; exit 1; }
  if [ -f "$lock_file" ]; then
    lock_host=$(sed -n 's/^  "host_identity": "\(.*\)",$/\1/p' "$lock_file")
    lock_pid=$(sed -n 's/^  "process_id": \([0-9][0-9]*\),$/\1/p' "$lock_file")
    if [ "$lock_host" = "$host_identity" ] && [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
      mv "$lock_file" "$recovery_root/stale-lock-$(date -u '+%Y%m%dT%H%M%SZ')-$$.json" || { echo 'Uncertain installer lock could not be recovered.' >&2; exit 1; }
    else
      echo 'Active installer lock or uncertain cross-host lock detected.' >&2
      exit 1
    fi
  fi
  for recovery_transaction in "$transactions_root"/*; do
    [ -d "$recovery_transaction" ] || continue
    recovery_journal=$recovery_transaction/journal.json
    grep -Fq '"status": "active"' "$recovery_journal" 2>/dev/null || continue
    recovery_id=$(basename "$recovery_transaction")
    recovery_backup=$backups_root/$recovery_id
    recovery_ok=true
    if [ -f "$recovery_transaction/backed" ]; then
      while IFS= read -r recovery_rel; do
        [ -n "$recovery_rel" ] || continue
        mkdir -p "$(dirname "$target_root/$recovery_rel")" && cp "$recovery_backup/$recovery_rel" "$target_root/$recovery_rel" || recovery_ok=false
      done < "$recovery_transaction/backed"
    fi
    if [ -f "$recovery_transaction/created" ]; then
      while IFS= read -r recovery_rel; do [ -n "$recovery_rel" ] && rm -f "$target_root/$recovery_rel" || true; done < "$recovery_transaction/created"
    fi
    [ "$recovery_ok" = true ] || { echo 'Recovery from an incomplete installer transaction failed.' >&2; exit 1; }
    sed 's/"status": "active"/"status": "recovered"/' "$recovery_journal" > "$recovery_transaction/journal.tmp" || { echo 'Recovery journal update failed.' >&2; exit 1; }
    mv "$recovery_transaction/journal.tmp" "$recovery_journal" || { echo 'Recovery journal update failed.' >&2; exit 1; }
  done
fi

target_name=$(basename "$target_root")
slug=$(normalize_slug "${project_slug:-$target_name}")
[ -n "$slug" ] || { echo 'Project slug resolves to empty.' >&2; exit 1; }
display_name=${project_display_name:-$target_name}
validate_project_display_name "$display_name" || { echo 'Project display name must not contain control characters.' >&2; exit 1; }
display_name_json=$(json_escape "$display_name")
selected_profile=$(resolve_profile "$profile" "$target_root")

if [ -z "$allowed_origins" ]; then allowed_origins='http://localhost:3000,http://127.0.0.1:3000'; explicit_origins=false; else explicit_origins=true; fi

normalized_origins_file=$(mktemp 2>/dev/null || mktemp -t qbit-origins)
trap 'rm -f "$normalized_origins_file"' EXIT HUP INT TERM
: > "$normalized_origins_file"
old_ifs=$IFS; IFS=,
for origin in $allowed_origins; do
  IFS=$old_ifs; clean=$(validate_origin "$origin")
  if ! grep -F -x -e "$clean" "$normalized_origins_file" >/dev/null 2>&1; then printf '%s\n' "$clean" >> "$normalized_origins_file"; fi
  IFS=,
done
IFS=$old_ifs
normalized_origins=$(awk 'BEGIN{first=1} {if(!first) printf ","; printf "%s",$0; first=0}' "$normalized_origins_file")
origins_json='['; first=true
while IFS= read -r origin; do [ "$first" = true ] || origins_json=$origins_json,; origins_json=$origins_json$(json_quote "$origin"); first=false; done < "$normalized_origins_file"
origins_json=$origins_json']'
compose_project_name=$slug-ai-tooling
docker_image_name=$slug-ai-tooling:serena-1.5.3-graphify-0.9.12
serena_enabled=false; case "$selected_profile" in typescript|rust) serena_enabled=true ;; esac
project_description='a generic repository.'
language_summary='generic repository'
[ "$selected_profile" = typescript ] && { project_description='a TypeScript repository.'; language_summary='TypeScript repository'; }
[ "$selected_profile" = rust ] && { project_description='a Rust repository.'; language_summary='Rust repository'; }

sed_escape() { printf '%s' "$1" | sed 's/[\\/&]/\\&/g'; }
template_token() { printf '{{%s}}' "$1"; }
render_file() {
  src=$1; dst=$2
  sed \
    -e "s/$(template_token PROJECT_SLUG)/$(sed_escape "$slug")/g" \
    -e "s/$(template_token PROJECT_DISPLAY_NAME_JSON)/$(sed_escape "$display_name_json")/g" \
    -e "s/$(template_token COMPOSE_PROJECT_NAME)/$(sed_escape "$compose_project_name")/g" \
    -e "s/$(template_token DOCKER_IMAGE_NAME)/$(sed_escape "$docker_image_name")/g" \
    -e "s/$(template_token SERENA_PROJECT_NAME)/$(sed_escape "$slug")/g" \
    -e "s/$(template_token ALLOWED_ORIGINS_JSON)/$(sed_escape "$origins_json")/g" \
    -e "s/$(template_token ALLOWED_ORIGINS_CSV)/$(sed_escape "$normalized_origins")/g" \
    -e "s/$(template_token SELECTED_PROFILE)/$selected_profile/g" \
    -e "s/$(template_token SERENA_ENABLED)/$serena_enabled/g" \
    -e "s/$(template_token LANGUAGE_SUMMARY)/$(sed_escape "$language_summary")/g" \
    -e "s/$(template_token PROJECT_DESCRIPTION)/$(sed_escape "$project_description")/g" \
    -e "s/$(template_token SERENA_VERSION)/1.5.3/g" \
    -e "s/$(template_token GRAPHIFY_VERSION)/0.9.12/g" \
    -e "s/$(template_token TYPESCRIPT_VERSION)/5.9.3/g" \
    -e "s/$(template_token TYPESCRIPT_LANGUAGE_SERVER_VERSION)/5.1.3/g" \
    -e "s/$(template_token RUST_TOOLCHAIN_VERSION)/1.85.0/g" \
    -e "s/$(template_token RUST_BASE_IMAGE)/$(sed_escape 'rust:1.85.0-slim-bookworm@sha256:c842cc0357b91bb15ad2bb89934513d0d226f711fac7f7fedb176d3311714d47')/g" "$src" > "$dst"
}
sha_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
plan_dir=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-plan)
trap 'rm -rf "$plan_dir"; rm -f "$normalized_origins_file"' EXIT HUP INT TERM
previous_files=$plan_dir/previous-files
previous_blocks=$plan_dir/previous-blocks
previous_installed=$plan_dir/previous-installed
previous_metadata=$plan_dir/previous-metadata
previous_state=$target_root/$state_path
: > "$previous_files"; : > "$previous_blocks"; : > "$previous_installed"; : > "$previous_metadata"
if [ -e "$previous_state" ]; then
  [ -f "$previous_state" ] || { echo 'Existing state path is not a regular file.' >&2; exit 1; }
  if ! parse_and_validate_state "$previous_state" "$previous_files" "$previous_blocks" "$previous_installed" "$previous_metadata" "$script_dir"; then
    echo 'State ownership metadata is invalid.' >&2
    exit 1
  fi
  validate_portable_ownership_state "$target_root" "$previous_files" "$previous_blocks" || { echo 'Portable ownership manifest does not match compatibility ownership state.' >&2; exit 1; }
fi
legacy_variant_path=
legacy_variant_hash=
legacy_variant_count=0
allow_unowned_legacy_blocks=false
legacy_anchor_matches(){
  legacy_path=$1; shift
  [ -f "$target_root/$legacy_path" ] || return 1
  legacy_hash=$(sha_file "$target_root/$legacy_path")
  for legacy_expected in "$@"; do [ "$legacy_hash" = "$legacy_expected" ] && return 0; done
  return 1
}
select_legacy_variant(){
  legacy_candidate_path=$1; legacy_candidate_hash=$2
  if legacy_anchor_matches "$legacy_candidate_path" "$legacy_candidate_hash"; then
    legacy_variant_count=$((legacy_variant_count+1))
    legacy_variant_path=$legacy_candidate_path
    legacy_variant_hash=$legacy_candidate_hash
  fi
}
if [ "$migrate_legacy" = true ] && [ ! -e "$previous_state" ]; then
  # Audited historical fingerprints are path-specific.  A match never grants
  # authority to replace a different managed path, and variants cannot mix.
  select_legacy_variant .ai/scripts/graphify-build.ps1 f83ce32dd3aafd94a1b4dcefa170141bc93c1332775235b45a192c9c5bccc74d
  select_legacy_variant .agents/skills/architecture-impact-analysis/SKILL.md 3441300fe10813a5eaddaef8fcd9c611d25c3190f9157b62b0d180705a0df99b
  select_legacy_variant .agents/skills/architecture-impact-analysis/SKILL.md f30d4f56abb56b2be4f09aa4bc65ad0d58a41f825908b6aa67213313309313d1
  select_legacy_variant .agents/skills/architecture-impact-analysis/SKILL.md 21f406a21c3f8ce4218c0d34d0dad0f47849dc6e17e01acf65cace0d937fe1c0
  select_legacy_variant .serena/project.yml 37c169cee6a4e44b4073b7de6ecf9a5805f9cfe717dcf1de5e6a25e8e0feff14
  select_legacy_variant .serena/project.yml b47976f16f34978421d3dcdfea2453911a30984cd5027e8f7577bf9d3d11cdb9
  [ "$legacy_variant_count" -le 1 ] || { echo 'Legacy migration found incompatible audited payload variants; no files were changed.' >&2; exit 1; }
  for legacy_block in .gitignore .gitattributes AGENTS.md; do
    [ -f "$target_root/$legacy_block" ] || continue
    case "$legacy_block" in
      AGENTS.md) legacy_begin='<!-- >>> qbit-toolkit:codex-ai-tooling -->'; legacy_end='<!-- <<< qbit-toolkit:codex-ai-tooling -->' ;;
      *) legacy_begin='# >>> qbit-toolkit:codex-ai-tooling'; legacy_end='# <<< qbit-toolkit:codex-ai-tooling' ;;
    esac
    if managed_block_has_valid_block "$target_root/$legacy_block" "$legacy_begin" "$legacy_end"; then allow_unowned_legacy_blocks=true; fi
  done
  if [ "$legacy_variant_count" -eq 0 ] && [ "$allow_unowned_legacy_blocks" = false ]; then
    echo 'Legacy migration was requested but no coherent audited payload fingerprint or managed block was found.' >&2
    exit 1
  fi
fi
metadata_value(){ awk -F '|' -v key="$1" '$1==key {sub(/^[^|]*\|/,""); print; exit}' "$previous_metadata"; }
previous_block_value(){ awk -F '|' -v path="$1" -v field="$2" '$1==path {if(field=="hash") print $2; else if(field=="created") print $3; else if(field=="separator") print $4; exit}' "$previous_blocks"; }
merge_with_metadata() {
  mwm_target=$1; mwm_fragment=$2; mwm_output=$3; mwm_meta=$4; mwm_begin=$5; mwm_end=$6
  mwm_relative=$(basename "$mwm_output")
  mwm_previous_hash=$(previous_block_value "$mwm_relative" hash)
  mwm_previous_created=$(previous_block_value "$mwm_relative" created)
  mwm_previous_sep=$(previous_block_value "$mwm_relative" separator)
  mwm_legacy_begin='# >>> qbit-toolkit:codex-ai-tooling'
  mwm_legacy_end='# <<< qbit-toolkit:codex-ai-tooling'
  if [ "$mwm_relative" = AGENTS.md ]; then
    mwm_legacy_begin='<!-- >>> qbit-toolkit:codex-ai-tooling -->'
    mwm_legacy_end='<!-- <<< qbit-toolkit:codex-ai-tooling -->'
  fi
  mwm_source=$mwm_target
  mwm_migrated=false
  if [ -f "$mwm_target" ]; then
    managed_block_assert_absent_or_valid "$mwm_target" "$mwm_begin" "$mwm_end" || return 1
    managed_block_assert_absent_or_valid "$mwm_target" "$mwm_legacy_begin" "$mwm_legacy_end" || return 1
    if [ "$(managed_block_line_count "$mwm_target" "$mwm_begin")" -eq 1 ] && [ "$(managed_block_line_count "$mwm_target" "$mwm_legacy_begin")" -eq 1 ]; then
      echo "Both current and legacy managed markers exist in $mwm_relative." >&2
      return 1
    fi
  fi
  if [ -f "$mwm_target" ] && managed_block_has_valid_block "$mwm_target" "$mwm_begin" "$mwm_end"; then
    [ -n "$mwm_previous_hash" ] || { echo "Unowned managed markers exist in $mwm_relative." >&2; return 1; }
    {
      managed_block_extract_file "$mwm_target" "$plan_dir/current-block" "$mwm_begin" "$mwm_end" || return 1
      [ "$(sha_file "$plan_dir/current-block")" = "$mwm_previous_hash" ] || [ "$owned_modified_policy" = replace ] || { echo "Managed block was modified after installation: $mwm_relative" >&2; return 1; }
    }
  elif [ -f "$mwm_target" ] && managed_block_has_valid_block "$mwm_target" "$mwm_legacy_begin" "$mwm_legacy_end"; then
    if [ -z "$mwm_previous_hash" ]; then
      [ "$migrate_legacy" = true ] && [ "$allow_unowned_legacy_blocks" = true ] || { echo "Unowned legacy managed markers exist in $mwm_relative." >&2; return 1; }
      write_managed_block_text "$mwm_fragment" "$plan_dir/legacy-current-block" "$mwm_begin" "$mwm_end"
      managed_block_replace_file "$mwm_target" "$plan_dir/legacy-current-block" "$plan_dir/legacy-replaced" "$mwm_legacy_begin" "$mwm_legacy_end" || return 1
      mwm_source=$plan_dir/legacy-replaced
    else
      managed_block_extract_file "$mwm_target" "$plan_dir/legacy-block" "$mwm_legacy_begin" "$mwm_legacy_end" || return 1
      [ "$(sha_file "$plan_dir/legacy-block")" = "$mwm_previous_hash" ] || [ "$owned_modified_policy" = replace ] || { echo "Legacy managed block was modified after installation: $mwm_relative" >&2; return 1; }
      managed_block_remove_file "$mwm_target" "$plan_dir/legacy-removed" "$mwm_legacy_begin" "$mwm_legacy_end" "$mwm_previous_sep" "$([ "$owned_modified_policy" = replace ] && printf true || printf false)" || return 1
      mwm_source=$plan_dir/legacy-removed
    fi
    mwm_migrated=true
  elif [ -n "$mwm_previous_hash" ]; then
    echo "Previously managed block is absent or malformed in $mwm_relative." >&2
    return 1
  elif [ -f "$mwm_target" ] && { grep -F -x "$mwm_legacy_begin" "$mwm_target" >/dev/null 2>&1 || grep -F -x "$mwm_legacy_end" "$mwm_target" >/dev/null 2>&1; }; then
    echo "Legacy managed markers are malformed in $mwm_relative." >&2
    return 1
  fi
  merge_managed_block_text "$mwm_source" "$mwm_fragment" "$mwm_output" "$mwm_meta" "$mwm_begin" "$mwm_end"
  if [ -n "$mwm_previous_hash" ] && { [ "$mwm_migrated" = true ] || managed_block_has_valid_block "$mwm_target" "$mwm_begin" "$mwm_end"; }; then
    if [ -n "$mwm_previous_created" ] && [ -n "$mwm_previous_sep" ]; then
      printf '%s\n%s\n' "$mwm_previous_created" "$mwm_previous_sep" > "$mwm_meta"
    fi
  fi
}
(
  cd "$script_dir" || exit 1
  find templates fragments -type f -print | LC_ALL=C sort > "$plan_dir/payload-actual-paths"
  sed 's/^[0-9a-f][0-9a-f]*  //' payload.sha256 | LC_ALL=C sort > "$plan_dir/payload-manifest-paths"
  cmp -s "$plan_dir/payload-actual-paths" "$plan_dir/payload-manifest-paths" || { echo 'Payload manifest path set mismatch.' >&2; exit 1; }
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -c payload.sha256 >/dev/null; else
    while IFS='  ' read -r expected path; do [ "$(shasum -a 256 "$path" | awk '{print $1}')" = "$expected" ] || exit 1; done < payload.sha256
  fi
) || { echo 'Payload hash integrity validation failed.' >&2; exit 1; }
source_manifest=$plan_dir/source-manifest
build_template_source_manifest "$script_dir" "$selected_profile" "$source_manifest" || { echo 'Could not build expected profile manifest.' >&2; exit 1; }
expected_paths=$plan_dir/expected-managed-paths
awk -F '|' '{print $1}' "$source_manifest" > "$expected_paths"
{
  cat "$expected_paths"
  printf '%s\n' .gitattributes .gitignore AGENTS.md "$state_path"
  awk -F '|' '{print $1}' "$previous_files"
  awk -F '|' '{print $1}' "$previous_blocks"
} | LC_ALL=C sort -u > "$plan_dir/all-destinations"
while IFS= read -r destination_rel; do
  assert_safe_destination_path "$target_root" "$destination_rel" || { echo "Unsafe target path or object type: $destination_rel" >&2; exit 1; }
done < "$plan_dir/all-destinations"
while IFS='|' read -r rel src; do
  mkdir -p "$plan_dir/$(dirname "$rel")"
  render_file "$src" "$plan_dir/$rel"
done < "$source_manifest"
render_file "$script_dir/fragments/gitignore.txt" "$plan_dir/.gitignore.fragment"
merge_with_metadata "$target_root/.gitignore" "$plan_dir/.gitignore.fragment" "$plan_dir/.gitignore" "$plan_dir/.gitignore.meta" "$begin_marker" "$end_marker"
write_managed_block_text "$plan_dir/.gitignore.fragment" "$plan_dir/.gitignore.block" "$begin_marker" "$end_marker"
gitignore_block_hash=$(sha_file "$plan_dir/.gitignore.block")
gitignore_created=$(sed -n '1p' "$plan_dir/.gitignore.meta"); gitignore_sep=$(sed -n '2p' "$plan_dir/.gitignore.meta")
rm -f "$plan_dir/.gitignore.fragment" "$plan_dir/.gitignore.block" "$plan_dir/.gitignore.meta"
render_file "$script_dir/fragments/gitattributes.txt" "$plan_dir/.gitattributes.fragment"
merge_with_metadata "$target_root/.gitattributes" "$plan_dir/.gitattributes.fragment" "$plan_dir/.gitattributes" "$plan_dir/.gitattributes.meta" "$begin_marker" "$end_marker"
write_managed_block_text "$plan_dir/.gitattributes.fragment" "$plan_dir/.gitattributes.block" "$begin_marker" "$end_marker"
gitattributes_block_hash=$(sha_file "$plan_dir/.gitattributes.block")
gitattributes_created=$(sed -n '1p' "$plan_dir/.gitattributes.meta"); gitattributes_sep=$(sed -n '2p' "$plan_dir/.gitattributes.meta")
rm -f "$plan_dir/.gitattributes.fragment" "$plan_dir/.gitattributes.block" "$plan_dir/.gitattributes.meta"
render_file "$script_dir/fragments/agents.md" "$plan_dir/AGENTS.md.fragment"
merge_with_metadata "$target_root/AGENTS.md" "$plan_dir/AGENTS.md.fragment" "$plan_dir/AGENTS.md" "$plan_dir/AGENTS.md.meta" "$agents_begin_marker" "$agents_end_marker"
write_managed_block_text "$plan_dir/AGENTS.md.fragment" "$plan_dir/AGENTS.md.block" "$agents_begin_marker" "$agents_end_marker"
agents_block_hash=$(sha_file "$plan_dir/AGENTS.md.block")
agents_created=$(sed -n '1p' "$plan_dir/AGENTS.md.meta"); agents_sep=$(sed -n '2p' "$plan_dir/AGENTS.md.meta")
rm -f "$plan_dir/AGENTS.md.fragment" "$plan_dir/AGENTS.md.block" "$plan_dir/AGENTS.md.meta"
ownership_manifest_rel=.qbit-toolkit/codex-ai-tooling/manifest.json
observed_unowned=$plan_dir/observed-unowned
: > "$observed_unowned"
while IFS= read -r rel; do
  [ "$rel" = "$ownership_manifest_rel" ] && continue
  destination=$target_root/$rel
  prior=$(awk -F '|' -v path="$rel" '$1==path {print $2; exit}' "$previous_files")
  if [ "$adopt_matching" = false ] && [ -z "$prior" ] && [ -f "$destination" ] && cmp -s "$plan_dir/$rel" "$destination"; then printf '%s\n' "$rel" >> "$observed_unowned"; fi
done < "$expected_paths"
owned_expected_paths=$plan_dir/owned-expected-paths
grep -F -x -v -f "$observed_unowned" "$expected_paths" > "$owned_expected_paths" || true
payload_digest_lines=$plan_dir/payload-digest-lines
: > "$payload_digest_lines"
while IFS= read -r rel; do
  [ "$rel" = "$ownership_manifest_rel" ] && continue
  printf '%s\t%s\n' "$rel" "$(sha_file "$plan_dir/$rel")" >> "$payload_digest_lines"
done < "$expected_paths"
printf '%s\t%s\n' .gitattributes "$gitattributes_block_hash" .gitignore "$gitignore_block_hash" AGENTS.md "$agents_block_hash" >> "$payload_digest_lines"
payload_manifest_sha256=$(sha_file "$payload_digest_lines")
entry_count=$(grep -F -x -v "$ownership_manifest_rel" "$owned_expected_paths" | wc -l | tr -d ' ')
entry_index=0
{
  printf '{\n'
  printf '  "schema_version": "1.0",\n'
  printf '  "installer_version": "%s",\n' "$installer_version"
  printf '  "profile": "%s",\n' "$selected_profile"
  printf '  "target_identity": "%s",\n' "$slug"
  printf '  "payload_manifest_sha256": "%s",\n' "$payload_manifest_sha256"
  printf '  "installed_entries": [\n'
  while IFS= read -r rel; do
    [ "$rel" = "$ownership_manifest_rel" ] && continue
    entry_index=$((entry_index+1))
    executable=false; case "$rel" in *.sh) executable=true ;; esac
    hash=$(sha_file "$plan_dir/$rel")
    printf '    {"relative_path": %s, "object_type": "file", "ownership_type": "installer-owned", "expected_sha256": "%s", "installed_sha256": "%s", "payload_version": "%s", "created_by_installer": true, "adopted_identical_unowned": false, "replaced_existing_owned": false, "backup_reference": null, "executable": %s, "expected_text_encoding": "utf-8", "expected_line_endings": "lf"}' "$(json_quote "$rel")" "$hash" "$hash" "$installer_version" "$executable"
    [ "$entry_index" -lt "$entry_count" ] && printf ','
    printf '\n'
  done < "$owned_expected_paths"
  printf '  ],\n'
  printf '  "managed_blocks": [\n'
  printf '    {"relative_path": ".gitattributes", "sha256": "%s"},\n' "$gitattributes_block_hash"
  printf '    {"relative_path": ".gitignore", "sha256": "%s"},\n' "$gitignore_block_hash"
  printf '    {"relative_path": "AGENTS.md", "sha256": "%s"}\n' "$agents_block_hash"
  printf '  ],\n'
  printf '  "generated_state_entries": ["backups", "lock.json", "recovery", "transactions"],\n'
  printf '  "original_state_records": [\n'
  observed_count=$(wc -l < "$observed_unowned" | tr -d ' ')
  observed_index=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    observed_index=$((observed_index+1))
    printf '    {"relative_path": %s, "ownership_type": "observed-identical-unowned", "sha256": "%s"}' "$(json_quote "$rel")" "$(sha_file "$plan_dir/$rel")"
    [ "$observed_index" -lt "$observed_count" ] && printf ','
    printf '\n'
  done < "$observed_unowned"
  printf '  ],\n'
  printf '  "last_successful_operation": "%s"\n' "${QBIT_TOOLKIT_OPERATION:-install}"
  printf '}\n'
} > "$plan_dir/$ownership_manifest_rel"
mkdir -p "$plan_dir/$(dirname "$state_path")"
installed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
if [ -s "$previous_metadata" ]; then installed_at=$(metadata_value installedAtUtc); fi
installed_paths=$plan_dir/installed-paths
installed_unsorted=$plan_dir/installed-paths-unsorted
cat "$owned_expected_paths" > "$installed_unsorted"
printf '%s\n' .gitignore .gitattributes AGENTS.md "$state_path" >> "$installed_unsorted"
LC_ALL=C sort "$installed_unsorted" > "$installed_paths"
rm -f "$installed_unsorted"
write_json_array() {
  wja_file=$1; wja_count=$(wc -l < "$wja_file" | tr -d ' '); wja_index=0
  while IFS= read -r wja_value; do
    wja_index=$((wja_index+1)); printf '    %s' "$(json_quote "$wja_value")"; [ "$wja_index" -lt "$wja_count" ] && printf ','; printf '\n'
  done < "$wja_file"
}
origins_file=$plan_dir/origins
cp "$normalized_origins_file" "$origins_file"
{
  printf '{\n  "schemaVersion": %s,\n  "installerId": %s,\n  "installerVersion": %s,\n  "toolkitSchemaVersion": %s,\n  "profile": %s,\n  "projectSlug": %s,\n  "projectDisplayName": %s,\n  "allowedOrigins": [\n' "$(json_quote '1.0')" "$(json_quote "$installer_id")" "$(json_quote "$installer_version")" "$(json_quote '1.0')" "$(json_quote "$selected_profile")" "$(json_quote "$slug")" "$(json_quote "$display_name")"
  write_json_array "$origins_file"
  printf '  ],\n  "dockerImageName": %s,\n  "installedAtUtc": %s,\n  "installedRelativePaths": [\n' "$(json_quote "$docker_image_name")" "$(json_quote "$installed_at")"
  write_json_array "$installed_paths"
  printf '  ],\n  "managedFiles": {\n'
  managed_count=$(wc -l < "$owned_expected_paths" | tr -d ' '); managed_index=0
  while IFS= read -r rel; do managed_index=$((managed_index+1)); printf '    %s: %s' "$(json_quote "$rel")" "$(json_quote "$(sha_file "$plan_dir/$rel")")"; [ "$managed_index" -lt "$managed_count" ] && printf ','; printf '\n'; done < "$owned_expected_paths"
  printf '  },\n  "managedBlocks": {\n'
  printf '    ".gitattributes": {\n      "sha256": "%s",\n      "createdFile": %s,\n      "insertedSeparatorLfCount": %s\n    },\n' "$gitattributes_block_hash" "$gitattributes_created" "$gitattributes_sep"
  printf '    ".gitignore": {\n      "sha256": "%s",\n      "createdFile": %s,\n      "insertedSeparatorLfCount": %s\n    },\n' "$gitignore_block_hash" "$gitignore_created" "$gitignore_sep"
  printf '    "AGENTS.md": {\n      "sha256": "%s",\n      "createdFile": %s,\n      "insertedSeparatorLfCount": %s\n    }\n' "$agents_block_hash" "$agents_created" "$agents_sep"
  printf '  },\n  "stateFile": %s\n}\n' "$(json_quote "$state_path")"
} > "$plan_dir/$state_path"

operations=$plan_dir/operations
stale_paths=$plan_dir/stale-paths
: > "$operations"; : > "$stale_paths"
previous_hash(){ awk -F '|' -v path="$1" '$1==path {print $2; exit}' "$previous_files"; }
is_expected_path(){ grep -F -x "$1" "$expected_paths" >/dev/null 2>&1; }
while IFS= read -r rel; do
  destination=$target_root/$rel
  [ ! -d "$destination" ] || { echo "Cannot overwrite directory: $rel" >&2; exit 1; }
  if [ -f "$destination" ] && cmp -s "$plan_dir/$rel" "$destination"; then continue; fi
  if [ -f "$destination" ]; then
    prior=$(previous_hash "$rel")
    if [ -z "$prior" ] && [ "$rel" = "$legacy_variant_path" ] && [ "$(sha_file "$destination")" = "$legacy_variant_hash" ]; then
      :
    elif [ -z "$prior" ]; then
      echo "Conflict at $rel. Existing content is unowned and differs from the payload." >&2
      exit 1
    elif [ "$(sha_file "$destination")" = "$prior" ]; then :
    elif [ "$owned_modified_policy" != replace ]; then
      echo "Conflict at $rel. Installer-owned content was modified; use --owned-modified replace to back it up and replace it." >&2
      exit 1
    fi
    printf 'update|%s\n' "$rel" >> "$operations"
  else
    printf 'create|%s\n' "$rel" >> "$operations"
  fi
done < "$expected_paths"
for rel in .gitattributes .gitignore AGENTS.md; do
  destination=$target_root/$rel
  [ ! -d "$destination" ] || { echo "Cannot overwrite directory: $rel" >&2; exit 1; }
  if [ -f "$destination" ] && cmp -s "$plan_dir/$rel" "$destination"; then continue; fi
  printf '%s|%s\n' "$([ -f "$destination" ] && printf update || printf create)" "$rel" >> "$operations"
done
if ! cmp -s "$plan_dir/$state_path" "$target_root/$state_path" 2>/dev/null; then printf '%s|%s\n' "$([ -f "$target_root/$state_path" ] && printf update || printf create)" "$state_path" >> "$operations"; fi
while IFS='|' read -r rel hash; do
  is_expected_path "$rel" && continue
  destination=$target_root/$rel
  [ -f "$destination" ] || { echo "State-declared stale managed file is missing or is not a regular file: $rel" >&2; exit 1; }
  if [ "$(sha_file "$destination")" != "$hash" ] && [ "$owned_modified_policy" != replace ]; then echo "Stale managed file was modified after installation: $rel. Use owned-modified=replace." >&2; exit 1; fi
  printf '%s\n' "$rel" >> "$stale_paths"
  printf 'remove|%s\n' "$rel" >> "$operations"
done < "$previous_files"

echo "Installer: $installer_id $installer_version"
echo "Target: $target_root"
echo "Profile: $selected_profile"
echo "Project slug: $slug"
echo "Allowed origins: $normalized_origins"
echo 'Planned operations:'
if [ -s "$operations" ]; then while IFS='|' read -r action rel; do echo "  $action $rel"; done < "$operations"; else echo '  no file changes'; fi
[ "$dry_run" = true ] && { echo 'DryRun completed; no files were written.'; exit 0; }
if [ ! -s "$operations" ] && [ ! -s "$stale_paths" ]; then
  echo 'codex-ai-tooling installation completed.'
  exit 0
fi
runtime_root=$target_root/.qbit-toolkit/codex-ai-tooling
transactions_root=$runtime_root/transactions
backups_root=$runtime_root/backups
recovery_root=$runtime_root/recovery
lock_file=$runtime_root/lock.json
host_identity=$(hostname 2>/dev/null || uname -n)
mkdir -p "$transactions_root" "$backups_root" "$recovery_root" || { echo 'Could not create installer transaction state.' >&2; exit 1; }
stale_recovery=false
if [ -f "$lock_file" ]; then
  lock_host=$(sed -n 's/^  "host_identity": "\(.*\)",$/\1/p' "$lock_file")
  lock_pid=$(sed -n 's/^  "process_id": \([0-9][0-9]*\),$/\1/p' "$lock_file")
  if [ "$lock_host" = "$host_identity" ] && [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
    stale_name=stale-lock-$(date -u '+%Y%m%dT%H%M%SZ')-$$.json
    mv "$lock_file" "$recovery_root/$stale_name" || { echo 'Uncertain installer lock could not be recovered.' >&2; exit 1; }
    stale_recovery=true
  else
    echo 'Active installer lock or uncertain cross-host lock detected.' >&2
    exit 1
  fi
fi
for recovery_transaction in "$transactions_root"/*; do
    [ -d "$recovery_transaction" ] || continue
    recovery_journal=$recovery_transaction/journal.json
    grep -Fq '"status": "active"' "$recovery_journal" 2>/dev/null || continue
    recovery_id=$(basename "$recovery_transaction")
    recovery_backup=$backups_root/$recovery_id
    recovery_ok=true
    if [ -f "$recovery_transaction/backed" ]; then
      while IFS= read -r recovery_rel; do
        [ -n "$recovery_rel" ] || continue
        mkdir -p "$(dirname "$target_root/$recovery_rel")" && cp "$recovery_backup/$recovery_rel" "$target_root/$recovery_rel" || recovery_ok=false
      done < "$recovery_transaction/backed"
    fi
    if [ -f "$recovery_transaction/created" ]; then
      while IFS= read -r recovery_rel; do [ -n "$recovery_rel" ] && rm -f "$target_root/$recovery_rel" || true; done < "$recovery_transaction/created"
    fi
    [ "$recovery_ok" = true ] || { echo 'Recovery from an incomplete installer transaction failed.' >&2; exit 1; }
    sed 's/"status": "active"/"status": "recovered"/' "$recovery_journal" > "$recovery_transaction/journal.tmp" || { echo 'Recovery journal update failed.' >&2; exit 1; }
    mv "$recovery_transaction/journal.tmp" "$recovery_journal" || { echo 'Recovery journal update failed.' >&2; exit 1; }
done
if ! (set -C; : > "$lock_file") 2>/dev/null; then echo 'Active installer lock detected.' >&2; exit 1; fi
transaction_id=$(date -u '+%Y%m%dT%H%M%SZ')-$$
transaction_dir=$transactions_root/$transaction_id
backup_root=.qbit-toolkit/codex-ai-tooling/backups/$transaction_id
mkdir -p "$transaction_dir" "$target_root/$backup_root" || { rm -f "$lock_file"; echo 'Could not initialize installer transaction.' >&2; exit 1; }
backed=$transaction_dir/backed
created=$transaction_dir/created
: > "$backed"; : > "$created"
{
  printf '{\n'
  printf '  "schema_version": "1.0",\n'
  printf '  "transaction_id": "%s",\n' "$transaction_id"
  printf '  "operation": "%s",\n' "${QBIT_TOOLKIT_OPERATION:-install}"
  printf '  "status": "active"\n'
  printf '}\n'
} > "$transaction_dir/journal.json"
{
  printf '{\n'
  printf '  "schema_version": "1.0",\n'
  printf '  "operation": "%s",\n' "${QBIT_TOOLKIT_OPERATION:-install}"
  printf '  "process_id": %s,\n' "$$"
  printf '  "host_identity": "%s",\n' "$host_identity"
  printf '  "start_time": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '  "transaction_id": "%s"\n' "$transaction_id"
  printf '}\n'
} > "$lock_file"
cp "$operations" "$transaction_dir/operations"
backup_target(){ bt_rel=$1; bt_src=$target_root/$bt_rel; [ -f "$bt_src" ] || return 0; mkdir -p "$target_root/$backup_root/$(dirname "$bt_rel")" || return 1; cp "$bt_src" "$target_root/$backup_root/$bt_rel" || return 1; printf '%s\n' "$bt_rel" >> "$backed"; }
write_target(){
  wt_rel=$1
  wt_dst=$target_root/$wt_rel
  wt_parent=$(dirname "$wt_dst")
  [ -f "$wt_dst" ] || printf '%s\n' "$wt_rel" >> "$created"
  mkdir -p "$wt_parent" || return 1
  wt_tmp=$(mktemp "$wt_dst.qbit-tmp.XXXXXX") || return 1
  cp "$plan_dir/$wt_rel" "$wt_tmp" || { rm -f "$wt_tmp"; return 1; }
  case "$wt_rel" in *.sh) chmod 0755 "$wt_tmp" || { rm -f "$wt_tmp"; return 1; } ;; *) chmod 0644 "$wt_tmp" || { rm -f "$wt_tmp"; return 1; } ;; esac
  if command -v sync >/dev/null 2>&1; then sync -f "$wt_tmp" 2>/dev/null || { rm -f "$wt_tmp"; return 1; }; fi
  mv -f "$wt_tmp" "$wt_dst" || { rm -f "$wt_tmp"; return 1; }
  if command -v sync >/dev/null 2>&1; then sync -f "$wt_parent" 2>/dev/null || return 1; fi
}
remove_empty_parents(){ rep_rel=$1; rep_dir=$(dirname "$target_root/$rep_rel"); while [ "$rep_dir" != "$target_root" ]; do rmdir "$rep_dir" 2>/dev/null || break; rep_dir=$(dirname "$rep_dir"); done; }
rollback_transaction(){
  [ -z "${QBIT_TOOLKIT_TEST_FAIL_ROLLBACK:-}" ] || return 1
  while IFS= read -r rb_rel; do [ -n "$rb_rel" ] || continue; mkdir -p "$(dirname "$target_root/$rb_rel")"; cp "$target_root/$backup_root/$rb_rel" "$target_root/$rb_rel" || return 1; done < "$backed"
  while IFS= read -r rb_rel; do [ -n "$rb_rel" ] || continue; rm -f "$target_root/$rb_rel"; remove_empty_parents "$rb_rel"; done < "$created"
  sed 's/"status": "active"/"status": "rolled_back"/' "$transaction_dir/journal.json" > "$transaction_dir/journal.tmp" || return 1
  mv "$transaction_dir/journal.tmp" "$transaction_dir/journal.json" || return 1
  rm -f "$lock_file"
  return 0
}
apply_transaction(){
  while IFS='|' read -r action rel; do case "$action" in update|remove) backup_target "$rel" || return 1 ;; esac; done < "$operations"
  while IFS='|' read -r action rel; do [ "$action" = remove ] && continue; [ "$rel" = "$state_path" ] && continue; write_target "$rel" || return 1; done < "$operations"
  while IFS= read -r rel; do [ -n "$rel" ] || continue; rm -f "$target_root/$rel" || return 1; done < "$stale_paths"
  [ -z "${QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES:-}" ] || return 1
  if grep -F -x "create|$state_path" "$operations" >/dev/null 2>&1 || grep -F -x "update|$state_path" "$operations" >/dev/null 2>&1; then write_target "$state_path" || return 1; fi
  current_git_index=$(git -C "$target_root" ls-files --stage) || return 1
  [ "$current_git_index" = "$initial_git_index" ] || { echo 'Git index changed during installer mutation.' >&2; return 1; }
  while IFS= read -r rel; do [ -n "$rel" ] && remove_empty_parents "$rel"; done < "$stale_paths"
}
if ! apply_transaction; then rollback_transaction || { echo 'Installation transaction and rollback both failed.' >&2; exit 1; }; echo 'Injected or file-system installation failure; rollback succeeded.' >&2; exit 1; fi
sed 's/"status": "active"/"status": "committed"/' "$transaction_dir/journal.json" > "$transaction_dir/journal.tmp" || { echo 'Could not commit transaction journal.' >&2; exit 1; }
mv "$transaction_dir/journal.tmp" "$transaction_dir/journal.json" || { echo 'Could not commit transaction journal.' >&2; exit 1; }
rm -f "$lock_file"
[ "$skip_bootstrap" = true ] || "$target_root/.ai/scripts/bootstrap.sh"
[ "$skip_doctor" = true ] || "$target_root/.ai/scripts/doctor.sh"
echo 'codex-ai-tooling installation completed.'
