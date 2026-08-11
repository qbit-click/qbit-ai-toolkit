#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
docker compose --env-file "$root/.ai/tooling/versions.env" --project-directory "$root" -f "$root/.ai/tooling/compose.yaml" run --rm -T --build --quiet-build graphify python -I /usr/local/libexec/graphify-runtime.py version
