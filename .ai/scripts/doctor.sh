#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
docker compose --project-directory "$root" -f "$root/.ai/tooling/compose.yaml" run --rm doctor
