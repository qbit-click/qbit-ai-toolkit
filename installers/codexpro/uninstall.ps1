[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$StateDir = (Join-Path $HOME '.codexpro'),
    [switch]$RemoveTunnel,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($env:OS -ne 'Windows_NT') {
    throw 'installer.codexpro uninstall is Windows-only.'
}

$DeploymentPath = Join-Path $StateDir 'deployment.json'
if (-not (Test-Path -LiteralPath $DeploymentPath -PathType Leaf)) {
    throw "CodexPro installer state not found: $DeploymentPath"
}
$Deployment = Get-Content -LiteralPath $DeploymentPath -Raw | ConvertFrom-Json
if ($Deployment.installerId -ne 'installer.codexpro') {
    throw "Refusing to uninstall unowned state from $StateDir."
}

function Remove-ManagedProfileBlock {
    param([string]$ProfilePath)
    if (-not $ProfilePath -or -not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
        return
    }
    $start = '# >>> qbit codexpro >>>'
    $end = '# <<< qbit codexpro <<<'
    $current = [IO.File]::ReadAllText($ProfilePath)
    $pattern = '(?ms)^' + [regex]::Escape($start) + '.*?^' + [regex]::Escape($end) + '\s*'
    $updated = [regex]::Replace($current, $pattern, '', 1)
    if ($updated -ne $current) {
        [IO.File]::WriteAllText($ProfilePath, $updated, $Utf8NoBom)
    }
}

function Remove-InstallerOwnedCodexProPackage {
    if ([bool]$Deployment.codexProWasPresentBefore) {
        return $false
    }

    $managerName = [string]$Deployment.packageManager
    $managerExecutable = [string]$Deployment.packageManagerExecutable
    if (-not $managerExecutable -or -not (Test-Path -LiteralPath $managerExecutable -PathType Leaf)) {
        $resolved = Get-Command $managerName -ErrorAction SilentlyContinue | Select-Object -First 1
        $managerExecutable = if ($resolved) { $resolved.Source } else { $null }
    }
    if (-not $managerExecutable) {
        throw "Package manager required to remove installer-owned CodexPro is unavailable: $managerName"
    }

    switch ($managerName) {
        'bun'  { & $managerExecutable remove -g codexpro }
        'npm'  { & $managerExecutable uninstall -g codexpro }
        'pnpm' { & $managerExecutable remove -g codexpro }
        default { throw "Unsupported recorded package manager: $managerName" }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove installer-owned CodexPro with $managerName (exit $LASTEXITCODE)."
    }
    return $true
}

function Restore-PackagePatch {
    param([string]$BackupDir, [string]$PackageDir)
    if (-not $BackupDir) { return $false }
    if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
        throw "Recorded CodexPro patch backup is missing: $BackupDir"
    }
    $metadataPath = Join-Path $BackupDir 'backup.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "CodexPro patch backup metadata is missing: $metadataPath"
    }
    if (-not (Test-Path -LiteralPath $PackageDir -PathType Container)) {
        throw "Installed CodexPro package directory is missing: $PackageDir"
    }
    $packageJsonPath = Join-Path $PackageDir 'package.json'
    $package = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
    if ($package.name -ne 'codexpro' -or $package.version -ne '0.29.0') {
        throw "Refusing to restore a 0.29.0 backup over $($package.name)@$($package.version)."
    }
    $dist = Join-Path $PackageDir 'dist'
    $serverPath = Join-Path $dist 'server.js'
    $configPath = Join-Path $dist 'config.js'
    $bashPath = Join-Path $dist 'bashOps.js'
    $hostPath = Join-Path $dist 'hostOps.js'
    $ownedMarkersPresent =
        (Test-Path -LiteralPath $serverPath -PathType Leaf) -and
        [IO.File]::ReadAllText($serverPath).Contains('registerCodexTool(config, server, "host_exec"') -and
        (Test-Path -LiteralPath $configPath -PathType Leaf) -and
        [IO.File]::ReadAllText($configPath).Contains('CODEXPRO_HOST_EXEC_MODE')
    if (-not $ownedMarkersPresent -and -not $Force) {
        throw 'Current CodexPro package no longer matches the installer-owned patch. Use -Force only after reviewing the package drift.'
    }

    $backupMetadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    Copy-Item -LiteralPath (Join-Path $BackupDir 'bashOps.js') -Destination $bashPath -Force
    Copy-Item -LiteralPath (Join-Path $BackupDir 'config.js') -Destination $configPath -Force
    Copy-Item -LiteralPath (Join-Path $BackupDir 'server.js') -Destination $serverPath -Force
    if ([bool]$backupMetadata.hostOpsExisted) {
        Copy-Item -LiteralPath (Join-Path $BackupDir 'hostOps.js') -Destination $hostPath -Force
    }
    else {
        Remove-Item -LiteralPath $hostPath -Force -ErrorAction SilentlyContinue
    }
    return $true
}

