[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path,

    [ValidateSet('', 'off', 'on-request', 'full-access')]
    [string]$HostExecMode = '',

    [ValidateSet('', 'auto', 'quic', 'http2')]
    [string]$TunnelProtocol = ''
)

$ErrorActionPreference = 'Stop'
$ConfigFile = Join-Path $PSScriptRoot 'deployment.json'
$TokenFile = Join-Path $PSScriptRoot 'http-token'

if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
    throw "CodexPro deployment configuration not found: $ConfigFile"
}
if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "CodexPro MCP token not found: $TokenFile"
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Workspace does not exist: $Root"
}

$Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json
$EffectiveHostExecMode = if ($HostExecMode) { $HostExecMode } else { [string]$Config.hostExecMode }
$EffectiveTunnelProtocol = if ($TunnelProtocol) { $TunnelProtocol } else { [string]$Config.tunnelProtocol }
if ($EffectiveHostExecMode -notin @('off', 'on-request', 'full-access')) {
    throw "Invalid configured host execution mode: $EffectiveHostExecMode"
}
if ($EffectiveTunnelProtocol -notin @('auto', 'quic', 'http2')) {
    throw "Invalid configured tunnel protocol: $EffectiveTunnelProtocol"
}

$RequiredPaths = @(
    [string]$Config.packageDir,
    [string]$Config.gitBash,
    [string]$Config.codexExecutable,
    [string]$Config.codexProExecutable,
    [string]$Config.cloudflaredExecutable
)
foreach ($RequiredPath in $RequiredPaths) {
    if ([string]::IsNullOrWhiteSpace($RequiredPath) -or -not (Test-Path -LiteralPath $RequiredPath)) {
        throw "Required CodexPro deployment path is unavailable: $RequiredPath"
    }
}

$DistDir = Join-Path ([string]$Config.packageDir) 'dist'
$MarkerChecks = @(
    @{ Path = Join-Path $DistDir 'bashOps.js'; Marker = 'function sandboxInvocation(config, workspace, cwd, command)' },
    @{ Path = Join-Path $DistDir 'config.js'; Marker = 'CODEXPRO_HOST_EXEC_MODE' },
    @{ Path = Join-Path $DistDir 'server.js'; Marker = 'registerCodexTool(config, server, "host_exec"' },
    @{ Path = Join-Path $DistDir 'hostOps.js'; Marker = 'function requestLocalApproval(request)' }
)
foreach ($Check in $MarkerChecks) {
    if (-not (Test-Path -LiteralPath $Check.Path -PathType Leaf)) {
        throw "Required patched CodexPro file is missing: $($Check.Path)"
    }
    if (-not [IO.File]::ReadAllText($Check.Path).Contains($Check.Marker)) {
        throw "Required CodexPro patch marker is missing from $($Check.Path): $($Check.Marker)"
    }
}

$McpToken = [IO.File]::ReadAllText($TokenFile).Trim()
if ($McpToken.Length -ne 64 -or $McpToken -notmatch '^[0-9a-f]{64}$') {
    throw "CodexPro MCP token is invalid: $TokenFile"
}

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$PathDirs = @(
    Split-Path -Parent ([string]$Config.gitBash),
    Split-Path -Parent ([string]$Config.codexExecutable),
    Split-Path -Parent ([string]$Config.codexProExecutable),
    Split-Path -Parent ([string]$Config.cloudflaredExecutable)
) | Where-Object { $_ } | Select-Object -Unique

$PreviousPath = $env:PATH
$PreviousBashSandbox = $env:CODEXPRO_BASH_SANDBOX
$PreviousBashExecutable = $env:CODEXPRO_BASH_EXECUTABLE
$PreviousHostExecMode = $env:CODEXPRO_HOST_EXEC_MODE
$PreviousTunnelTransportProtocol = $env:TUNNEL_TRANSPORT_PROTOCOL

$env:PATH = (($PathDirs + @($PreviousPath)) -join ';')
$env:CODEXPRO_BASH_SANDBOX = 'workspace'
$env:CODEXPRO_BASH_EXECUTABLE = [string]$Config.gitBash
$env:CODEXPRO_HOST_EXEC_MODE = $EffectiveHostExecMode
$env:TUNNEL_TRANSPORT_PROTOCOL = $EffectiveTunnelProtocol

$HostExecDescription = switch ($EffectiveHostExecMode) {
    'full-access' { 'full-access (no per-request approval)' }
    'on-request' { 'on-request (local approval)' }
    default { 'off' }
}

Write-Host "CodexPro workspace:  $ResolvedRoot"
Write-Host "MCP hostname:        $($Config.hostname)"
Write-Host "Bash:                $($Config.gitBash)"
Write-Host "Codex sandbox:       $($Config.codexExecutable)"
Write-Host "Permission profile:  :workspace"
Write-Host "Host execution:      $HostExecDescription"
Write-Host "Tunnel protocol:     $EffectiveTunnelProtocol"

$CodexProArgs = @(
    'stable',
    '--root', $ResolvedRoot,
    '--hostname', [string]$Config.hostname,
    '--tunnel-name', [string]$Config.tunnelName,
    '--token', $McpToken,
    '--agent',
    '--tool-mode', 'full',
    '--write', 'workspace',
    '--bash', 'full',
    '--log-requests'
)

try {
    & ([string]$Config.codexProExecutable) @CodexProArgs
    if ($LASTEXITCODE -ne 0) {
        throw "CodexPro exited with code $LASTEXITCODE."
    }
}
finally {
    $env:CODEXPRO_BASH_EXECUTABLE = $PreviousBashExecutable
    $env:CODEXPRO_BASH_SANDBOX = $PreviousBashSandbox
    $env:CODEXPRO_HOST_EXEC_MODE = $PreviousHostExecMode
    $env:TUNNEL_TRANSPORT_PROTOCOL = $PreviousTunnelTransportProtocol
    $env:PATH = $PreviousPath
}
