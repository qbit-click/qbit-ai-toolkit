param(
  [Parameter(Mandatory = $true)][string]$Scope,
  [Parameter(Mandatory = $true)][string]$Question
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$compose = Join-Path $root '.ai/tooling/compose.yaml'
$versions = Join-Path $root '.ai/tooling/versions.env'
& docker compose --env-file $versions --project-directory $root -f $compose run --rm -T --build --quiet-build graphify python -I /usr/local/libexec/graphify-runtime.py ensure $Scope | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Graphify scoped ensure failed.' }
& docker compose --env-file $versions --project-directory $root -f $compose run --rm -T graphify python -I /usr/local/libexec/graphify-runtime.py query $Scope $Question
if ($LASTEXITCODE -ne 0) { throw 'Graphify scoped query failed.' }
