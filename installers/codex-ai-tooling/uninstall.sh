#!/usr/bin/env sh
set -eu
state_path=.qbit/toolkit/installed/codex-ai-tooling.json
target=; dry_run=false; remove_docker_image=false; owned_modified=fail
while [ "$#" -gt 0 ]; do case "$1" in --target) target=${2:-}; shift 2 ;; --dry-run) dry_run=true; shift ;; --owned-modified) owned_modified=${2:-}; shift 2 ;; --remove-docker-image) remove_docker_image=true; shift ;; -h|--help) echo 'Usage: uninstall.sh --target <path> [--dry-run] [--owned-modified fail|replace] [--remove-docker-image]'; exit 0 ;; *) echo 'Usage: uninstall.sh --target <path> [--dry-run] [--owned-modified fail|replace]' >&2; exit 2 ;; esac; done
[ -n "$target" ] || { echo 'Target is required.' >&2; exit 2; }
case "$owned_modified" in fail|replace) ;; *) echo 'Invalid owned-modified policy.' >&2; exit 2 ;; esac
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/lib/installer.sh"
root=$(CDPATH= cd -- "$target" && pwd)
state_file=$root/$state_path
[ -f "$state_file" ] || { echo "Missing state file: $state_path" >&2; exit 1; }
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-uninstall)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sha_file(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
safe_state_path(){ case "$1" in ""|/*|*../*|../*|*'/..'|*'\'*) return 1 ;; esac; return 0; }
block_markers(){ if [ "$1" = AGENTS.md ]; then printf '%s\n%s\n' "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; else printf '%s\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; fi; }
backup_file(){ rel=$1; [ -f "$root/$rel" ] || return 0; mkdir -p "$backup_root/$(dirname "$rel")"; cp "$root/$rel" "$backup_root/$rel"; }

if [ -z "$state_file" ] || ! parse_and_validate_state "$state_file" "$tmp/managed-files" "$tmp/managed-blocks" "$tmp/installed-paths" "$tmp/metadata" "$script_dir"; then
  echo 'State ownership metadata is invalid.' >&2
  exit 1
fi
validate_portable_ownership_state "$root" "$tmp/managed-files" "$tmp/managed-blocks" || { echo 'Portable ownership manifest does not match compatibility ownership state.' >&2; exit 1; }
: > "$tmp/retained"

while IFS='|' read -r rel hash; do
  safe_state_path "$rel" || { echo "Unsafe managed file path: $rel" >&2; exit 1; }
  assert_safe_destination_path "$root" "$rel" || { echo "Unsafe managed file destination: $rel" >&2; exit 1; }
  if [ ! -f "$root/$rel" ]; then printf '%s|missing managed file\n' "$rel" >> "$tmp/retained"; continue; fi
  actual=$(sha_file "$root/$rel")
  if [ "$actual" != "$hash" ] && [ "$owned_modified" != replace ]; then printf '%s|user-modified managed file\n' "$rel" >> "$tmp/retained"; continue; fi
  printf '%s\n' "$rel" >> "$tmp/files"
done < "$tmp/managed-files"

while IFS='|' read -r rel hash created sep; do
  safe_state_path "$rel" || { echo "Unsafe managed block path: $rel" >&2; exit 1; }
  assert_safe_destination_path "$root" "$rel" || { echo "Unsafe managed block destination: $rel" >&2; exit 1; }
  printf '%s\n' "$hash" | grep -Eq '^[0-9a-f]{64}$' || { echo "Invalid managed block sha256: $rel" >&2; exit 1; }
  case "$created" in true|false) ;; *) echo "Invalid managed block createdFile: $rel" >&2; exit 1 ;; esac
  case "$sep" in 0|1|2) ;; *) echo "Invalid managed block separator count: $rel" >&2; exit 1 ;; esac
  if [ ! -f "$root/$rel" ]; then printf '%s|missing managed-block file\n' "$rel" >> "$tmp/retained"; continue; fi
  markers=$(block_markers "$rel"); begin=$(printf '%s\n' "$markers" | sed -n '1p'); end=$(printf '%s\n' "$markers" | sed -n '2p')
  if ! managed_block_extract_file "$root/$rel" "$tmp/block" "$begin" "$end"; then printf '%s|malformed managed block\n' "$rel" >> "$tmp/retained"; continue; fi
  actual=$(sha_file "$tmp/block")
  if [ "$actual" != "$hash" ] && [ "$owned_modified" != replace ]; then printf '%s|user-modified managed block\n' "$rel" >> "$tmp/retained"; continue; fi
  if ! managed_block_remove_file "$root/$rel" "$tmp/remove-test" "$begin" "$end" "$sep" "$([ "$owned_modified" = replace ] && printf true || printf false)"; then printf '%s|managed block separator mismatch\n' "$rel" >> "$tmp/retained"; continue; fi
  printf '%s|%s|%s\n' "$rel" "$created" "$sep" >> "$tmp/blocks"
done < "$tmp/managed-blocks"

echo 'Planned uninstall operations:'
while IFS='|' read -r rel created sep; do [ -n "$rel" ] && echo "  remove managed block $rel"; done < "$tmp/blocks"
while IFS= read -r rel; do [ -n "$rel" ] && echo "  remove $rel"; done < "$tmp/files"
while IFS='|' read -r rel reason; do [ -n "$rel" ] && echo "  retain $rel ($reason)"; done < "$tmp/retained"
if [ -s "$tmp/retained" ]; then echo "  retain $state_path (ownership evidence remains required)"; else echo "  remove $state_path"; fi
[ "$dry_run" = true ] && { echo 'DryRun completed; no files were changed.'; [ ! -s "$tmp/retained" ] || exit 4; exit 0; }
[ ! -s "$tmp/retained" ] || { echo 'Uninstall retained modified or uncertain content; no target mutation was performed.' >&2; exit 4; }

runtime_root=$root/.qbit-toolkit/codex-ai-tooling
transactions_root=$runtime_root/transactions
recovery_root=$runtime_root/recovery
transaction_id=uninstall-$(date -u '+%Y%m%dT%H%M%SZ')-$$
transaction_dir=$transactions_root/$transaction_id
backup_root=$runtime_root/backups/$transaction_id
lock_file=$runtime_root/lock.json
host_identity=$(hostname 2>/dev/null || uname -n)
mkdir -p "$transaction_dir" "$backup_root" "$recovery_root"
if [ -f "$lock_file" ]; then
  lock_host=$(sed -n 's/^  "host_identity": "\(.*\)",$/\1/p' "$lock_file")
  lock_pid=$(sed -n 's/^  "process_id": \([0-9][0-9]*\),$/\1/p' "$lock_file")
  if [ "$lock_host" = "$host_identity" ] && [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
    mv "$lock_file" "$recovery_root/stale-lock-$transaction_id.json"
  else
    echo 'Active installer lock or uncertain cross-host lock detected.' >&2
    exit 9
  fi
fi
for recovery_transaction in "$transactions_root"/*; do
  [ -d "$recovery_transaction" ] || continue
  recovery_journal=$recovery_transaction/journal.json
  grep -Fq '"status": "active"' "$recovery_journal" 2>/dev/null || continue
  recovery_id=$(basename "$recovery_transaction")
  recovery_backup=$runtime_root/backups/$recovery_id
  recovery_ok=true
  if [ -f "$recovery_transaction/backed" ]; then
    while IFS= read -r recovery_rel; do
      [ -n "$recovery_rel" ] || continue
      mkdir -p "$(dirname "$root/$recovery_rel")" && cp "$recovery_backup/$recovery_rel" "$root/$recovery_rel" || recovery_ok=false
    done < "$recovery_transaction/backed"
  fi
  if [ -f "$recovery_transaction/created" ]; then
    while IFS= read -r recovery_rel; do [ -n "$recovery_rel" ] && rm -f "$root/$recovery_rel" || true; done < "$recovery_transaction/created"
  fi
  [ "$recovery_ok" = true ] || { echo 'Recovery from an incomplete installer transaction failed.' >&2; exit 7; }
  sed 's/"status": "active"/"status": "recovered"/' "$recovery_journal" > "$recovery_transaction/journal.tmp"
  mv "$recovery_transaction/journal.tmp" "$recovery_journal"
done
if ! (set -C; : > "$lock_file") 2>/dev/null; then echo 'Active installer lock detected.' >&2; exit 9; fi
printf '{\n  "schema_version": "1.0",\n  "operation": "uninstall",\n  "process_id": %s,\n  "host_identity": "%s",\n  "start_time": "%s",\n  "transaction_id": "%s"\n}\n' "$$" "$host_identity" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$transaction_id" > "$lock_file"
printf '{\n  "schema_version": "1.0",\n  "transaction_id": "%s",\n  "operation": "uninstall",\n  "status": "active"\n}\n' "$transaction_id" > "$transaction_dir/journal.json"
: > "$transaction_dir/backed"
while IFS='|' read -r rel created sep; do [ -n "$rel" ] && { backup_file "$rel"; printf '%s\n' "$rel" >> "$transaction_dir/backed"; }; done < "$tmp/blocks"
while IFS= read -r rel; do [ -n "$rel" ] && { backup_file "$rel"; printf '%s\n' "$rel" >> "$transaction_dir/backed"; }; done < "$tmp/files"
if [ ! -s "$tmp/retained" ]; then backup_file "$state_path"; printf '%s\n' "$state_path" >> "$transaction_dir/backed"; fi
rollback_uninstall(){
  rollback_ok=true
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    mkdir -p "$(dirname "$root/$rel")" && cp "$backup_root/$rel" "$root/$rel" || rollback_ok=false
  done < "$transaction_dir/backed"
  [ "$rollback_ok" = true ] || return 1
  sed 's/"status": "active"/"status": "rolled_back"/' "$transaction_dir/journal.json" > "$transaction_dir/journal.tmp" || return 1
  mv "$transaction_dir/journal.tmp" "$transaction_dir/journal.json" || return 1
  rm -f "$lock_file"
}
apply_uninstall(){
  while IFS='|' read -r rel created sep; do
    [ -n "$rel" ] || continue
    markers=$(block_markers "$rel"); begin=$(printf '%s\n' "$markers" | sed -n '1p'); end=$(printf '%s\n' "$markers" | sed -n '2p')
    managed_block_remove_file "$root/$rel" "$tmp/removed" "$begin" "$end" "$sep" false || return 1
    if [ "$created" = true ] && [ ! -s "$tmp/removed" ]; then rm -f "$root/$rel" || return 1; else mv "$tmp/removed" "$root/$rel" || return 1; fi
  done < "$tmp/blocks"
  while IFS= read -r rel; do [ -n "$rel" ] || continue; rm -f "$root/$rel" || return 1; done < "$tmp/files"
  [ -z "${QBIT_TOOLKIT_TEST_FAIL_UNINSTALL:-}" ] || return 1
  if [ ! -s "$tmp/retained" ]; then rm -f "$state_file" || return 1; fi
}
if ! apply_uninstall; then
  rollback_uninstall || { echo 'Uninstall failed and rollback failed; recovery is required.' >&2; exit 7; }
  echo 'Uninstall failed and rollback succeeded.' >&2
  exit 6
fi
sed 's/"status": "active"/"status": "committed"/' "$transaction_dir/journal.json" > "$transaction_dir/journal.tmp"
mv "$transaction_dir/journal.tmp" "$transaction_dir/journal.json"
rm -f "$lock_file"
for dir in .agents/skills/architecture-impact-analysis .agents/skills/browser-verification .agents/skills/external-library-docs .agents/skills/incident-analysis .agents/skills/security-review .agents/skills .agents .ai/scripts .ai/policies .ai/tooling/language-servers .ai/tooling/node .ai/tooling/python .ai/tooling .ai .codex .playwright .serena docs/ai-tooling .qbit/toolkit/installed .qbit/toolkit .qbit; do
  [ -d "$root/$dir" ] && rmdir "$root/$dir" 2>/dev/null || true
done
[ "$remove_docker_image" = true ] && echo 'Docker image removal is not implemented by POSIX uninstaller without general JSON parsing; use PowerShell or remove the project image explicitly.' >&2
echo 'codex-ai-tooling uninstall completed.'
[ ! -s "$tmp/retained" ] || { echo 'Uninstall retained modified or uncertain content and preserved ownership state.' >&2; exit 4; }
