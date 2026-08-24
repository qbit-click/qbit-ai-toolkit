#!/usr/bin/env bash
set -u

installer_version=1.1.1
schema_version=1.0
operation=install
target=
profile=auto
output_format=text
dry_run=false
owned_modified=fail
adopt_matching=false
migrate_legacy=false
engine_args=()

json_escape() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

usage() {
  printf '%s\n' 'Usage: install.sh --operation plan|install|update|repair|verify|doctor|uninstall --target PATH [--profile auto|generic|typescript|rust] [--format text|json] [--non-interactive] [--dry-run] [--owned-modified fail|replace] [--adopt-matching] [--migrate-legacy]' >&2
}

argument_error() {
  local message=${1:-Invalid arguments.}
  usage
  if [[ "$output_format" == json ]]; then
    printf '{"schema_version":"1.0","installer_version":"%s","operation":"%s","target":"%s","profile":"%s","dry_run":%s,"success":false,"exit_code":2,"detected_state":"unknown","planned_actions":[],"performed_actions":[],"skipped_actions":[],"conflicts":[],"warnings":[],"errors":[{"code":"QBIT-2","category":"arguments","message":"%s","recoverable":true,"remediation":"Correct the command arguments and retry."}],"rollback":{"attempted":false,"success":null,"actions":[],"errors":[]},"verification":{"performed":false,"success":null,"checks":[]}}\n' "$installer_version" "$(json_escape "$operation")" "$(json_escape "$target")" "$(json_escape "$profile")" "$dry_run" "$(json_escape "$message")"
  fi
  exit 2
}

while (($#)); do
  case "$1" in
    --operation) (($# >= 2)) || argument_error 'Missing operation value.'; operation=$2; shift 2 ;;
    --target) (($# >= 2)) || argument_error 'Missing target value.'; target=$2; engine_args+=(--target "$target"); shift 2 ;;
    --profile) (($# >= 2)) || argument_error 'Missing profile value.'; profile=$2; engine_args+=(--profile "$profile"); shift 2 ;;
    --format|--output-format) (($# >= 2)) || argument_error 'Missing output format value.'; output_format=$2; shift 2 ;;
    --non-interactive) shift ;;
    --dry-run) dry_run=true; shift ;;
    --owned-modified) (($# >= 2)) || argument_error 'Missing owned-modified value.'; owned_modified=$2; shift 2 ;;
    --adopt-matching) adopt_matching=true; shift ;;
    --migrate-legacy) migrate_legacy=true; shift ;;
    --project-slug|--project-display-name|--allowed-origin)
      (($# >= 2)) || argument_error "Missing value for $1."; engine_args+=("$1" "$2"); shift 2 ;;
    --skip-bootstrap|--skip-doctor) shift ;;
    -h|--help) usage; exit 0 ;;
    *) argument_error "Unknown argument: $1" ;;
  esac
done

[[ -n "$target" ]] || argument_error 'Target is required.'
case "$operation" in plan|install|update|repair|verify|doctor|uninstall) ;; *) argument_error 'Invalid operation.' ;; esac
case "$profile" in auto|generic|typescript|rust) ;; *) argument_error 'Invalid profile.' ;; esac
case "$output_format" in text|json) ;; *) argument_error 'Invalid output format.' ;; esac
case "$owned_modified" in fail|replace) ;; *) argument_error 'Invalid owned-modified policy.' ;; esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export QBIT_TOOLKIT_OPERATION=$operation
work=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-lifecycle)
trap 'rm -rf "$work"' EXIT HUP INT TERM
stdout_file=$work/stdout
stderr_file=$work/stderr
actions_file=$work/actions
: >"$stdout_file"
: >"$stderr_file"
: >"$actions_file"

emit_string_array() {
  local file=$1 first=true value
  printf '['
  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    [[ "$first" == true ]] || printf ','
    printf '"%s"' "$(json_escape "$value")"
    first=false
  done <"$file"
  printf ']'
}

classify_failure() {
  local text
  text=$(tr '[:upper:]' '[:lower:]' <"$stderr_file")
  case "$text" in
    *'target directory does not exist'*|*'target must be a git work tree'*|*'target must be the git work tree root'*|*'refusing to target'*) printf 3 ;;
    *'conflict at'*|*'was modified'*|*'managed block'*'modified'*|*'managed block marker'*|*'managed markers'*|*'previously managed block'*|*'no recognized historical'*) printf 4 ;;
    *'unsafe'*|*'cannot overwrite directory'*|*'ownership metadata is invalid'*|*'state path is not a regular file'*|*'hash mismatch'*|*'hash integrity'*) printf 5 ;;
    *'rollback succeeded'*) printf 6 ;;
    *'rollback both failed'*|*'rollback had errors'*|*'recovery'*) printf 7 ;;
    *'active installer lock'*|*'uncertain installer lock'*) printf 9 ;;
    *'docker cli is unavailable'*|*'compose'*'required'*|*'missing mandatory prerequisite'*) printf 10 ;;
    *) printf 12 ;;
  esac
}

canonical_target=$target
if [[ -n "$target" && -d "$target" ]]; then canonical_target=$(cd -- "$target" 2>/dev/null && pwd -P || printf '%s' "$target"); fi
detected_state=absent
state_path=.qbit/toolkit/installed/codex-ai-tooling.json
[[ -n "$canonical_target" && -f "$canonical_target/$state_path" ]] && detected_state=installed

