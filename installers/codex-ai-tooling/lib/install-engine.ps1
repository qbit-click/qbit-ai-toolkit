[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$Target,
  [ValidateSet('auto', 'generic', 'typescript', 'rust')] [string]$Profile = 'auto',
  [string]$ProjectSlug,
  [string]$ProjectDisplayName,
  [string[]]$AllowedOrigins,
  [switch]$DryRun,
  [ValidateSet('fail','replace')] [string]$OwnedModifiedPolicy = 'fail',
  [switch]$AdoptMatching,
  [switch]$MigrateLegacy,
  [switch]$SkipBootstrap,
  [switch]$SkipDoctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'installer.ps1')

$TargetRoot = Resolve-TargetRoot $Target
$TargetName = Split-Path -Leaf $TargetRoot
$SelectedProfile = Resolve-Profile $Profile $TargetRoot
$Slug = Get-ProjectSlug $ProjectSlug $TargetName
$DisplayNameInput = if ([string]::IsNullOrWhiteSpace($ProjectDisplayName)) { $TargetName } else { $ProjectDisplayName }
$DisplayName = Test-ProjectDisplayName $DisplayNameInput
$OriginsWereExplicit = $PSBoundParameters.ContainsKey('AllowedOrigins') -and $AllowedOrigins.Count -gt 0
$OriginInputs = if ($OriginsWereExplicit) { $AllowedOrigins } else { @('http://localhost:3000', 'http://127.0.0.1:3000') }
$NormalizedOriginsList = [Collections.Generic.List[string]]::new()
$SeenOrigins = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($OriginInput in $OriginInputs) {
  $NormalizedOrigin = Test-AllowedOrigin $OriginInput $OriginsWereExplicit
  if ($SeenOrigins.Add($NormalizedOrigin)) { $NormalizedOriginsList.Add($NormalizedOrigin) }
}
$NormalizedOrigins = @($NormalizedOriginsList)
if ($NormalizedOrigins.Count -eq 0) { throw 'At least one allowed origin is required.' }

$Status = & git -C $TargetRoot status --porcelain
if ($Status) { Write-Warning 'Target has uncommitted changes. The installer will not stage, reset, stash, commit, or clean them.' }
$InitialGitIndex = (& git -C $TargetRoot ls-files --stage) -join "`n"
if (-not $DryRun) { Invoke-PendingTransactionRecovery $TargetRoot }

$ComposeProjectName = "$Slug-ai-tooling"
$DockerImageName = "$Slug-ai-tooling:serena-1.5.3-graphify-0.9.12"
$Values = @{
  PROJECT_SLUG = $Slug
  PROJECT_DISPLAY_NAME_JSON = ConvertTo-JsonStringContent $DisplayName
  COMPOSE_PROJECT_NAME = $ComposeProjectName
  DOCKER_IMAGE_NAME = $DockerImageName
  SERENA_PROJECT_NAME = $Slug
  ALLOWED_ORIGINS_JSON = (ConvertTo-Json -InputObject @($NormalizedOrigins) -Compress)
  ALLOWED_ORIGINS_CSV = ($NormalizedOrigins -join ',')
  SELECTED_PROFILE = $SelectedProfile
  SERENA_ENABLED = if ($SelectedProfile -in @('typescript', 'rust')) { 'true' } else { 'false' }
  LANGUAGE_SUMMARY = if ($SelectedProfile -eq 'typescript') { 'TypeScript repository' } elseif ($SelectedProfile -eq 'rust') { 'Rust repository' } else { 'generic repository' }
  PROJECT_DESCRIPTION = if ($SelectedProfile -eq 'typescript') { 'a TypeScript repository.' } elseif ($SelectedProfile -eq 'rust') { 'a Rust repository.' } else { 'a generic repository.' }
  SERENA_VERSION = '1.5.3'
  GRAPHIFY_VERSION = '0.9.12'
  TYPESCRIPT_VERSION = '5.9.3'
  TYPESCRIPT_LANGUAGE_SERVER_VERSION = '5.1.3'
  RUST_TOOLCHAIN_VERSION = '1.85.0'
  RUST_BASE_IMAGE = 'rust:1.85.0-slim-bookworm@sha256:c842cc0357b91bb15ad2bb89934513d0d226f711fac7f7fedb176d3311714d47'
}

