$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
docker compose --project-directory $root -f (Join-Path $root '.ai/tooling/compose.yaml') run --rm graphify python -I /usr/local/libexec/graphify-runtime.py report
