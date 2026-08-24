#!/usr/bin/env bash
set -euo pipefail

installer_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
install="$installer_root/install.sh"
verify="$installer_root/verify.sh"
uninstall="$installer_root/uninstall.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
pass=0
fail=0

ok() { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1" >&2; }
run_test() { local name=$1; shift; if "$@"; then ok "$name"; else bad "$name"; fi; }

new_repo() {
  local name=$1 path="$root/$name"
  git init -b main "$path" >/dev/null
  git -C "$path" config user.name Test
  git -C "$path" config user.email test@example.invalid
  printf '# %s\n' "$name" >"$path/README.md"
  git -C "$path" add README.md
  git -C "$path" commit -m init >/dev/null
  printf '%s\n' "$path"
}

base_args() {
  local repo=$1
  printf '%s\n' --mode member --target "$repo" --project-id demo --project-display-name Demo --repository-id demo-api --context-remote https://github.com/example/demo-ai-context.git --context-branch main
}

test_plan_write_free() {
  local repo before after
  repo=$(new_repo plan-member)
  before=$(git -C "$repo" status --porcelain)
  mapfile -t args < <(base_args "$repo")
  bash "$install" --operation plan "${args[@]}" --format json >/dev/null
  after=$(git -C "$repo" status --porcelain)
  [[ "$before" == "$after" && ! -e "$repo/.qbit/toolkit/installed/ai-context.json" && ! -e "$repo/.ai/context/context.sh" ]]
}

test_install_verify_idempotent() {
  local repo state before after
  repo=$(new_repo member-idempotent)
  mapfile -t args < <(base_args "$repo")
  bash "$install" --operation install "${args[@]}" --format json >/dev/null
  state="$repo/.qbit/toolkit/installed/ai-context.json"
  [[ -f "$state" && -f "$repo/.ai/context/context.ps1" && -f "$repo/.ai/context/context.sh" && -f "$repo/.ai/context/context.py" ]]
  bash "$verify" --target "$repo" --format json >/dev/null
  before=$(sha256sum "$state" | awk '{print $1}')
  sleep 1
  bash "$install" --operation install --target "$repo" --format json >/dev/null
  after=$(sha256sum "$state" | awk '{print $1}')
  [[ "$before" == "$after" ]]
}

test_unowned_conflict() {
  local repo output code
  repo=$(new_repo unowned-conflict)
  mkdir -p "$repo/.ai/context"
  printf 'custom\n' >"$repo/.ai/context/context.sh"
  mapfile -t args < <(base_args "$repo")
  set +e
  output=$(bash "$install" --operation plan "${args[@]}" --format json 2>/dev/null)
  code=$?
  set -e
  [[ $code -eq 4 && "$output" == *'"success":false'* && $(cat "$repo/.ai/context/context.sh") == custom && ! -e "$repo/.qbit/toolkit/installed/ai-context.json" ]]
}

test_matching_requires_adoption() {
  local repo code
  repo=$(new_repo adopt-matching)
  mkdir -p "$repo/.ai/context"
  cp "$installer_root/templates/common/member/context.sh" "$repo/.ai/context/context.sh"
  mapfile -t args < <(base_args "$repo")
  set +e
  bash "$install" --operation plan "${args[@]}" --format json >/dev/null 2>&1
  code=$?
  set -e
  [[ $code -eq 4 ]]
  bash "$install" --operation install --adopt-matching "${args[@]}" --format json >/dev/null
}

test_owned_replace_backup() {
  local repo
  repo=$(new_repo owned-replace)
  mapfile -t args < <(base_args "$repo")
  bash "$install" --operation install "${args[@]}" --format json >/dev/null
  printf 'modified\n' >"$repo/.ai/context/context.sh"
  if bash "$install" --operation update --target "$repo" --format json >/dev/null 2>&1; then return 1; fi
  bash "$install" --operation update --target "$repo" --owned-modified replace --format json >/dev/null
  grep -q '^#!/usr/bin/env bash' "$repo/.ai/context/context.sh"
  find "$repo/.qbit-toolkit/ai-context/backups" -type f -path '*/.ai/context/context.sh' | grep -q .
}

test_uninstall_preserves_project_content() {
  local repo
  repo=$(new_repo uninstall-preserve)
  printf '# User rules\n' >"$repo/AGENTS.md"
  mapfile -t args < <(base_args "$repo")
  bash "$install" --operation install "${args[@]}" --format json >/dev/null
  printf '# User-owned bridge docs\n' >"$repo/.ai-bridge/README.md"
  bash "$uninstall" --target "$repo" --format json >/dev/null
  grep -q '^# User rules' "$repo/AGENTS.md"
  grep -q '^# User-owned bridge docs' "$repo/.ai-bridge/README.md"
  [[ ! -e "$repo/.ai/context/context.sh" && ! -e "$repo/.qbit/toolkit/installed/ai-context.json" ]]
}

test_central_update_preserves_seed() {
  local repo before after
  repo=$(new_repo central-seeds)
  bash "$install" --operation install --mode central --target "$repo" --project-id demo --project-display-name Demo --repository-id demo-ai-context --context-remote https://github.com/example/demo-ai-context.git --context-branch main --format json >/dev/null
  printf '# Current Project AI State\n\nCUSTOM PROJECT CONTENT\n' >"$repo/state/current.md"
  before=$(sha256sum "$repo/state/current.md" | awk '{print $1}')
  bash "$install" --operation update --target "$repo" --format json >/dev/null
  after=$(sha256sum "$repo/state/current.md" | awk '{print $1}')
  [[ "$before" == "$after" ]]
  bash "$verify" --target "$repo" --format json >/dev/null
}

test_central_uninstall_preserves_seed() {
  local repo
  repo=$(new_repo central-uninstall)
  bash "$install" --operation install --mode central --target "$repo" --project-id demo --project-display-name Demo --repository-id demo-ai-context --context-remote https://github.com/example/demo-ai-context.git --context-branch main --format json >/dev/null
  printf '# Keep me\n' >"$repo/state/current.md"
  bash "$uninstall" --target "$repo" --format json >/dev/null
  grep -q '^# Keep me' "$repo/state/current.md"
  [[ ! -e "$repo/tooling/context-lifecycle.py" && ! -e "$repo/tooling/context-lifecycle.ps1" ]]
}

run_test 'member plan is write-free' test_plan_write_free
run_test 'member install verify and repeated install are idempotent' test_install_verify_idempotent
run_test 'unowned file conflicts fail closed' test_unowned_conflict
run_test 'matching generated file requires explicit adoption' test_matching_requires_adoption
run_test 'modified owned file fails then replace backs up and repairs' test_owned_replace_backup
run_test 'uninstall preserves outside content and seeded bridge README' test_uninstall_preserves_project_content
run_test 'central update preserves project-owned continuity seeds' test_central_update_preserves_seed
run_test 'central uninstall preserves project-owned continuity seeds' test_central_uninstall_preserves_seed

if (( fail > 0 )); then
  printf 'FAIL %d integration test(s); %d passed.\n' "$fail" "$pass" >&2
  exit 1
fi
printf 'PASS all %d POSIX AI Context installer integration tests\n' "$pass"