$InstallerRoot = Split-Path -Parent $PSScriptRoot
function Assert-InstallerPayloadIntegrity([string]$Root) {
  $ManifestPath = Join-Path $Root 'payload.sha256'
  if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw 'Payload checksum manifest is missing.' }
  $Expected = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
  foreach ($Line in @(Get-Content -LiteralPath $ManifestPath)) {
    if ($Line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Payload checksum manifest is malformed.' }
    if ($Expected.ContainsKey($Matches[2])) { throw "Duplicate payload checksum path: $($Matches[2])" }
    $Expected.Add($Matches[2],$Matches[1])
  }
  $Actual = New-Object System.Collections.Generic.List[string]
  foreach ($DirectoryName in @('templates','fragments')) {
    $Directory = Join-Path $Root $DirectoryName
    foreach ($File in @(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force)) {
      $Actual.Add((Get-RelativePath $Root $File.FullName))
    }
  }
  Assert-ExactStringSet @($Actual) @($Expected.Keys) 'payload checksum paths'
  foreach ($RelativePath in $Expected.Keys) {
    if ((Get-FileSha256 (Join-Path $Root $RelativePath)) -cne $Expected[$RelativePath]) { throw "Payload hash mismatch: $RelativePath" }
  }
}
Assert-InstallerPayloadIntegrity $InstallerRoot
$Plan = Get-TemplatePlan $InstallerRoot $SelectedProfile $Values
$PreviousState = $null
$StateFullPath = Join-UnderRoot $TargetRoot $StatePath
if (Test-Path -LiteralPath $StateFullPath -PathType Leaf) {
  $PreviousState = Read-ValidatedInstallerState $StateFullPath
  Assert-PortableOwnershipState $TargetRoot $PreviousState
}
function Get-CoherentLegacyVariant([string]$Root) {
  # Each entry is an audited, path-specific historical payload fingerprint.  A
  # matching file authorizes replacement only for that same path; two distinct
  # variants are intentionally incompatible rather than being mixed together.
  $Variants = @(
    [pscustomobject]@{ Id = 'graphify-build-v1'; Files = @{ '.ai/scripts/graphify-build.ps1' = 'f83ce32dd3aafd94a1b4dcefa170141bc93c1332775235b45a192c9c5bccc74d' } },
    [pscustomobject]@{ Id = 'architecture-skill-v1'; Files = @{ '.agents/skills/architecture-impact-analysis/SKILL.md' = '3441300fe10813a5eaddaef8fcd9c611d25c3190f9157b62b0d180705a0df99b' } },
    [pscustomobject]@{ Id = 'architecture-skill-v2'; Files = @{ '.agents/skills/architecture-impact-analysis/SKILL.md' = 'f30d4f56abb56b2be4f09aa4bc65ad0d58a41f825908b6aa67213313309313d1' } },
    [pscustomobject]@{ Id = 'architecture-skill-v3'; Files = @{ '.agents/skills/architecture-impact-analysis/SKILL.md' = '21f406a21c3f8ce4218c0d34d0dad0f47849dc6e17e01acf65cace0d937fe1c0' } },
    [pscustomobject]@{ Id = 'serena-project-v1'; Files = @{ '.serena/project.yml' = '37c169cee6a4e44b4073b7de6ecf9a5805f9cfe717dcf1de5e6a25e8e0feff14' } },
    [pscustomobject]@{ Id = 'serena-project-v2'; Files = @{ '.serena/project.yml' = 'b47976f16f34978421d3dcdfea2453911a30984cd5027e8f7577bf9d3d11cdb9' } }
  )
  $Matches = @()
  foreach ($Variant in $Variants) {
    foreach ($RelativePath in $Variant.Files.Keys) {
      $Path = Join-UnderRoot $Root $RelativePath
      if ((Test-Path -LiteralPath $Path -PathType Leaf) -and ((Get-FileSha256 $Path) -ceq $Variant.Files[$RelativePath])) {
        $Matches += $Variant
        break
      }
    }
  }
  if ($Matches.Count -gt 1) { throw 'Legacy migration found incompatible audited payload variants; no files were changed.' }
  if ($Matches.Count -eq 1) { return $Matches[0] }
  return $null
}
function Test-RecognizedLegacyManagedBlock([string]$Root) {
  foreach ($Entry in @(
    @{ Path = '.gitignore'; Begin = '# >>> qbit-toolkit:codex-ai-tooling'; End = '# <<< qbit-toolkit:codex-ai-tooling' },
    @{ Path = '.gitattributes'; Begin = '# >>> qbit-toolkit:codex-ai-tooling'; End = '# <<< qbit-toolkit:codex-ai-tooling' },
    @{ Path = 'AGENTS.md'; Begin = '<!-- >>> qbit-toolkit:codex-ai-tooling -->'; End = '<!-- <<< qbit-toolkit:codex-ai-tooling -->' }
  )) {
    $Path = Join-UnderRoot $Root $Entry.Path
    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and (Get-ManagedBlockAnalysis (Read-TextFile $Path) $Entry.Begin $Entry.End $Entry.Path).Status -eq 'valid') { return $true }
  }
  return $false
}
$LegacyVariant = $null
$AllowUnownedLegacyBlocks = $false
if ($MigrateLegacy -and -not $PreviousState) {
  $LegacyVariant = Get-CoherentLegacyVariant $TargetRoot
  $AllowUnownedLegacyBlocks = Test-RecognizedLegacyManagedBlock $TargetRoot
  if (-not $LegacyVariant -and -not $AllowUnownedLegacyBlocks) { throw 'Legacy migration was requested but no coherent audited payload fingerprint or managed block was found.' }
}
$DestinationPaths = @($Plan.Keys) + @('.gitignore','.gitattributes','AGENTS.md',$StatePath)
if ($PreviousState) {
  $DestinationPaths += @($PreviousState.managedFiles.PSObject.Properties.Name)
  $DestinationPaths += @($PreviousState.managedBlocks.PSObject.Properties.Name)
}
foreach ($RelativePath in @(Sort-QbitPaths @($DestinationPaths | Select-Object -Unique))) {
  Assert-SafeDestinationPath $TargetRoot $RelativePath
}
function Resolve-BlockWithLegacyMigration(
  [string]$Existing,
  [bool]$FileExists,
  [string]$Body,
  [string]$Begin,
  [string]$End,
  [string]$LegacyBegin,
  [string]$LegacyEnd,
  [object]$PreviousRecord,
  [string]$RelativePath,
  [ValidateSet('fail','replace')] [string]$Policy,
  [bool]$AllowUnownedLegacy
) {
  $Current = Get-ManagedBlockAnalysis $Existing $Begin $End $RelativePath
  $Legacy = Get-ManagedBlockAnalysis $Existing $LegacyBegin $LegacyEnd $RelativePath
  if ($Current.Status -eq 'valid') {
    if ($Legacy.Status -ne 'absent') { throw "Both current and legacy managed markers exist in $RelativePath." }
    return Resolve-ManagedBlockUpdate $Existing $FileExists $Body $Begin $End $PreviousRecord $RelativePath $Policy
  }
  if ($Legacy.Status -eq 'valid') {
    if (-not $PreviousRecord -and -not $AllowUnownedLegacy) { throw "Unowned legacy managed markers exist in $RelativePath." }
    $Record = if ($PreviousRecord) { ConvertTo-ManagedBlockRecord $PreviousRecord $RelativePath } else { [ordered]@{ sha256 = ''; createdFile = $false; insertedSeparatorLfCount = 0 } }
    if ($PreviousRecord -and (Get-TextSha256 $Legacy.Block) -cne $Record.sha256 -and $Policy -cne 'replace') { throw "Managed block was modified after installation: $RelativePath. Use owned-modified=replace to back it up and remove it." }
    $BlockText = Get-ManagedBlockText $Body $Begin $End
    $Record.sha256 = Get-TextSha256 $BlockText
    return [pscustomobject]@{
      Content = $Legacy.Prefix + $BlockText + $Legacy.Suffix
      BlockText = $BlockText
      Record = $Record
      Analysis = $Legacy
    }
  }
  if ($Legacy.Status -ne 'absent') { throw "Legacy managed markers are malformed in $RelativePath." }
  return Resolve-ManagedBlockUpdate $Existing $FileExists $Body $Begin $End $PreviousRecord $RelativePath $Policy
}
$BlockRecords = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($MergeTarget in @('.gitignore', '.gitattributes')) {
  $FragmentName = if ($MergeTarget -ceq '.gitignore') { 'gitignore.txt' } else { 'gitattributes.txt' }
  $Fragment = Render-Template (Read-TextFile (Join-Path $InstallerRoot "fragments/$FragmentName")) $Values
  $TargetPath = Join-Path $TargetRoot $MergeTarget
  $FileExists = Test-Path -LiteralPath $TargetPath -PathType Leaf
  $Existing = if ($FileExists) { Read-TextFile $TargetPath } else { '' }
  $Update = Resolve-BlockWithLegacyMigration $Existing $FileExists $Fragment $BeginMarker $EndMarker '# >>> qbit-toolkit:codex-ai-tooling' '# <<< qbit-toolkit:codex-ai-tooling' (Get-ManagedBlockRecordValue $PreviousState $MergeTarget) $MergeTarget $OwnedModifiedPolicy $AllowUnownedLegacyBlocks
  $BlockRecords[$MergeTarget] = $Update.Record
  $Plan[$MergeTarget] = [ordered]@{ RelativePath = $MergeTarget; Content = $Update.Content; Kind = 'merge'; WriteMode = $WriteModeCanonicalExact }
}
$AgentsFragment = Render-Template (Read-TextFile (Join-Path $InstallerRoot 'fragments/agents.md')) $Values
$AgentsPath = Join-Path $TargetRoot 'AGENTS.md'
$AgentsExists = Test-Path -LiteralPath $AgentsPath -PathType Leaf
$ExistingAgents = if ($AgentsExists) { Read-TextFile $AgentsPath } else { '' }
$AgentsUpdate = Resolve-BlockWithLegacyMigration $ExistingAgents $AgentsExists $AgentsFragment $AgentsBeginMarker $AgentsEndMarker '<!-- >>> qbit-toolkit:codex-ai-tooling -->' '<!-- <<< qbit-toolkit:codex-ai-tooling -->' (Get-ManagedBlockRecordValue $PreviousState 'AGENTS.md') 'AGENTS.md' $OwnedModifiedPolicy $AllowUnownedLegacyBlocks
$BlockRecords['AGENTS.md'] = $AgentsUpdate.Record
$Plan['AGENTS.md'] = [ordered]@{ RelativePath = 'AGENTS.md'; Content = $AgentsUpdate.Content; Kind = 'merge'; WriteMode = $WriteModeCanonicalExact }

