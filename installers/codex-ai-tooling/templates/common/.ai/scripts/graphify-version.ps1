$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$compose = Join-Path $root '.ai/tooling/compose.yaml'
$versions = Join-Path $root '.ai/tooling/versions.env'
& docker compose --env-file $versions --project-directory $root -f $compose run --rm -T --build --quiet-build graphify python -I /usr/local/libexec/graphify-runtime.py version
if ($LASTEXITCODE -ne 0) { throw 'Graphify version check failed.' }
