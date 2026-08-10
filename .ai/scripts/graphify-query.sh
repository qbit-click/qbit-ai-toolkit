#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo 'usage: graphify-query.sh QUESTION' >&2; exit 2; fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
docker compose --project-directory "$root" -f "$root/.ai/tooling/compose.yaml" run --rm graphify python -I /usr/local/libexec/graphify-runtime.py query "$1"
