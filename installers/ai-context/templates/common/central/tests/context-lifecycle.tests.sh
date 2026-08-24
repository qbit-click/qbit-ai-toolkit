#!/usr/bin/env bash
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
central_root=$(CDPATH= cd -- "$here/.." && pwd -P)
member_context_py="$central_root/templates/member/context.py"
member_context_sh="$central_root/templates/member/context.sh"

pass=0
fail=0
log_pass() { pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
log_fail() { fail=$((fail+1)); printf 'FAIL %s\n' "$1" >&2; }
assert_file() { [[ -f "$1" ]] || { printf 'missing file: %s\n' "$1" >&2; return 1; }; }
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

git_identity() {
  git -C "$1" config user.name "AI Context Test"
  git -C "$1" config user.email "ai-context-test@local.invalid"
}

seed_central() {
  local repo=$1
  mkdir -p "$repo/project" "$repo/state" "$repo/repositories" "$repo/tooling"
  cp "$central_root/tooling/context-lifecycle.py" "$repo/tooling/context-lifecycle.py"
  cat >"$repo/AI_CONTEXT.md" <<'EOF'
# AI Context Entry Point
EOF
  cat >"$repo/project/authority.md" <<'EOF'
# Authority
AI context is coordination evidence, never implementation authority.
EOF
  cat >"$repo/state/current.md" <<'EOF'
# Current
Status: READY
EOF
  cat >"$repo/state/next-action.md" <<'EOF'
# Next Action
Continue validated work.
EOF
  cat >"$repo/repositories/repositories.yaml" <<'EOF'
project: test
repositories: {}
EOF
}

make_fixture() {
  local root=$1
  local remote="$root/context.git"
  local remote_config
  remote_config=$(native_path "$remote")
  local central="$root/central"
  local member="$root/member"
  git init --bare "$remote" >/dev/null
  git init -b main "$central" >/dev/null
  git_identity "$central"
  seed_central "$central"
  git -C "$central" add .
  git -C "$central" commit -m seed >/dev/null
  git -C "$central" remote add origin "$remote"
  git -C "$central" push -u origin main >/dev/null
  git init -b main "$member" >/dev/null
  git_identity "$member"
  printf '# member\n' >"$member/README.md"
  mkdir -p "$member/.ai/context" "$member/.ai-bridge"
  cp "$member_context_py" "$member/.ai/context/context.py"
  cp "$member_context_sh" "$member/.ai/context/context.sh"
  cat >"$member/.ai/context/config.json" <<EOF
{
  "schemaVersion": 1,
  "project": "test-project",
  "repository": "test-member",
  "context": {"remote": "$remote_config", "branch": "main", "cachePath": ".ai/context/cache/project-context"},
  "behavior": {"ensureOnStart": true, "refreshOnStart": true, "loadOnStart": true, "checkpointAfterValidation": true, "checkpointBeforeHandoff": true, "commitContext": true, "pushContext": true}
}
EOF
  git -C "$member" add README.md .ai/context/config.json .ai/context/context.py .ai/context/context.sh
  git -C "$member" commit -m seed >/dev/null
  printf '%s\n' "$member"
}

run_test() {
  local name=$1
  shift
  if "$@"; then log_pass "$name"; else log_fail "$name"; fi
}

test_fresh_start() {
  local root member
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  assert_file "$member/.ai-bridge/context-runtime.md"
  assert_file "$member/.ai-bridge/context-runtime.json"
  [[ -d "$member/.ai/context/cache/project-context/.git" ]]
}

test_status() {
  local root member out
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  out=$(bash "$member/.ai/context/context.sh" status)
  [[ "$out" == *'"repository": "test-member"'* ]]
}

test_checkpoint() {
  local root member remote_clone
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  cat >"$member/.ai-bridge/context-checkpoint.json" <<'EOF'
{
  "schemaVersion": 1,
  "repository": "test-member",
  "scope": "posix-e2e",
  "status": "VALIDATED",
  "objective": "Validate POSIX checkpoint lifecycle.",
  "confirmedFindings": ["POSIX lifecycle ran."],
  "decisions": [],
  "rejectedApproaches": [],
  "validation": ["local bare remote"],
  "openQuestions": [],
  "nextAction": "Continue."
}
EOF
  bash "$member/.ai/context/context.sh" checkpoint >/dev/null
  [[ ! -e "$member/.ai-bridge/context-checkpoint.json" ]]
  remote_clone="$root/verify"
  git clone --branch main --single-branch "$root/context.git" "$remote_clone" >/dev/null 2>&1
  assert_file "$remote_clone/state/repositories/test-member.md"
  assert_file "$remote_clone/manifests/repositories/test-member.json"
}

test_invalid_status_rejected() {
  local root member
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  cat >"$member/.ai-bridge/context-checkpoint.json" <<'EOF'
{"schemaVersion":1,"repository":"test-member","scope":"bad","status":"NOPE","objective":"x","confirmedFindings":[],"decisions":[],"rejectedApproaches":[],"validation":[],"openQuestions":[],"nextAction":"x"}
EOF
  if bash "$member/.ai/context/context.sh" checkpoint >/dev/null 2>&1; then return 1; fi
  [[ -f "$member/.ai-bridge/context-checkpoint.json" ]]
}

test_secret_rejected() {
  local root member
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  cat >"$member/.ai-bridge/context-checkpoint.json" <<'EOF'
{"schemaVersion":1,"repository":"test-member","scope":"bad","status":"VALIDATED","objective":"Bearer abcdefghijklmnop","confirmedFindings":[],"decisions":[],"rejectedApproaches":[],"validation":[],"openQuestions":[],"nextAction":"x"}
EOF
  if bash "$member/.ai/context/context.sh" checkpoint >/dev/null 2>&1; then return 1; fi
  [[ -f "$member/.ai-bridge/context-checkpoint.json" ]]
}

test_dirty_context_checkpoint_refused() {
  local root member cache
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  git -C "$member/.ai/context/cache/project-context" config user.name "AI Context Test"
  git -C "$member/.ai/context/cache/project-context" config user.email "ai-context-test@local.invalid"
  cache="$member/.ai/context/cache/project-context"
  printf '\nlocal dirty\n' >>"$cache/state/current.md"
  cat >"$member/.ai-bridge/context-checkpoint.json" <<'EOF'
{"schemaVersion":1,"repository":"test-member","scope":"dirty","status":"VALIDATED","objective":"x","confirmedFindings":[],"decisions":[],"rejectedApproaches":[],"validation":[],"openQuestions":[],"nextAction":"x"}
EOF
  if bash "$member/.ai/context/context.sh" checkpoint >/dev/null 2>&1; then return 1; fi
  grep -q 'local dirty' "$cache/state/current.md"
}

test_fast_forward_clean_cache() {
  local root member cache before after central
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  cache="$member/.ai/context/cache/project-context"
  before=$(git -C "$cache" rev-parse HEAD)
  central="$root/central"
  printf '# Current\nRemote advanced.\n' >"$central/state/current.md"
  git -C "$central" add state/current.md
  git -C "$central" commit -m advance >/dev/null
  git -C "$central" push origin main >/dev/null
  bash "$member/.ai/context/context.sh" start >/dev/null
  after=$(git -C "$cache" rev-parse HEAD)
  [[ "$before" != "$after" ]]
}

test_dirty_start_preserved() {
  local root member cache
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  cache="$member/.ai/context/cache/project-context"
  printf 'preserve me\n' >"$cache/local-dirty-marker.txt"
  bash "$member/.ai/context/context.sh" start >/dev/null 2>&1
  [[ -f "$cache/local-dirty-marker.txt" ]]
  python3 - "$member/.ai-bridge/context-runtime.json" <<'PY'
import json,pathlib,sys
d=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d['context']['dirty'] is True
assert d['context']['freshness']=='DIRTY_LOCAL_CONTEXT'
PY
}

test_clean_origin_migration() {
  local root member cache replacement replacement_config actual
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  cache="$member/.ai/context/cache/project-context"
  replacement="$root/replacement-context.git"
  git clone --bare "$root/context.git" "$replacement" >/dev/null 2>&1
  replacement_config=$(native_path "$replacement")
  python3 - "$member/.ai/context/config.json" "$replacement_config" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d['context']['remote']=sys.argv[2]; p.write_text(json.dumps(d,indent=2)+'\n')
PY
  bash "$member/.ai/context/context.sh" start >/dev/null
  actual=$(git -C "$cache" remote get-url origin)
  python3 - "$actual" "$replacement_config" <<'PY'
from pathlib import Path
import sys
assert Path(sys.argv[1]).resolve() == Path(sys.argv[2]).resolve()
PY
}

test_dirty_origin_migration_refused() {
  local root member cache replacement replacement_config original actual
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  cache="$member/.ai/context/cache/project-context"
  original=$(git -C "$cache" remote get-url origin)
  printf 'preserve me\n' >"$cache/local-dirty-marker.txt"
  replacement="$root/replacement-context.git"
  git clone --bare "$root/context.git" "$replacement" >/dev/null 2>&1
  replacement_config=$(native_path "$replacement")
  python3 - "$member/.ai/context/config.json" "$replacement_config" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d['context']['remote']=sys.argv[2]; p.write_text(json.dumps(d,indent=2)+'\n')
PY
  if bash "$member/.ai/context/context.sh" start >/dev/null 2>&1; then return 1; fi
  actual=$(git -C "$cache" remote get-url origin)
  [[ "$actual" == "$original" && -f "$cache/local-dirty-marker.txt" ]]
}

test_diverged_cache_reported_read_only() {
  local root member cache central local_head after_head
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  bash "$member/.ai/context/context.sh" start >/dev/null
  cache="$member/.ai/context/cache/project-context"
  git_identity "$cache"
  printf 'local commit\n' >"$cache/local-ahead.md"
  git -C "$cache" add local-ahead.md
  git -C "$cache" commit -m local-ahead >/dev/null
  local_head=$(git -C "$cache" rev-parse HEAD)
  central="$root/central"
  printf '# Current\nRemote divergent commit.\n' >"$central/state/current.md"
  git -C "$central" add state/current.md
  git -C "$central" commit -m remote-diverge >/dev/null
  git -C "$central" push origin main >/dev/null
  bash "$member/.ai/context/context.sh" start >/dev/null 2>&1
  after_head=$(git -C "$cache" rev-parse HEAD)
  [[ "$after_head" == "$local_head" ]]
  python3 - "$member/.ai-bridge/context-runtime.json" <<'PY'
import json,pathlib,sys
d=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d['context']['freshness']=='DIVERGED_LOCAL_CONTEXT'
assert d['context']['dirty'] is False
PY
}

test_cache_escape_rejected() {
  local root member config escaped
  root=$(mktemp -d)
  member=$(make_fixture "$root")
  config="$member/.ai/context/config.json"
  escaped="$root/escaped-cache"
  python3 - "$config" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1])
