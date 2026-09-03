[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourcePackageDir,

    [string]$WorkingPackageDir = ''
)

$ErrorActionPreference = 'Stop'
$InstallerRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PatchScript = Join-Path $InstallerRoot 'lib\patch-codexpro.ps1'

if (-not (Test-Path -LiteralPath $SourcePackageDir -PathType Container)) {
    throw "Vanilla CodexPro source package was not found: $SourcePackageDir"
}
$sourcePackage = Get-Content -LiteralPath (Join-Path $SourcePackageDir 'package.json') -Raw | ConvertFrom-Json
if ($sourcePackage.name -ne 'codexpro' -or $sourcePackage.version -ne '0.29.0') {
    throw "Expected a vanilla codexpro@0.29.0 package, found $($sourcePackage.name)@$($sourcePackage.version)."
}

$TempRoot = Join-Path $env:TEMP ("qbit-codexpro-patcher-test-" + [guid]::NewGuid().ToString('N'))
$TempPackage = Join-Path $TempRoot 'codexpro'
$BackupRoot = Join-Path $TempRoot 'backups'
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
Copy-Item -LiteralPath $SourcePackageDir -Destination $TempPackage -Recurse

try {
    $First = (& $PatchScript -PackageDir $TempPackage -BackupRoot $BackupRoot) | ConvertFrom-Json
    if (-not [bool]$First.changed) {
        throw 'First patch run did not report a change for the vanilla package.'
    }
    if (-not $First.backupDir -or -not (Test-Path -LiteralPath ([string]$First.backupDir) -PathType Container)) {
        throw 'First patch run did not create a rollback backup.'
    }

    $Second = (& $PatchScript -PackageDir $TempPackage -BackupRoot $BackupRoot) | ConvertFrom-Json
    if ([bool]$Second.changed) {
        throw 'Second patch run was not idempotent.'
    }
    if ($Second.backupDir) {
        throw 'Idempotent second patch run unexpectedly created a backup.'
    }

    $Dist = Join-Path $TempPackage 'dist'
    $MarkerChecks = @(
        @{ File = 'bashOps.js'; Marker = 'function sandboxInvocation(config, workspace, cwd, command)' },
        @{ File = 'bashOps.js'; Marker = 'env.USERPROFILE = userProfile;' },
        @{ File = 'config.js'; Marker = 'CODEXPRO_HOST_EXEC_MODE' },
        @{ File = 'server.js'; Marker = 'registerCodexTool(config, server, "host_exec"' },
        @{ File = 'server.js'; Marker = 'registerCodexTool(config, server, "open_app"' },
        @{ File = 'hostOps.js'; Marker = 'function requestLocalApproval(request)' }
    )
    foreach ($Check in $MarkerChecks) {
        $Path = Join-Path $Dist $Check.File
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Patched file was not created: $Path"
        }
        if (-not [IO.File]::ReadAllText($Path).Contains($Check.Marker)) {
            throw "Patch marker is missing from $($Check.File): $($Check.Marker)"
        }
    }

    $Comparison = [ordered]@{}
    if ($WorkingPackageDir) {
        if (-not (Test-Path -LiteralPath $WorkingPackageDir -PathType Container)) {
            throw "Working comparison package was not found: $WorkingPackageDir"
        }
        $WorkingDist = Join-Path $WorkingPackageDir 'dist'
        foreach ($File in @('bashOps.js', 'config.js', 'server.js')) {
            $Actual = [IO.File]::ReadAllText((Join-Path $Dist $File)).Replace("`r`n", "`n")
            $Expected = [IO.File]::ReadAllText((Join-Path $WorkingDist $File)).Replace("`r`n", "`n")
            $Matches = $Actual -eq $Expected
            $Comparison[$File] = $Matches
            if (-not $Matches) {
                throw "Patched $File differs semantically from the validated working CodexPro package."
            }
        }
    }

    [pscustomobject]@{
        status = 'ok'
        firstRunChanged = [bool]$First.changed
        secondRunChanged = [bool]$Second.changed
        rollbackBackupCreated = [bool]$First.backupDir
        markersVerified = $MarkerChecks.Count
        workingPackageComparison = $Comparison
    } | ConvertTo-Json -Depth 4 -Compress
}
finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
