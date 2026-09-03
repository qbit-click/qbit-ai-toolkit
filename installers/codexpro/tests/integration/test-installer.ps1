[CmdletBinding()]
param(
    [string]$WorkspaceRoot = '',
    [string]$Hostname = 'codexpro.test.example.com',
    [string]$TunnelName = 'codexpro-test'
)

$ErrorActionPreference = 'Stop'
$InstallerRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = (Resolve-Path -LiteralPath (Join-Path $InstallerRoot '..\..')).Path
}
elseif (-not (Test-Path -LiteralPath $WorkspaceRoot -PathType Container)) {
    throw "WorkspaceRoot does not exist: $WorkspaceRoot"
}
else {
    $WorkspaceRoot = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
}

$InstallScript = Join-Path $InstallerRoot 'install.ps1'
$UninstallScript = Join-Path $InstallerRoot 'uninstall.ps1'
$TempRoot = Join-Path $env:TEMP ("qbit-codexpro-installer-test-" + [guid]::NewGuid().ToString('N'))
$StateDir = Join-Path $TempRoot 'state'
$ProfilePath = Join-Path $TempRoot 'profile\Microsoft.PowerShell_profile.ps1'
$Sentinel = '# QBIT_CODEXPRO_TEST_PROFILE_SENTINEL'
$CodexProBefore = Get-Command codexpro -ErrorAction SilentlyContinue | Select-Object -First 1
$CodexProBeforePath = if ($CodexProBefore) { $CodexProBefore.Source } else { $null }
$Installed = $false

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $ProfilePath) -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($ProfilePath, "$Sentinel`r`n", $Utf8NoBom)

try {
    & $InstallScript `
        -WorkspaceRoot $WorkspaceRoot `
        -Hostname $Hostname `
        -TunnelName $TunnelName `
        -StateDir $StateDir `
        -ProfilePath $ProfilePath `
        -SkipTunnelSetup `
        -SkipCodexLogin | Out-Host
    $Installed = $true

    $DeploymentPath = Join-Path $StateDir 'deployment.json'
    $LauncherPath = Join-Path $StateDir 'Start-CodexPro.ps1'
    $UrlHelperPath = Join-Path $StateDir 'Get-CodexProConnectorUrl.ps1'
    Assert-True (Test-Path -LiteralPath $DeploymentPath -PathType Leaf) 'deployment.json was not created.'
    Assert-True (Test-Path -LiteralPath $LauncherPath -PathType Leaf) 'Start-CodexPro.ps1 was not created.'
    Assert-True (Test-Path -LiteralPath $UrlHelperPath -PathType Leaf) 'Get-CodexProConnectorUrl.ps1 was not created.'

    $ConnectorUrl = (& $UrlHelperPath | Select-Object -Last 1).Trim()
    $ConnectorUri = [Uri]$ConnectorUrl
    $QueryParts = $ConnectorUri.Query.TrimStart('?').Split('=', 2)
    Assert-True ($ConnectorUri.Scheme -eq 'https' -and $ConnectorUri.Host -eq $Hostname -and $ConnectorUri.AbsolutePath -eq '/mcp') 'Connector URL helper produced an unexpected endpoint.'
    Assert-True ($QueryParts.Count -eq 2 -and $QueryParts[1] -match '^[0-9a-f]{64}$') 'Connector URL helper did not include a valid 256-bit hexadecimal credential.'

    $Deployment = Get-Content -LiteralPath $DeploymentPath -Raw | ConvertFrom-Json
    Assert-True ([string]$Deployment.profilePath -eq $ProfilePath) 'deployment.json did not record the requested ProfilePath.'
    Assert-True ([bool]$Deployment.profileManaged) 'deployment.json did not mark the profile as managed.'
    Assert-True ([string]$Deployment.tunnelProtocol -eq 'http2') 'Default tunnel protocol is not http2.'

    $ProfileText = [IO.File]::ReadAllText($ProfilePath)
    Assert-True ($ProfileText.Contains($Sentinel)) 'Existing PowerShell profile content was lost during install.'
    Assert-True ($ProfileText.Contains('# >>> qbit codexpro >>>')) 'Managed cpx block start marker was not installed.'
    Assert-True ($ProfileText.Contains('# <<< qbit codexpro <<<')) 'Managed cpx block end marker was not installed.'
    Assert-True ($ProfileText.Contains($LauncherPath)) 'Managed cpx block does not reference the launcher in the configured StateDir.'

    $EscapedProfilePath = $ProfilePath.Replace("'", "''")
    $ChildScript = ". '$EscapedProfilePath'; `$command = Get-Command cpx -ErrorAction Stop; if (`$command.CommandType -ne 'Function') { throw 'cpx did not load as a PowerShell function.' }; 'CPX_PROFILE_LOAD_OK'"
    $Pwsh = Get-Command pwsh -ErrorAction Stop | Select-Object -First 1
    $ChildOutput = & $Pwsh.Source -NoProfile -Command $ChildScript
    if ($LASTEXITCODE -ne 0) {
        throw "Loading the managed profile in a clean PowerShell process failed with exit code $LASTEXITCODE."
    }
    Assert-True (($ChildOutput -join "`n").Contains('CPX_PROFILE_LOAD_OK')) 'Managed cpx helper could not be loaded in a clean PowerShell process.'

    & $UninstallScript -StateDir $StateDir | Out-Host
    $Installed = $false

    $AfterProfile = [IO.File]::ReadAllText($ProfilePath)
    Assert-True ($AfterProfile.Contains($Sentinel)) 'Existing PowerShell profile content was lost during uninstall.'
    Assert-True (-not $AfterProfile.Contains('# >>> qbit codexpro >>>')) 'Managed cpx block start marker remained after uninstall.'
    Assert-True (-not $AfterProfile.Contains('# <<< qbit codexpro <<<')) 'Managed cpx block end marker remained after uninstall.'
    Assert-True (-not (Test-Path -LiteralPath $DeploymentPath -PathType Leaf)) 'deployment.json remained after uninstall.'

    if ($CodexProBeforePath) {
        $CodexProAfter = Get-Command codexpro -ErrorAction Stop | Select-Object -First 1
        Assert-True ($CodexProAfter.Source -eq $CodexProBeforePath) 'A pre-existing CodexPro installation was changed or removed by the isolated lifecycle test.'
    }

    [pscustomobject]@{
        status = 'ok'
        installer = 'installer.codexpro'
        connectorUrlValidated = $true
        profileManaged = $true
        profilePreserved = $true
        cpxLoaded = $true
        uninstallCleanedProfile = $true
        preExistingCodexProPreserved = [bool]$CodexProBeforePath
    } | ConvertTo-Json -Compress
}
finally {
    if ($Installed -and (Test-Path -LiteralPath (Join-Path $StateDir 'deployment.json') -PathType Leaf)) {
        try {
            & $UninstallScript -StateDir $StateDir | Out-Null
        }
        catch {
            Write-Warning "Cleanup uninstall failed: $($_.Exception.Message)"
        }
    }
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
