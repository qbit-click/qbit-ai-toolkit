[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ConfigFile = Join-Path $PSScriptRoot 'deployment.json'
$TokenFile = Join-Path $PSScriptRoot 'http-token'
if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "CodexPro deployment configuration not found: $ConfigFile"
}
if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "CodexPro MCP token not found: $TokenFile"
}
$Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
$Token = [IO.File]::ReadAllText($TokenFile).Trim()
if ($Token.Length -ne 64 -or $Token -notmatch '^[0-9a-f]{64}$') {
    throw 'CodexPro MCP token is invalid.'
}
"https://$($Config.hostname)/mcp?codexpro_token=$Token"