$PortableManifestPath = '.qbit-toolkit/codex-ai-tooling/manifest.json'
$PreviousOwned = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
if ($PreviousState) {
  foreach ($Name in $PreviousState.managedFiles.PSObject.Properties.Name) { $null = $PreviousOwned.Add($Name) }
}
foreach ($RelativePath in @(Sort-QbitPaths @($Plan.Keys))) {
  if ($RelativePath -ceq $PortableManifestPath -or $Plan[$RelativePath].Kind -ne 'file' -or $PreviousOwned.Contains($RelativePath)) { continue }
  $Destination = Join-UnderRoot $TargetRoot $RelativePath
  if (-not $AdoptMatching -and (Test-Path -LiteralPath $Destination -PathType Leaf) -and (Test-PlanItemContentMatchesFile $Destination $Plan[$RelativePath] $RelativePath)) {
    $Plan[$RelativePath].Kind = 'observed'
  }
}
$Plan[$PortableManifestPath] = [ordered]@{
  RelativePath = $PortableManifestPath
  Content = New-PortableOwnershipManifest $Plan $BlockRecords $SelectedProfile $Slug
  Kind = 'file'
  WriteMode = $WriteModeCanonicalWithTerminalLf
}
$StateContent = New-StateContent $Plan $BlockRecords $PreviousState $SelectedProfile $Slug $DisplayName $NormalizedOrigins $DockerImageName
$Plan[$StatePath] = [ordered]@{ RelativePath = $StatePath; Content = $StateContent; Kind = 'state'; WriteMode = $WriteModeCanonicalWithTerminalLf }

$PreviousHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
if ($PreviousState -and $PreviousState.managedFiles) {
  foreach ($Property in $PreviousState.managedFiles.PSObject.Properties) { $PreviousHashes[$Property.Name] = [string]$Property.Value }
}
$DesiredManagedPaths = @(Sort-QbitPaths @($Plan.Keys | Where-Object { $Plan[$_].Kind -eq 'file' }))
$StalePaths = @()
if ($PreviousState) {
  foreach ($Property in $PreviousState.managedFiles.PSObject.Properties) {
    $RelativePath = $Property.Name
    if ($DesiredManagedPaths -ccontains $RelativePath) { continue }
    $Destination = Join-UnderRoot $TargetRoot $RelativePath
    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) { throw "State-declared stale managed file is missing or is not a regular file: $RelativePath" }
    if ((Get-FileSha256 $Destination) -ne [string]$Property.Value -and $OwnedModifiedPolicy -ne 'replace') { throw "Stale managed file was modified after installation: $RelativePath. Use OwnedModified replace to back it up and remove it." }
    $StalePaths += $RelativePath
  }
}
$Operations = @()
foreach ($RelativePath in (Sort-QbitPaths @($Plan.Keys))) {
  $Destination = Join-UnderRoot $TargetRoot $RelativePath
  $Exists = Test-Path -LiteralPath $Destination -PathType Leaf
  if ($Exists -and (Test-PlanItemContentMatchesFile $Destination $Plan[$RelativePath] $RelativePath)) { continue }
  if ($Exists -and $Plan[$RelativePath].Kind -cnotin @('merge', 'state')) {
    $CurrentHash = Get-FileSha256 $Destination
    $LegacyPathAllowed = $LegacyVariant -and $LegacyVariant.Files.ContainsKey($RelativePath) -and ($LegacyVariant.Files[$RelativePath] -ceq $CurrentHash)
    if (-not $PreviousHashes.ContainsKey($RelativePath) -and -not $LegacyPathAllowed) {
      throw "Conflict at $RelativePath. Existing content is unowned and differs from the payload."
    }
    $WasManaged = $LegacyPathAllowed -or $PreviousHashes[$RelativePath] -ceq $CurrentHash -or (Test-PlanItemLogicalTextMatchesFile $Destination $Plan[$RelativePath] $RelativePath)
    if (-not $WasManaged -and $OwnedModifiedPolicy -ne 'replace') { throw "Conflict at $RelativePath. Installer-owned content was modified; use OwnedModified replace to back it up and replace it." }
  }
  if ($Exists -and $Plan[$RelativePath].Kind -ceq 'state' -and -not $PreviousState) { throw "Conflict at $RelativePath. Existing state is not recognized." }
  $Operations += [ordered]@{ action = if ($Exists) { 'update' } else { 'create' }; path = $RelativePath }
}
foreach ($RelativePath in $StalePaths) { $Operations += [ordered]@{ action = 'remove'; path = $RelativePath } }

