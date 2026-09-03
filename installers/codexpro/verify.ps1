[CmdletBinding()]
param(
    [string]$StateDir = (Join-Path $HOME '.codexpro'),
    [switch]$SkipTunnelCheck
)

$ErrorActionPreference = 'Stop'
$ExpectedCodexProVersion = '0.29.0'
$Errors = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $Checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail }) | Out-Null
    if (-not $Passed) { $Errors.Add("${Name}: $Detail") | Out-Null }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'installer.codexpro verification is Windows-only.'
}

$DeploymentPath = Join-Path $StateDir 'deployment.json'
$TokenPath = Join-Path $StateDir 'http-token'
$LauncherPath = Join-Path $StateDir 'Start-CodexPro.ps1'
$UrlHelperPath = Join-Path $StateDir 'Get-CodexProConnectorUrl.ps1'

if (-not (Test-Path -LiteralPath $DeploymentPath -PathType Leaf)) {
    throw "CodexPro deployment state not found: $DeploymentPath"
}
$Deployment = Get-Content -LiteralPath $DeploymentPath -Raw | ConvertFrom-Json
Add-Check 'installer ownership' ($Deployment.installerId -eq 'installer.codexpro') "installerId=$($Deployment.installerId)"
Add-Check 'workspace root' (Test-Path -LiteralPath ([string]$Deployment.workspaceRoot) -PathType Container) ([string]$Deployment.workspaceRoot)
Add-Check 'launcher' (Test-Path -LiteralPath $LauncherPath -PathType Leaf) $LauncherPath
Add-Check 'connector URL helper' (Test-Path -LiteralPath $UrlHelperPath -PathType Leaf) $UrlHelperPath

$TokenValid = $false
if (Test-Path -LiteralPath $TokenPath -PathType Leaf) {
    $Token = [IO.File]::ReadAllText($TokenPath).Trim()
    $TokenValid = $Token.Length -eq 64 -and $Token -match '^[0-9a-f]{64}$'
}
Add-Check 'MCP token' $TokenValid '64-character lowercase hexadecimal token present; value not displayed'

$PackageDir = [string]$Deployment.packageDir
$PackageJson = Join-Path $PackageDir 'package.json'
$PackageVersionOk = $false
if (Test-Path -LiteralPath $PackageJson -PathType Leaf) {
    $Package = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
    $PackageVersionOk = $Package.name -eq 'codexpro' -and $Package.version -eq $ExpectedCodexProVersion
}
Add-Check 'CodexPro package version' $PackageVersionOk "$PackageDir (expected $ExpectedCodexProVersion)"

$MarkerChecks = @(
    @{ Name = 'workspace Bash sandbox'; Path = Join-Path $PackageDir 'dist\bashOps.js'; Marker = 'function sandboxInvocation(config, workspace, cwd, command)' },
    @{ Name = 'Windows environment allowlist'; Path = Join-Path $PackageDir 'dist\bashOps.js'; Marker = 'env.USERPROFILE = userProfile;' },
    @{ Name = 'host execution config'; Path = Join-Path $PackageDir 'dist\config.js'; Marker = 'CODEXPRO_HOST_EXEC_MODE' },
    @{ Name = 'host_exec registration'; Path = Join-Path $PackageDir 'dist\server.js'; Marker = 'registerCodexTool(config, server, "host_exec"' },
    @{ Name = 'open_app registration'; Path = Join-Path $PackageDir 'dist\server.js'; Marker = 'registerCodexTool(config, server, "open_app"' },
    @{ Name = 'host execution implementation'; Path = Join-Path $PackageDir 'dist\hostOps.js'; Marker = 'function requestLocalApproval(request)' }
)
foreach ($Check in $MarkerChecks) {
    $passed = Test-Path -LiteralPath $Check.Path -PathType Leaf
    if ($passed) {
        $passed = [IO.File]::ReadAllText($Check.Path).Contains($Check.Marker)
    }
    Add-Check $Check.Name $passed $Check.Path
}

foreach ($PathCheck in @(
    @{ Name = 'Git executable'; Path = [string]$Deployment.gitExecutable },
    @{ Name = 'Git Bash'; Path = [string]$Deployment.gitBash },
    @{ Name = 'Codex CLI'; Path = [string]$Deployment.codexExecutable },
    @{ Name = 'CodexPro executable'; Path = [string]$Deployment.codexProExecutable },
    @{ Name = 'cloudflared'; Path = [string]$Deployment.cloudflaredExecutable }
)) {
    Add-Check $PathCheck.Name (Test-Path -LiteralPath $PathCheck.Path -PathType Leaf) $PathCheck.Path
}

$CodexPath = [string]$Deployment.codexExecutable
$CodexLoggedIn = $false
if (Test-Path -LiteralPath $CodexPath -PathType Leaf) {
    & $CodexPath login status *> $null
    $CodexLoggedIn = $LASTEXITCODE -eq 0
}
Add-Check 'Codex CLI authentication' $CodexLoggedIn 'codex login status'

if ([bool]$Deployment.profileManaged) {
    $ProfilePath = [string]$Deployment.profilePath
    $ProfileOk = $false
    if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) {
        $profileText = [IO.File]::ReadAllText($ProfilePath)
        $ProfileOk = $profileText.Contains('# >>> qbit codexpro >>>') -and $profileText.Contains('# <<< qbit codexpro <<<')
    }
    Add-Check 'PowerShell cpx helper' $ProfileOk $ProfilePath
}

if ([bool]$Deployment.tunnelConfigured -and -not $SkipTunnelCheck) {
    $Cloudflared = [string]$Deployment.cloudflaredExecutable
    $TunnelOk = $false
    if (Test-Path -LiteralPath $Cloudflared -PathType Leaf) {
        $json = & $Cloudflared tunnel list --output json 2>$null
        if ($LASTEXITCODE -eq 0 -and $json) {
            try {
                $tunnels = @(($json -join [Environment]::NewLine) | ConvertFrom-Json)
                $TunnelOk = $null -ne ($tunnels | Where-Object { $_.name -eq [string]$Deployment.tunnelName } | Select-Object -First 1)
            }
            catch {
                $Warnings.Add('cloudflared tunnel list returned output that could not be parsed as JSON.') | Out-Null
            }
        }
    }
    Add-Check 'Cloudflare named tunnel' $TunnelOk ([string]$Deployment.tunnelName)
}

$Result = [pscustomobject]@{
    status = if ($Errors.Count -eq 0) { 'ok' } else { 'error' }
    installer = 'installer.codexpro'
    stateDir = $StateDir
    checks = $Checks
    warnings = $Warnings
    errors = $Errors
}
$Result | ConvertTo-Json -Depth 6

if ($Errors.Count -gt 0) {
    throw "CodexPro verification failed: $($Errors -join '; ')"
}
