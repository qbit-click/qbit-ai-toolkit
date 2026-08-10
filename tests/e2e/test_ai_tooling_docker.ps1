$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
python (Join-Path $root 'tests/e2e/ai_tooling_docker.py') --host-family powershell
