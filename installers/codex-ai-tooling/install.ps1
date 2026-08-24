[CmdletBinding()]
param(
  [string]$Operation = 'install',
  [string]$Target = '',
  [string]$Profile = 'auto',
  [string]$Format = 'text',
  [switch]$NonInteractive,
  [switch]$DryRun,
  [string]$OwnedModified = 'fail',
  [switch]$AdoptMatching,
  [switch]$MigrateLegacy,
  [string]$ProjectSlug,
  [string]$ProjectDisplayName,
  [string[]]$AllowedOrigin,
  [switch]$SkipBootstrap,
  [switch]$SkipDoctor
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$InstallerVersion = '1.1.2'
$StatePath = '.qbit/toolkit/installed/codex-ai-tooling.json'
$env:QBIT_TOOLKIT_OPERATION = $Operation
function Stop-ArgumentError([string]$Message) {
  [Console]::Error.WriteLine($Message)
  if ($Format -ceq 'json') {
    $ErrorItem = [pscustomobject][ordered]@{ code='QBIT-2'; category='arguments'; message=$Message; recoverable=$true; remediation='Correct the command arguments and retry.' }
    $Value = [ordered]@{
      schema_version='1.0'; installer_version=$InstallerVersion; operation=$Operation; target=$Target; profile=$Profile
      dry_run=[bool]$DryRun; success=$false; exit_code=2; detected_state='unknown'
      planned_actions=[object[]]@(); performed_actions=[object[]]@(); skipped_actions=[object[]]@()
      conflicts=[object[]]@(); warnings=[object[]]@(); errors=[object[]]@($ErrorItem)
      rollback=[ordered]@{attempted=$false;success=$null;actions=[object[]]@();errors=[object[]]@()}
      verification=[ordered]@{performed=$false;success=$null;checks=[object[]]@()}
    }
    $Value | ConvertTo-Json -Depth 8 -Compress
  }
  exit 2
}
if ([string]::IsNullOrWhiteSpace($Target)) { Stop-ArgumentError 'Target is required.' }
if ($Operation -cnotin @('plan','install','update','repair','verify','doctor','uninstall')) { Stop-ArgumentError 'Invalid operation.' }
if ($Profile -cnotin @('auto','generic','typescript','rust')) { Stop-ArgumentError 'Invalid profile.' }
if ($Format -cnotin @('text','json')) { Stop-ArgumentError 'Invalid output format.' }
if ($OwnedModified -cnotin @('fail','replace')) { Stop-ArgumentError 'Invalid owned-modified policy.' }
$CanonicalTarget = $Target
try { $CanonicalTarget = (Resolve-Path -LiteralPath $Target -ErrorAction Stop).ProviderPath } catch {}
$DetectedState = if (Test-Path -LiteralPath (Join-Path $CanonicalTarget $StatePath) -PathType Leaf) { 'installed' } else { 'absent' }
$Messages = New-Object System.Collections.Generic.List[string]
$Actions = New-Object System.Collections.Generic.List[string]
$Code = 0

function Invoke-Captured([scriptblock]$Body) {
  try {
    $items = @(& $Body *>&1)
    foreach ($item in $items) { $script:Messages.Add([string]$item) }
    return $true
  } catch {
    $script:Messages.Add($_.Exception.Message)
    return $false
  }
}

function Get-FailureCode([string]$Message) {
  $text = $Message.ToLowerInvariant()
  if ($text -match 'target.*(does not exist|git work tree|root)|refusing to target') { return 3 }
  if ($text -match 'conflict at|was modified|managed block.*modified|managed block.*markers?|managed markers|previously managed block|uninstall retained|no recognized historical|no coherent audited') { return 4 }
  if ($text -match 'unsafe|cannot overwrite directory|ownership metadata is invalid|hash mismatch|hash integrity|state.*invalid') { return 5 }
  if ($text -match 'rollback succeeded') { return 6 }
  if ($text -match 'rollback.*(failed|errors)|recovery') { return 7 }
  if ($text -match "term 'git' is not recognized|docker.*unavailable|compose.*required|mandatory prerequisite") { return 10 }
  return 12
}

$EngineArgs = @{
  Target = $Target
  Profile = $Profile
  SkipBootstrap = $true
  SkipDoctor = $true
}
if ($ProjectSlug) { $EngineArgs.ProjectSlug = $ProjectSlug }
if ($ProjectDisplayName) { $EngineArgs.ProjectDisplayName = $ProjectDisplayName }
if ($AllowedOrigin) { $EngineArgs.AllowedOrigins = $AllowedOrigin }
$EngineArgs.OwnedModifiedPolicy = $OwnedModified
$EngineArgs.AdoptMatching = $AdoptMatching
$EngineArgs.MigrateLegacy = $MigrateLegacy

switch ($Operation) {
  'plan' {
    $EngineArgs.DryRun = $true
    if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'lib/install-engine.ps1') @EngineArgs })) { $Code = Get-FailureCode ($Messages -join ' ') }
  }
  'install' {
    if ($DryRun) { $EngineArgs.DryRun = $true }
    if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'lib/install-engine.ps1') @EngineArgs })) { $Code = Get-FailureCode ($Messages -join ' ') }
  }
  { $_ -in @('update','repair') } {
    if ($DetectedState -ne 'installed') {
      $Messages.Add("$Operation requires a valid ownership manifest.")
      $Code = 5
    } else {
      if ($DryRun) { $EngineArgs.DryRun = $true }
      if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'lib/install-engine.ps1') @EngineArgs })) { $Code = Get-FailureCode ($Messages -join ' ') }
    }
  }
  'verify' {
    if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'verify.ps1') -Target $Target })) { $Code = 8 }
  }
  'doctor' {
    if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'verify.ps1') -Target $Target })) {
      $Code = 8
    } else {
      $Doctor = Join-Path $CanonicalTarget '.ai/scripts/doctor.ps1'
      if (-not (Test-Path -LiteralPath $Doctor -PathType Leaf)) {
        $Messages.Add('Installed Doctor entrypoint is missing.')
        $Code = 8
      } elseif (-not (Invoke-Captured { & $Doctor })) { $Code = 8 }
    }
  }
  'uninstall' {
    $UninstallArgs = @{ Target = $Target; OwnedModified = $OwnedModified }
    if ($DryRun) { $UninstallArgs.DryRun = $true }
    if (-not (Invoke-Captured { & (Join-Path $PSScriptRoot 'uninstall.ps1') @UninstallArgs })) { $Code = Get-FailureCode ($Messages -join ' ') }
  }
}