data=json.loads(p.read_text())
data['context']['cachePath']='../../../escaped-cache'
p.write_text(json.dumps(data,indent=2)+'\n')
PY
  if bash "$member/.ai/context/context.sh" start >/dev/null 2>&1; then return 1; fi
  [[ ! -e "$escaped" ]]
}

run_test 'fresh clone start creates runtime bundle' test_fresh_start
run_test 'status emits repository runtime state' test_status
run_test 'checkpoint commits and pushes scoped context' test_checkpoint
run_test 'invalid checkpoint status is rejected' test_invalid_status_rejected
run_test 'secret-like checkpoint content is rejected' test_secret_rejected
run_test 'dirty context checkpoint is refused without overwrite' test_dirty_context_checkpoint_refused
run_test 'clean stale cache fast-forwards to remote' test_fast_forward_clean_cache
run_test 'dirty start preserves local context and reports dirty freshness' test_dirty_start_preserved
run_test 'clean cache origin migrates safely' test_clean_origin_migration
run_test 'dirty cache refuses origin migration' test_dirty_origin_migration_refused
run_test 'diverged cache is preserved and reported read-only' test_diverged_cache_reported_read_only
run_test 'cache path escape is rejected before filesystem mutation' test_cache_escape_rejected

if (( fail > 0 )); then
  printf 'FAIL %d/%d context lifecycle tests\n' "$fail" "$((pass+fail))" >&2
  exit 1
fi
printf 'PASS all %d POSIX context lifecycle tests\n' "$pass"
