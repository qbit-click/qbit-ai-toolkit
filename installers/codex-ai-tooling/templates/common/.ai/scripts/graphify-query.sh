#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 && -n "$1" && -n "$2" ]] || { echo 'usage: graphify-query.sh <scope> <question>' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
docker compose --env-file "$root/.ai/tooling/versions.env" --project-directory "$root" -f "$root/.ai/tooling/compose.yaml" run --rm -T --build --quiet-build graphify python -I /usr/local/libexec/graphify-runtime.py ensure "$1" >/dev/null
docker compose --env-file "$root/.ai/tooling/versions.env" --project-directory "$root" -f "$root/.ai/tooling/compose.yaml" run --rm -T graphify python -I /usr/local/libexec/graphify-runtime.py query "$1" "$2"
