$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
docker compose --project-directory $root -f (Join-Path $root '.ai/tooling/compose.yaml') run --rm doctor
if ($LASTEXITCODE -ne 0) { throw 'AI tooling Doctor reported a failed runtime check.' }
