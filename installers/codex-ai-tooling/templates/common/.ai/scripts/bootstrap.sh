#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose="$root/.ai/tooling/compose.yaml"
expected_in=9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0
expected_lock=df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1

index_snapshot() {
  git -C "$root" ls-files --stage
}

[[ -d "$root/.git" ]] || { echo 'Repository root is not a Git worktree.' >&2; exit 1; }
command -v docker >/dev/null || { echo 'Docker CLI is unavailable.' >&2; exit 1; }
docker info >/dev/null
engine="$(docker info --format '{{.OSType}}/{{.Architecture}}')"
[[ "$engine" =~ ^linux/(amd64|x86_64)$ ]] || { echo "Docker engine does not provide native linux/amd64: $engine" >&2; exit 1; }
compose_version="$(docker compose version --short)"
compose_major="${compose_version%%.*}"
[[ "$compose_major" =~ ^[0-9]+$ && "$compose_major" -ge 2 ]] || { echo 'Docker Compose major version 2 or newer is required.' >&2; exit 1; }

required=(.ai/tooling/Dockerfile .ai/tooling/compose.yaml .ai/tooling/runtime-entrypoint.py
  .ai/tooling/build-download.py .ai/tooling/graphify-runtime.py
  .ai/tooling/doctor.py .ai/tooling/serena_config.yml
  .ai/tooling/versions.env .ai/tooling/debian-trixie-amd64.lock .ai/tooling/serena-artifacts.lock
  .ai/tooling/python/requirements.in .ai/tooling/python/requirements.lock
  .ai/tooling/language-servers/package.json .ai/tooling/language-servers/package-lock.json
  .serena/project.yml .serena/codex-single-project.yml)
for relative in "${required[@]}"; do [[ -f "$root/$relative" ]] || { echo "Missing build input: $relative" >&2; exit 1; }; done
[[ "$(sha256sum "$root/.ai/tooling/python/requirements.in" | cut -d' ' -f1)" == "$expected_in" ]] || { echo 'requirements.in hash mismatch.' >&2; exit 1; }
[[ "$(sha256sum "$root/.ai/tooling/python/requirements.lock" | cut -d' ' -f1)" == "$expected_lock" ]] || { echo 'requirements.lock hash mismatch.' >&2; exit 1; }
grep -Fq '"lockfileVersion": 3' "$root/.ai/tooling/language-servers/package-lock.json"
grep -Fq '"bash-language-server": "5.6.0"' "$root/.ai/tooling/language-servers/package-lock.json"
grep -Fq '"pyright": "1.1.403"' "$root/.ai/tooling/language-servers/package-lock.json"
grep -Fq '"typescript": "5.9.3"' "$root/.ai/tooling/language-servers/package-lock.json"
grep -Fq '"typescript-language-server": "5.1.3"' "$root/.ai/tooling/language-servers/package-lock.json"
[[ ! -e "$root/node_modules" && ! -e "$root/.ai/tooling/language-servers/node_modules" ]] || { echo 'Repository node_modules is forbidden.' >&2; exit 1; }
docker compose --project-directory "$root" -f "$compose" config --quiet

before_index="$(index_snapshot)"
build_args=(compose --project-directory "$root" -f "$compose" build)
if [[ "${1:-}" == "--clean" ]]; then build_args+=(--pull --no-cache); elif [[ $# -ne 0 ]]; then echo 'usage: bootstrap.sh [--clean]' >&2; exit 2; fi
docker "${build_args[@]}"
docker compose --project-directory "$root" -f "$compose" run --rm -T --no-deps serena true
after_index="$(index_snapshot)"
[[ "$after_index" == "$before_index" ]] || { echo 'Git index changed during the AI tooling bootstrap.' >&2; exit 1; }
echo 'AI tooling image and Serena state/resources prepared without starting MCP services or mutating the Git index.'
