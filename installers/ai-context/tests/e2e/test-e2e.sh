#!/usr/bin/env bash
set -euo pipefail
installer_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
install="$installer_root/install.sh"
verify="$installer_root/verify.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
remote="$root/context.git"
central="$root/central"
member="$root/member"
verify_clone="$root/verify"

git init --bare "$remote" >/dev/null
git init -b main "$central" >/dev/null
git -C "$central" config user.name Test
git -C "$central" config user.email test@example.invalid
printf '# bootstrap\n' >"$central/bootstrap.md"
git -C "$central" add bootstrap.md
git -C "$central" commit -m bootstrap >/dev/null
git -C "$central" remote add origin "$remote"

bash "$install" --operation install --mode central --target "$central" --project-id demo --project-display-name Demo --repository-id demo-ai-context --context-remote "$remote" --context-branch main --format json >/dev/null
bash "$verify" --target "$central" --format json >/dev/null
git -C "$central" add .
git -C "$central" commit -m 'install central context' >/dev/null
git -C "$central" push -u origin main >/dev/null
bash "$central/tests/context-lifecycle.tests.sh"

git init -b main "$member" >/dev/null
git -C "$member" config user.name Test
git -C "$member" config user.email test@example.invalid
printf '# member\n' >"$member/README.md"
git -C "$member" add README.md
git -C "$member" commit -m bootstrap >/dev/null

bash "$install" --operation install --mode member --target "$member" --project-id demo --project-display-name Demo --repository-id demo-member --context-remote "$remote" --context-branch main --format json >/dev/null
bash "$verify" --target "$member" --format json >/dev/null
git -C "$member" add .
git -C "$member" commit -m 'install member context' >/dev/null

bash "$member/.ai/context/context.sh" start >/dev/null
cache="$member/.ai/context/cache/project-context"
git -C "$cache" config user.name Test
git -C "$cache" config user.email test@example.invalid
test -f "$member/.ai-bridge/context-runtime.md"
test -f "$member/.ai-bridge/context-runtime.json"
grep -q 'demo-member' "$member/.ai-bridge/context-runtime.md"
cat >"$member/.ai-bridge/context-checkpoint.json" <<'EOF'
{
  "schemaVersion": 1,
  "repository": "demo-member",
  "scope": "posix-installer-e2e",
  "status": "VALIDATED",
  "objective": "Validate installer-provisioned POSIX lifecycle end to end.",
  "confirmedFindings": ["context.sh start generated runtime context."],
  "decisions": ["Use the POSIX lifecycle without PowerShell."],
  "rejectedApproaches": [],
  "validation": ["local bare Git remote"],
  "openQuestions": [],
  "nextAction": "Keep POSIX parity covered by regression tests."
}
EOF
bash "$member/.ai/context/context.sh" checkpoint >/dev/null
test ! -e "$member/.ai-bridge/context-checkpoint.json"

git clone --branch main --single-branch "$remote" "$verify_clone" >/dev/null 2>&1
test -f "$verify_clone/state/repositories/demo-member.md"
test -f "$verify_clone/handoffs/repositories/demo-member.md"
test -f "$verify_clone/manifests/repositories/demo-member.json"
find "$verify_clone/sessions" -type f -name '*demo-member-posix-installer-e2e.md' | grep -q .
python3 - "$verify_clone/manifests/repositories/demo-member.json" <<'PY'
import json, pathlib, sys
value=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value['repository']=='demo-member'
assert value['status']=='VALIDATED'
assert value['scope']=='posix-installer-e2e'
PY
printf 'PASS POSIX AI Context installer E2E\n'
