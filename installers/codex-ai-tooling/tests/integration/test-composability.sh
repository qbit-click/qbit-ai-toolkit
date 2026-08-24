#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
tooling="$root/installers/codex-ai-tooling"
context="$root/installers/ai-context"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
init_repo(){ local path=$1; mkdir -p "$path"; git -C "$path" init -q -b main; printf 'project\n' > "$path/PROJECT.txt"; }
markers(){ [ "$(grep -Fxc "$2" "$1")" = 1 ]; }
install_tooling(){ bash "$tooling/install.sh" --operation install --target "$1" --profile generic --skip-bootstrap --skip-doctor >/dev/null; }
verify_tooling(){ bash "$tooling/verify.sh" --target "$1" >/dev/null; }
install_context(){ bash "$context/install.sh" --operation install --mode member --target "$1" --project-id composition --repository-id "$2" --context-remote "$bare" --context-branch main >/dev/null; }
verify_context(){ bash "$context/install.sh" --operation verify --target "$1" >/dev/null; }
git init --bare -q --initial-branch=main "$tmp/context.git"
bare="$tmp/context.git"; central="$tmp/central"; init_repo "$central"; git -C "$central" remote add origin "$bare"
bash "$context/install.sh" --operation install --mode central --target "$central" --project-id composition --project-display-name Composition --repository-id composition-ai-context --context-remote "$bare" --context-branch main >/dev/null
git -C "$central" add --all; git -C "$central" -c user.name=Test -c user.email=test@example.invalid commit -qm central; git -C "$central" push -qu origin main
for order in tooling-context context-tooling; do
  [ -z "${QBIT_TOOLKIT_COMPOSITION_ORDER:-}" ] || [ "$order" = "$QBIT_TOOLKIT_COMPOSITION_ORDER" ] || continue
  repo="$tmp/$order"; init_repo "$repo"; printf '# Prefix\n# Suffix\n' > "$repo/AGENTS.md"; printf 'project.log\n' > "$repo/.gitignore"
  if [ "$order" = tooling-context ]; then install_tooling "$repo"; install_context "$repo" "$order"; else install_context "$repo" "$order"; install_tooling "$repo"; fi
  verify_tooling "$repo"; verify_context "$repo"
  markers "$repo/AGENTS.md" '<!-- qbit-toolkit:codex-ai-tooling:start -->'; markers "$repo/AGENTS.md" '<!-- qbit-toolkit:ai-context:start -->'; markers "$repo/.gitignore" '# qbit-toolkit:codex-ai-tooling:start'; markers "$repo/.gitignore" '# qbit-toolkit:ai-context:start'
  grep -Fx '# Prefix' "$repo/AGENTS.md" >/dev/null; grep -Fx '# Suffix' "$repo/AGENTS.md" >/dev/null
  context_state="$repo/.qbit/toolkit/installed/ai-context.json"; tooling_state="$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; context_hash=$(sha256sum "$context_state"|awk '{print $1}')
  bash "$tooling/install.sh" --operation update --target "$repo" --profile generic --skip-bootstrap --skip-doctor >/dev/null; [ "$context_hash" = "$(sha256sum "$context_state"|awk '{print $1}')" ]
  tooling_hash=$(sha256sum "$tooling_state"|awk '{print $1}'); bash "$context/install.sh" --operation update --target "$repo" >/dev/null; [ "$tooling_hash" = "$(sha256sum "$tooling_state"|awk '{print $1}')" ]
  bash "$tooling/uninstall.sh" --target "$repo" >/dev/null; [ -f "$context_state" ]; verify_context "$repo"
  install_tooling "$repo"; bash "$context/install.sh" --operation uninstall --target "$repo" >/dev/null; [ -f "$tooling_state" ]; verify_tooling "$repo"
done
echo 'PASS POSIX cross-installer composability'
