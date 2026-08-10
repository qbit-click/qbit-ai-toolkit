#!/usr/bin/env sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
installer_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-e2e-sh)
cleanup(){ rm -rf "$tmp"; }
trap cleanup EXIT HUP INT TERM
pass=0
fail=0
skip=0
scenario(){ scenario_name=$1; shift; if "$@"; then pass=$((pass+1)); echo "PASS $scenario_name"; else fail=$((fail+1)); echo "FAIL $scenario_name" >&2; fi; }
new_repo(){ mkdir -p "$tmp/$1"; git -C "$tmp/$1" init -q; printf '%s' "$tmp/$1"; }
snapshot_files(){ find "$1" -path "$1/.git" -prune -o -type f -exec sh -c 'for f do printf "%s:" "$f"; if command -v sha256sum >/dev/null 2>&1; then sha256sum "$f" | cut -d " " -f 1; else shasum -a 256 "$f" | cut -d " " -f 1; fi; done' sh {} + | sort; }
write_project_agents(){ cat > "$1/AGENTS.md" <<'EOF'
# Repository Guidelines

## Architecture

Project-owned Rust architecture guidance.

## Build Commands

- Build: `cargo build`

## Testing Rules

- Run unit and integration tests.

Trailing spaces stay here.  


EOF
}
typescript_lifecycle(){ repo=$(new_repo ts-life); echo '{}' > "$repo/tsconfig.json"; echo keep > "$repo/UNRELATED.txt"; bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null; grep -q '"profile": "typescript"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; before=$(snapshot_files "$repo"); bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null; after=$(snapshot_files "$repo"); [ "$before" = "$after" ]; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ -f "$repo/UNRELATED.txt" ] && [ ! -f "$repo/.qbit/toolkit/installed/codex-ai-tooling.json" ]; }
generic_lifecycle(){ repo=$(new_repo generic-life); echo keep > "$repo/UNRELATED.txt"; bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null; grep -q '"profile": "generic"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"; bash "$installer_root/verify.sh" --target "$repo" >/dev/null; grep -q 'enabled = false' "$repo/.codex/config.toml"; bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null; [ -f "$repo/UNRELATED.txt" ]; }
rust_lifecycle(){
  repo=$(new_repo rust-life)
  cat > "$repo/Cargo.toml" <<'EOF'
[package]
name = "demo"
edition = "2024"
rust-version = "1.85"
EOF
  cat > "$repo/rust-toolchain.toml" <<'EOF'
[toolchain]
channel = "1.85.0"
EOF
  write_project_agents "$repo"
  cp "$repo/AGENTS.md" "$tmp/rust-agents-original"
  mkdir -p "$repo/src"
  printf '%s' 'fn main() {}' > "$repo/src/main.rs"
  mkdir -p "$repo/.ai" "$repo/.codex"
  printf '%s' keep-ai > "$repo/.ai/custom-project-file.txt"
  printf '%s' keep-codex > "$repo/.codex/custom-project-file.toml"
  bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null
  grep -q '"profile": "rust"' "$repo/.qbit/toolkit/installed/codex-ai-tooling.json"
  grep -q 'Project-owned Rust architecture guidance.' "$repo/AGENTS.md"
  [ "$(grep -c '<!-- qbit-toolkit:codex-ai-tooling:start -->' "$repo/AGENTS.md")" -eq 1 ]
  bash "$installer_root/verify.sh" --target "$repo" >/dev/null
  before=$(snapshot_files "$repo")
  bash "$installer_root/install.sh" --target "$repo" --profile auto --skip-bootstrap --skip-doctor >/dev/null
  after=$(snapshot_files "$repo")
  [ "$before" = "$after" ]
  {
    printf '## Local Notes\nProject-owned update.  \n\n'
    cat "$repo/AGENTS.md"
  } > "$repo/AGENTS.tmp"
  mv "$repo/AGENTS.tmp" "$repo/AGENTS.md"
  {
    printf '## Local Notes\nProject-owned update.  \n\n'
    cat "$tmp/rust-agents-original"
  } > "$tmp/rust-agents-expected"
  bash "$installer_root/verify.sh" --target "$repo" >/dev/null
  bash "$installer_root/uninstall.sh" --target "$repo" >/dev/null
  ! grep -q 'qbit-toolkit:codex-ai-tooling' "$repo/AGENTS.md"
  cmp -s "$tmp/rust-agents-expected" "$repo/AGENTS.md"
  [ -f "$repo/src/main.rs" ]
  [ -f "$repo/.ai/custom-project-file.txt" ]
  [ -f "$repo/.codex/custom-project-file.toml" ]
}
scenario 'POSIX TypeScript lifecycle' typescript_lifecycle
scenario 'POSIX generic lifecycle' generic_lifecycle
scenario 'POSIX Rust lifecycle with existing AGENTS' rust_lifecycle
echo "RESULT passed=$pass failed=$fail skipped=$skip"
[ "$fail" -eq 0 ]