$PackageRestored = $false
if ($PSCmdlet.ShouldProcess([string]$Deployment.packageDir, 'restore CodexPro package patch backup')) {
    $PackageRestored = Restore-PackagePatch -BackupDir ([string]$Deployment.patchBackupDir) -PackageDir ([string]$Deployment.packageDir)
}

$PackageRemoved = $false
if (-not [bool]$Deployment.codexProWasPresentBefore -and $PSCmdlet.ShouldProcess('codexpro', 'remove installer-owned global CodexPro package')) {
    $PackageRemoved = Remove-InstallerOwnedCodexProPackage
}

if ([bool]$Deployment.profileManaged -and $PSCmdlet.ShouldProcess([string]$Deployment.profilePath, 'remove managed cpx profile block')) {
    Remove-ManagedProfileBlock -ProfilePath ([string]$Deployment.profilePath)
}

$LauncherPath = Join-Path $StateDir 'Start-CodexPro.ps1'
$UrlHelperPath = Join-Path $StateDir 'Get-CodexProConnectorUrl.ps1'
if ($PSCmdlet.ShouldProcess($LauncherPath, 'restore or remove managed launcher')) {
    if ($Deployment.previousLauncherBackup -and (Test-Path -LiteralPath ([string]$Deployment.previousLauncherBackup) -PathType Leaf)) {
        Copy-Item -LiteralPath ([string]$Deployment.previousLauncherBackup) -Destination $LauncherPath -Force
    }
    else {
        Remove-Item -LiteralPath $LauncherPath -Force -ErrorAction SilentlyContinue
    }
}
if ($PSCmdlet.ShouldProcess($UrlHelperPath, 'restore or remove connector URL helper')) {
    if ($Deployment.previousUrlHelperBackup -and (Test-Path -LiteralPath ([string]$Deployment.previousUrlHelperBackup) -PathType Leaf)) {
        Copy-Item -LiteralPath ([string]$Deployment.previousUrlHelperBackup) -Destination $UrlHelperPath -Force
    }
    else {
        Remove-Item -LiteralPath $UrlHelperPath -Force -ErrorAction SilentlyContinue
    }
}

$TokenPath = Join-Path $StateDir 'http-token'
if (-not [bool]$Deployment.tokenWasPresentBefore -and $PSCmdlet.ShouldProcess($TokenPath, 'remove installer-created MCP token')) {
    Remove-Item -LiteralPath $TokenPath -Force -ErrorAction SilentlyContinue
}

if ($RemoveTunnel) {
    $Cloudflared = [string]$Deployment.cloudflaredExecutable
    if (-not (Test-Path -LiteralPath $Cloudflared -PathType Leaf)) {
        throw "cloudflared is unavailable; cannot remove tunnel $($Deployment.tunnelName)."
    }
    if ($PSCmdlet.ShouldProcess([string]$Deployment.tunnelName, 'delete Cloudflare named tunnel')) {
        & $Cloudflared tunnel delete --force ([string]$Deployment.tunnelName)
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete Cloudflare tunnel $($Deployment.tunnelName). DNS cleanup may still be required in Cloudflare."
        }
    }
}

if ($PSCmdlet.ShouldProcess($DeploymentPath, 'remove installer ownership state')) {
    Remove-Item -LiteralPath $DeploymentPath -Force
}

Write-Host 'CodexPro installer-owned state was removed.'
if (-not $RemoveTunnel -and [bool]$Deployment.tunnelConfigured) {
    Write-Host "Cloudflare tunnel '$($Deployment.tunnelName)' was preserved."
}
Write-Host 'Shared dependencies (Git, Codex CLI, package manager, cloudflared) were preserved.'

[pscustomobject]@{
    status = 'ok'
    installer = 'installer.codexpro'
    tunnelRemoved = [bool]$RemoveTunnel
    packageRestored = [bool]$PackageRestored
    packageRemoved = [bool]$PackageRemoved
} | ConvertTo-Json -Compress