Write-Host "Installer: $InstallerId $InstallerVersion"
Write-Host "Target: $TargetRoot"
Write-Host "Profile: $SelectedProfile"
Write-Host "Project slug: $Slug"
Write-Host "Allowed origins: $($NormalizedOrigins -join ', ')"
Write-Host 'Planned operations:'
if ($Operations.Count -eq 0) { Write-Host '  no file changes' } else { $Operations | ForEach-Object { Write-Host "  $($_.action) $($_.path)" } }
if ($DryRun) { Write-Host 'DryRun completed; no files were written.'; return }

$WritePlan = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($Operation in $Operations) {
  if ($Operation.action -ne 'remove') { $WritePlan[$Operation.path] = $Plan[$Operation.path] }
}
if ($WritePlan.Count -gt 0 -or $StalePaths.Count -gt 0) {
  $StateWritePath = if ($WritePlan.ContainsKey($StatePath)) { $StatePath } else { '' }
  Invoke-TransactionalWrite $TargetRoot $WritePlan -RemovePaths $StalePaths -StateRelativePath $StateWritePath -DryRun:$false
}
$FinalGitIndex = (& git -C $TargetRoot ls-files --stage) -join "`n"
if ($FinalGitIndex -cne $InitialGitIndex) { throw 'Git index changed during installer mutation.' }

try {
  if (-not $SkipBootstrap) { & (Join-UnderRoot $TargetRoot '.ai/scripts/bootstrap.ps1'); if ($LASTEXITCODE -ne 0) { throw 'Bootstrap failed.' } }
  if (-not $SkipDoctor) { & (Join-UnderRoot $TargetRoot '.ai/scripts/doctor.ps1'); if ($LASTEXITCODE -ne 0) { throw 'Doctor failed.' } }
} catch {
  throw "Post-install validation failed after file writes. Review target state and rerun after corrective action: $($_.Exception.Message)"
}

Write-Host 'codex-ai-tooling installation completed.'
