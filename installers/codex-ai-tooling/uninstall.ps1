[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Target,
  [switch]$DryRun,
  [ValidateSet('fail','replace')] [string]$OwnedModified = 'fail',
  [switch]$RemoveDockerImage
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/installer.ps1')

function Get-BlockMarkersForPath([string]$Rel) {
  if ($Rel -ceq 'AGENTS.md') { return @($AgentsBeginMarker, $AgentsEndMarker) }
  return @($BeginMarker, $EndMarker)
}

$Root=ConvertTo-CanonicalPath $Target
$StateFile=Join-UnderRoot $Root $StatePath
if(-not(Test-Path -LiteralPath $StateFile -PathType Leaf)){throw "Missing state file: $StatePath"}
$State=Read-ValidatedInstallerState $StateFile
Assert-PortableOwnershipState $Root $State
if($State.installerId -cne $InstallerId){throw 'State file does not belong to codex-ai-tooling.'}
if($State.installerVersion -cne $InstallerVersion){throw 'State file installerVersion is invalid.'}

$ManagedFileOperations = @()
$Retained = @()
foreach($Property in $State.managedFiles.PSObject.Properties){
  $Rel=$Property.Name
  Assert-SafeDestinationPath $Root $Rel
  $Path=Join-UnderRoot $Root $Rel
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ $Retained += "$Rel (missing managed file)"; continue }
  $ExpectedHash = [string]$Property.Value
  if($ExpectedHash -notmatch '^[0-9a-f]{64}$'){throw "Managed file state for $Rel has invalid sha256."}
  if((Get-FileSha256 $Path) -ne $ExpectedHash -and $OwnedModified -ne 'replace'){ $Retained += "$Rel (user-modified managed file)"; continue }
  $ManagedFileOperations += [ordered]@{ RelativePath=$Rel; Path=$Path }
}

$BlockOperations = @()
foreach($Property in $State.managedBlocks.PSObject.Properties){
  $Rel=$Property.Name
  Assert-SafeDestinationPath $Root $Rel
  $Path=Join-UnderRoot $Root $Rel
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ $Retained += "$Rel (missing managed-block file)"; continue }
  $Markers = Get-BlockMarkersForPath $Rel
  $Text = Read-TextFile $Path
  try {
    $RemoveArgs = @{}
    if($OwnedModified -eq 'replace'){ $RemoveArgs.ReplaceModifiedOwned = $true }
    $Remaining = Remove-ManagedBlockFromText $Text $Property.Value $Markers[0] $Markers[1] $Rel @RemoveArgs
  } catch {
    $Retained += "$Rel (modified or malformed managed block)"
    continue
  }
  $Record = ConvertTo-ManagedBlockRecord $Property.Value $Rel
  $DeleteFile = [bool]$Record.createdFile -and $Remaining.Length -eq 0
  $BlockOperations += [ordered]@{ RelativePath=$Rel; Path=$Path; Remaining=$Remaining; DeleteFile=$DeleteFile }
}

Write-Host 'Planned uninstall operations:'
foreach($Operation in $BlockOperations){Write-Host "  remove managed block $($Operation.RelativePath)"}
foreach($Operation in $ManagedFileOperations){Write-Host "  remove $($Operation.RelativePath)"}
foreach($Item in $Retained){Write-Host "  retain $Item"}
if($Retained.Count -eq 0){Write-Host "  remove $StatePath"}else{Write-Host "  retain $StatePath (ownership evidence remains required)"}
if($DryRun){Write-Host 'DryRun completed; no files were changed.'; if($Retained.Count){throw 'Uninstall retained modified or uncertain content.'}; return}
if($Retained.Count){throw 'Uninstall retained modified or uncertain content; no target mutation was performed.'}

$WritePlan = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$RemovePaths = New-Object System.Collections.Generic.List[string]
foreach($Operation in $BlockOperations){
  if($Operation.DeleteFile){
    $RemovePaths.Add($Operation.RelativePath)
  } else {
    $WritePlan[$Operation.RelativePath] = [ordered]@{ RelativePath=$Operation.RelativePath; Content=$Operation.Remaining; Kind='merge'; WriteMode=$WriteModeCanonicalExact }
  }
}
foreach($Operation in $ManagedFileOperations){$RemovePaths.Add($Operation.RelativePath)}
$RemovePaths.Add($StatePath)
Invoke-TransactionalWrite $Root $WritePlan -RemovePaths @($RemovePaths) -StateRelativePath ''

foreach($Dir in @('.agents/skills/architecture-impact-analysis','.agents/skills/browser-verification','.agents/skills/external-library-docs','.agents/skills/incident-analysis','.agents/skills/security-review','.agents/skills','.agents','.ai/scripts','.ai/policies','.ai/tooling/language-servers','.ai/tooling/node','.ai/tooling/python','.ai/tooling','.ai','.codex','.playwright','.serena','docs/ai-tooling','.qbit/toolkit/installed','.qbit/toolkit','.qbit')) {
  $Path=Join-UnderRoot $Root $Dir
  if((Test-Path -LiteralPath $Path -PathType Container) -and -not (Get-ChildItem -LiteralPath $Path -Force)){ Remove-Item -LiteralPath $Path -Force }
}
if($RemoveDockerImage -and $State.dockerImageName){ & docker image rm $State.dockerImageName }
Write-Host 'codex-ai-tooling uninstall completed.'