code=0
shared_engine_args=(--owned-modified "$owned_modified")
[[ "$adopt_matching" == true ]] && shared_engine_args+=(--adopt-matching)
[[ "$migrate_legacy" == true ]] && shared_engine_args+=(--migrate-legacy)
case "$operation" in
  plan)
    "$script_dir/lib/install-engine.sh" "${engine_args[@]}" "${shared_engine_args[@]}" --dry-run --skip-bootstrap --skip-doctor >"$stdout_file" 2>"$stderr_file" || code=$?
    ;;
  install)
    extra=("${shared_engine_args[@]}")
    [[ "$dry_run" == true ]] && extra+=(--dry-run)
    "$script_dir/lib/install-engine.sh" "${engine_args[@]}" "${extra[@]}" --skip-bootstrap --skip-doctor >"$stdout_file" 2>"$stderr_file" || code=$?
    ;;
  update|repair)
    if [[ "$detected_state" != installed ]]; then
      printf '%s\n' "$operation requires a valid ownership manifest." >"$stderr_file"
      code=5
    else
      extra=("${shared_engine_args[@]}")
      [[ "$dry_run" == true ]] && extra+=(--dry-run)
      "$script_dir/lib/install-engine.sh" "${engine_args[@]}" "${extra[@]}" --skip-bootstrap --skip-doctor >"$stdout_file" 2>"$stderr_file" || code=$?
    fi
    ;;
  verify)
    "$script_dir/verify.sh" --target "$target" >"$stdout_file" 2>"$stderr_file" || code=8
    ;;
  doctor)
    if "$script_dir/verify.sh" --target "$target" >>"$stdout_file" 2>>"$stderr_file"; then
      doctor_path=$canonical_target/.ai/scripts/doctor.sh
      if [[ -f "$doctor_path" ]]; then
        bash "$doctor_path" >>"$stdout_file" 2>>"$stderr_file" || code=8
      else
        printf '%s\n' 'Installed Doctor entrypoint is missing.' >>"$stderr_file"
        code=8
      fi
    else
      code=8
    fi
    ;;
  uninstall)
    extra=()
    [[ "$dry_run" == true ]] && extra+=(--dry-run)
    extra+=(--owned-modified "$owned_modified")
    "$script_dir/uninstall.sh" --target "$target" "${extra[@]}" >"$stdout_file" 2>"$stderr_file" || code=$?
    ;;
esac

if [[ "$code" -eq 1 ]]; then code=$(classify_failure); fi
awk '/^  (create|update|remove) / { action=$1; $1=""; sub(/^ /,""); print action " " $0 }
     /^  remove managed block / { sub(/^  /,""); print }
     /^  remove / { sub(/^  /,""); print }' "$stdout_file" | LC_ALL=C sort -u >"$actions_file"

if [[ "$output_format" == text ]]; then
  cat "$stdout_file"
  cat "$stderr_file" >&2
  exit "$code"
fi

cat "$stderr_file" >&2
success=false
[[ "$code" -eq 0 ]] && success=true
performed_file=$work/performed
: >"$performed_file"
if [[ "$success" == true && "$dry_run" == false && "$operation" != plan && "$operation" != verify && "$operation" != doctor ]]; then
  cp "$actions_file" "$performed_file"
fi
error_message=
if [[ "$code" -ne 0 ]]; then error_message=$(tr '\n' ' ' <"$stderr_file" | sed 's/[[:space:]][[:space:]]*/ /g; s/[[:space:]]$//'); fi
printf '{'
printf '"schema_version":"%s",' "$schema_version"
printf '"installer_version":"%s",' "$installer_version"
printf '"operation":"%s",' "$(json_escape "$operation")"
printf '"target":"%s",' "$(json_escape "$canonical_target")"
printf '"profile":"%s",' "$(json_escape "$profile")"
printf '"dry_run":%s,' "$([[ "$dry_run" == true || "$operation" == plan ]] && printf true || printf false)"
printf '"success":%s,"exit_code":%s,' "$success" "$code"
printf '"detected_state":"%s",' "$detected_state"
printf '"planned_actions":'; emit_string_array "$actions_file"; printf ','
printf '"performed_actions":'; emit_string_array "$performed_file"; printf ','
printf '"skipped_actions":[],'
if [[ "$code" -eq 4 ]]; then printf '"conflicts":["%s"],' "$(json_escape "$error_message")"; else printf '"conflicts":[],'; fi
printf '"warnings":[],'
if [[ "$code" -eq 0 ]]; then
  printf '"errors":[],'
else
  printf '"errors":[{"code":"QBIT-%s","category":"operation","message":"%s","recoverable":%s,"remediation":"Review stderr, resolve the reported condition, and retry."}],' "$code" "$(json_escape "$error_message")" "$([[ "$code" -eq 5 || "$code" -eq 7 ]] && printf false || printf true)"
fi
rollback_attempted=false
rollback_success=null
[[ "$code" -eq 6 ]] && { rollback_attempted=true; rollback_success=true; }
[[ "$code" -eq 7 ]] && { rollback_attempted=true; rollback_success=false; }
printf '"rollback":{"attempted":%s,"success":%s,"actions":[],"errors":[]},' "$rollback_attempted" "$rollback_success"
verification_performed=false
verification_success=null
if [[ "$operation" == verify || "$operation" == doctor ]]; then verification_performed=true; verification_success=$success; fi
printf '"verification":{"performed":%s,"success":%s,"checks":[]}' "$verification_performed" "$verification_success"
printf '}\n'
exit "$code"