foreach ($Message in $Messages) {
  if ($Message -match '^\s+(create|update|remove)\s+(.+)$') { $Actions.Add("$($Matches[1]) $($Matches[2])") }
}
$ActionSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($Action in $Actions) { $null = $ActionSet.Add($Action) }
[string[]]$SortedActions = @($ActionSet)
[Array]::Sort($SortedActions, [StringComparer]::Ordinal)
if ($Format -eq 'text') {
  foreach ($Message in $Messages) { Write-Output $Message }
  exit $Code
}

foreach ($Message in $Messages) { [Console]::Error.WriteLine($Message) }
$Success = $Code -eq 0
[object[]]$Performed = @()
if ($Success -and -not $DryRun -and $Operation -notin @('plan','verify','doctor')) { $Performed = @($SortedActions) }
[object[]]$Errors = @()
if (-not $Success) {
  $Errors = @([pscustomobject][ordered]@{
    code = "QBIT-$Code"
    category = 'operation'
    message = ($Messages -join ' ')
    recoverable = $Code -notin @(5,7)
    remediation = 'Review stderr, resolve the reported condition, and retry.'
  })
}
$VerificationPerformed = $Operation -in @('verify','doctor')
[object[]]$Conflicts = @()
if ($Code -eq 4) { $Conflicts = @($Messages -join ' ') }
$RollbackAttempted = $Code -in @(6,7)
$RollbackSuccess = if ($Code -eq 6) { $true } elseif ($Code -eq 7) { $false } else { $null }
$Result = [ordered]@{
  schema_version = '1.0'
  installer_version = $InstallerVersion
  operation = $Operation
  target = $CanonicalTarget
  profile = $Profile
  dry_run = [bool]($DryRun -or $Operation -eq 'plan')
  success = $Success
  exit_code = $Code
  detected_state = $DetectedState
  planned_actions = [object[]]$SortedActions
  performed_actions = [object[]]$Performed
  skipped_actions = [object[]]@()
  conflicts = [object[]]$Conflicts
  warnings = [object[]]@()
  errors = [object[]]$Errors
  rollback = [ordered]@{ attempted = $RollbackAttempted; success = $RollbackSuccess; actions = [object[]]@(); errors = [object[]]@() }
  verification = [ordered]@{
    performed = $VerificationPerformed
    success = if ($VerificationPerformed) { $Success } else { $null }
    checks = [object[]]@()
  }
}
$Result | ConvertTo-Json -Depth 8 -Compress
exit $Code
