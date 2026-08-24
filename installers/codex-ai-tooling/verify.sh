#!/usr/bin/env sh
set -eu
state_path=.qbit/toolkit/installed/codex-ai-tooling.json
target=
while [ "$#" -gt 0 ]; do case "$1" in --target) target=${2:-}; shift 2 ;; -h|--help) echo 'Usage: verify.sh --target <path>'; exit 0 ;; *) echo 'Usage: verify.sh --target <path>' >&2; exit 2 ;; esac; done
[ -n "$target" ] || { echo 'Target is required.' >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/lib/installer.sh"
root=$(CDPATH= cd -- "$target" && pwd)
state_file=$root/$state_path
[ -f "$state_file" ] || { echo "Missing state file: $state_path" >&2; exit 1; }
tmp=$(mktemp -d 2>/dev/null || mktemp -d -t qbit-verify)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
failures=0
fail(){ echo "$1" >&2; failures=$((failures+1)); }
sha_file(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
safe_state_path(){ case "$1" in ""|/*|*../*|../*|*'/..'|*'\'*) return 1 ;; esac; return 0; }
block_markers(){ if [ "$1" = AGENTS.md ]; then printf '%s\n%s\n' "$qbit_codex_agents_begin_marker" "$qbit_codex_agents_end_marker"; else printf '%s\n%s\n' "$qbit_codex_begin_marker" "$qbit_codex_end_marker"; fi; }

if [ -z "$state_file" ] || ! parse_and_validate_state "$state_file" "$tmp/managed-files" "$tmp/managed-blocks" "$tmp/installed-paths" "$tmp/metadata" "$script_dir"; then
  echo 'State ownership metadata is invalid.' >&2
  exit 1
fi
validate_portable_ownership_state "$root" "$tmp/managed-files" "$tmp/managed-blocks" || { echo 'Portable ownership manifest does not match compatibility ownership state.' >&2; exit 1; }
state_profile=$(sed -n 's/^profile|//p' "$tmp/metadata")
while IFS='|' read -r rel hash; do
  [ "$rel" != AGENTS.md ] || { echo 'AGENTS.md must not be whole-file managed.' >&2; exit 9; }
  safe_state_path "$rel" || { echo "Unsafe managed file path: $rel" >&2; exit 9; }
  assert_safe_destination_path "$root" "$rel" || { echo "Unsafe managed file destination: $rel" >&2; exit 9; }
  [ -f "$root/$rel" ] || { echo "Missing managed file: $rel" >&2; exit 9; }
  [ "$(sha_file "$root/$rel")" = "$hash" ] || { echo "User-modified managed file: $rel" >&2; exit 9; }
done < "$tmp/managed-files" || failures=$((failures+1))
while IFS='|' read -r rel hash created sep; do
  safe_state_path "$rel" || { echo "Unsafe managed block path: $rel" >&2; exit 9; }
  assert_safe_destination_path "$root" "$rel" || { echo "Unsafe managed block destination: $rel" >&2; exit 9; }
  case "$hash" in [0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;; *) echo "Invalid managed block hash: $rel" >&2; exit 9 ;; esac
  case "$created" in true|false) ;; *) echo "Invalid managed block createdFile: $rel" >&2; exit 9 ;; esac
  case "$sep" in 0|1|2) ;; *) echo "Invalid managed block separator count: $rel" >&2; exit 9 ;; esac
  [ -f "$root/$rel" ] || { echo "Missing managed-block file: $rel" >&2; exit 9; }
  markers=$(block_markers "$rel"); begin=$(printf '%s\n' "$markers" | sed -n '1p'); end=$(printf '%s\n' "$markers" | sed -n '2p')
  managed_block_extract_file "$root/$rel" "$tmp/block" "$begin" "$end" || { echo "Managed block malformed in $rel" >&2; exit 9; }
  [ "$(sha_file "$tmp/block")" = "$hash" ] || { echo "Managed block content mismatch in $rel" >&2; exit 9; }
done < "$tmp/managed-blocks" || failures=$((failures+1))

forbidden_state_pattern='\{\{[A-Z0-9_]+\}\}|D:\\'"Projects"'\\|C:\\'"Users"'\\|/'"Users"'/[^/]+/|/'"home"'/[^/]+/'
grep -Eiq "$forbidden_state_pattern" "$state_file" && fail 'Forbidden host-specific or unresolved value found in state file.' || true
required_files='.codex/config.toml
.serena/project.yml
.serena/codex-single-project.yml
.ai/scripts/bootstrap.sh
.ai/scripts/doctor.sh
.ai/tooling/Dockerfile
.ai/tooling/compose.yaml
.ai/tooling/build-download.py
.ai/tooling/mcp_stdio.py
.ai/tooling/runtime-entrypoint.py
.ai/tooling/doctor.py
.ai/tooling/graphify-runtime.py
.ai/tooling/versions.env
.ai/tooling/python/requirements.in
.ai/tooling/python/requirements.lock
.qbit-toolkit/codex-ai-tooling/manifest.json'
printf '%s\n' "$required_files" | while IFS= read -r file; do [ -f "$root/$file" ] || { echo "Missing managed file: $file" >&2; exit 1; }; done || failures=$((failures+1))
config=$root/.codex/config.toml
compose=$root/.ai/tooling/compose.yaml
versions=$root/.ai/tooling/versions.env
ownership_manifest=$root/.qbit-toolkit/codex-ai-tooling/manifest.json
for field in schema_version installer_version profile target_identity payload_manifest_sha256 installed_entries managed_blocks generated_state_entries original_state_records last_successful_operation; do
  grep -Fq "\"$field\"" "$ownership_manifest" || fail "Ownership manifest field is missing: $field"
done
grep -Eq '"payload_manifest_sha256": "[0-9a-f]{64}"' "$ownership_manifest" || fail 'Ownership payload manifest hash is invalid.'
grep -Eq 'mcp_servers\.(graphify|playwright)' "$config" && fail 'Graphify and Playwright must not be configured as MCP servers.' || true
expected_allowlist='enabled_tools = ["get_symbols_overview", "find_symbol", "find_referencing_symbols", "find_implementations", "find_declaration", "get_diagnostics_for_file", "get_diagnostics_for_symbol", "replace_symbol_body", "insert_after_symbol", "insert_before_symbol", "rename_symbol", "safe_delete_symbol"]'
[ "$(grep -Fxc "$expected_allowlist" "$config")" -eq 1 ] || fail 'Serena enabled_tools must be the exact approved 12-tool allowlist.'
[ "$(grep -Fxc 'enabled_tools = ["resolve-library-id", "query-docs"]' "$config")" -eq 1 ] || fail 'Context7 enabled_tools must be the exact approved allowlist.'
[ "$(grep -Fxc 'enabled_tools = ["find_organizations", "find_projects", "get_sentry_resource", "search_events", "search_issues"]' "$config")" -eq 1 ] || fail 'Sentry enabled_tools must be the exact approved read-only allowlist.'
grep -Fq 'PYTHON_IMAGE=python:3.13.14-slim-trixie@sha256:afe189875f1d2f9b45e287834fb9f2c273a5d59d354ae4050ab9affbf0a6ba06' "$versions" || fail 'Pinned Python image differs.'
grep -Fq 'NODE_IMAGE=node:24.18.0-trixie-slim@sha256:5301bbf5e8046148348b1dea15436326f43c579031f8d76654a631225bdfe467' "$versions" || fail 'Pinned Node image differs.'
grep -Fq 'TYPESCRIPT_VERSION=5.9.3' "$versions" || fail 'Pinned TypeScript version differs.'
grep -Fq 'TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.1.3' "$versions" || fail 'Pinned TypeScript Language Server version differs.'
grep -Fq 'RUST_TOOLCHAIN_VERSION=1.85.0' "$versions" || fail 'Pinned Rust toolchain differs.'
grep -Fq 'RUST_BASE_IMAGE=rust:1.85.0-slim-bookworm@sha256:c842cc0357b91bb15ad2bb89934513d0d226f711fac7f7fedb176d3311714d47' "$versions" || fail 'Pinned Rust base image differs.'
[ "$(sha_file "$root/.ai/tooling/python/requirements.in")" = 9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0 ] || fail 'requirements.in hash mismatch.'
[ "$(sha_file "$root/.ai/tooling/python/requirements.lock")" = df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1 ] || fail 'requirements.lock hash mismatch.'
grep -Fq 'network_mode: none' "$compose" || fail 'Runtime network denial is missing.'
grep -Fq 'cap_drop:' "$compose" && grep -Fq '      - ALL' "$compose" || fail 'Runtime capability drop is missing.'
grep -Fq 'read_only: true' "$compose" || fail 'Read-only runtime contract is missing.'
grep -Fq 'source: .' "$compose" && grep -Fq 'target: /workspace' "$compose" || fail 'Workspace mount contract is missing.'
# Derived Graphify output is ignored and intentionally not installer-owned.
find "$root/.ai" "$root/.codex" "$root/.serena" -type f -exec grep -El '\{\{[A-Z0-9_]+\}\}' {} + 2>/dev/null | grep -q . && fail 'Unresolved payload placeholder found.' || true
[ "$failures" -eq 0 ] || { echo "codex-ai-tooling verification failed with $failures failure(s)." >&2; exit 1; }
echo 'codex-ai-tooling verification passed.'
