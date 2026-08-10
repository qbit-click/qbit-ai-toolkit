[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:Passed = 0
$Script:Failed = 0
$Script:Skipped = 0
$InstallerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Install = Join-Path $InstallerRoot 'install.ps1'
$BashInstall = Join-Path $InstallerRoot 'install.sh'
$Verify = Join-Path $InstallerRoot 'verify.ps1'
$Uninstall = Join-Path $InstallerRoot 'uninstall.ps1'
. (Join-Path $InstallerRoot 'lib/installer.ps1')
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qbit-toolkit-tests-' + [System.Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
function New-Repo([string]$Name) {
  $Path = Join-Path $TempRoot $Name
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  & git -C $Path init -q
  if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
  return $Path
}
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function ReadText([string]$Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8).Replace("`r`n", "`n") }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }
function Snapshot([string]$Path) {
  $Items = Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object { $_.FullName -notmatch '\\.git(?:\\|$)' } | Sort-Object FullName
  return ($Items | ForEach-Object {
    $Relative = $_.FullName.Substring($Path.Length).Replace('\','/')
    if ($_.PSIsContainer) { "d:$Relative" } else { "f:${Relative}:$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
  }) -join "`n"
}
function CoreSnapshot([string]$Path) {
  $GeneratedRoot = '/.qbit-toolkit/codex-ai-tooling'
  $Items = Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object {
    $Relative = $_.FullName.Substring($Path.Length).Replace('\','/')
    $IsGit = $Relative -match '^/\.git(?:/|$)'
    $IsGeneratedDirectory = @('backups','transactions','recovery') | Where-Object {
      $Relative -eq "$GeneratedRoot/$_" -or $Relative.StartsWith("$GeneratedRoot/$_/", [StringComparison]::Ordinal)
    }
    -not $IsGit -and -not $IsGeneratedDirectory -and $Relative -cne "$GeneratedRoot/lock.json"
  } | Sort-Object FullName
  return ($Items | ForEach-Object {
    $Relative = $_.FullName.Substring($Path.Length).Replace('\','/')
    if ($_.PSIsContainer) { "d:$Relative" } else { "f:${Relative}:$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
  }) -join "`n"
}
function Get-UninstallBackupCount([string]$Path) {
  $BackupPath = Join-Path $Path '.qbit-toolkit/codex-ai-tooling/backups'
  if (-not (Test-Path -LiteralPath $BackupPath -PathType Container)) { return 0 }
  return @(Get-ChildItem -LiteralPath $BackupPath -Directory -Force).Count
}
function Get-InstallBackupCount([string]$Path) {
  $BackupPath = Join-Path $Path '.qbit-toolkit/codex-ai-tooling/backups'
  if (-not (Test-Path -LiteralPath $BackupPath -PathType Container)) { return 0 }
  return @(Get-ChildItem -LiteralPath $BackupPath -Directory -Force).Count
}
function Get-CompleteManagedBlock([string]$Text, [string]$Begin, [string]$End) {
  $Start = $Text.IndexOf($Begin, [StringComparison]::Ordinal)
  $EndStart = $Text.IndexOf($End, [StringComparison]::Ordinal)
  if ($Start -lt 0 -or $EndStart -lt $Start) { throw 'Managed block fixture is malformed.' }
  $Finish = $EndStart + $End.Length
  if ($Finish -lt $Text.Length -and $Text[$Finish] -eq "`n") { $Finish++ }
  return $Text.Substring($Start, $Finish - $Start)
}
function ConvertTo-ValidLegacyAgentsFixture([string]$Repo) {
  $LegacyBegin = '<!-- >>> qbit-toolkit:codex-ai-tooling -->'
  $LegacyEnd = '<!-- <<< qbit-toolkit:codex-ai-tooling -->'
  $AgentsPath = Join-Path $Repo 'AGENTS.md'
  $LegacyText = (ReadText $AgentsPath).Replace($AgentsBeginMarker, $LegacyBegin).Replace($AgentsEndMarker, $LegacyEnd)
  WriteText $AgentsPath $LegacyText
  $LegacyHash = Get-TextSha256 (Get-CompleteManagedBlock $LegacyText $LegacyBegin $LegacyEnd)
  $StateFile = Join-Path $Repo $StatePath
  $ManifestRelative = '.qbit-toolkit/codex-ai-tooling/manifest.json'
  $ManifestFile = Join-Path $Repo $ManifestRelative
  $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  $Manifest = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json
  $State.managedBlocks.'AGENTS.md'.sha256 = $LegacyHash
  $ManifestBlock = @($Manifest.managed_blocks | Where-Object relative_path -CEQ 'AGENTS.md')
  Assert ($ManifestBlock.Count -eq 1) 'Portable fixture lacks exactly one AGENTS.md block record.'
  $ManifestBlock[0].sha256 = $LegacyHash
  $Digest = [Text.StringBuilder]::new()
  foreach ($Entry in @($Manifest.installed_entries | Sort-Object relative_path)) { $null = $Digest.Append($Entry.relative_path).Append("`t").Append($Entry.expected_sha256).Append("`n") }
  foreach ($Block in @($Manifest.managed_blocks | Sort-Object relative_path)) { $null = $Digest.Append($Block.relative_path).Append("`t").Append($Block.sha256).Append("`n") }
  $Manifest.payload_manifest_sha256 = Get-TextSha256 $Digest.ToString()
  WriteText $ManifestFile ((ConvertTo-QbitPrettyJson $Manifest 20) + "`n")
  $State.managedFiles.$ManifestRelative = Get-FileSha256 $ManifestFile
  WriteText $StateFile ((ConvertTo-QbitPrettyJson $State 20) + "`n")
  Assert-PortableOwnershipState $Repo (Read-ValidatedInstallerState $StateFile)
  return $LegacyHash
}
function Get-TransactionCount([string]$Repo) {
  $Root = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/transactions'
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return 0 }
  return @(Get-ChildItem -LiteralPath $Root -Directory -Force).Count
}
function Get-TransactionNames([string]$Repo) {
  $Root = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/transactions'
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
  return @(Get-ChildItem -LiteralPath $Root -Directory -Force | Sort-Object Name | ForEach-Object Name)
}
function Get-RecoveryEvidenceNames([string]$Repo) {
  $Root = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/recovery'
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
  return @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object { $_.FullName.Substring($Root.Length).Replace('\','/') } | Sort-Object)
}
function Assert-SuccessfulRollbackAudit(
  [string]$Repo,
  [object]$Result,
  [string]$BeforeCore,
  [string]$BeforeStateHash,
  [string]$BeforeProfile,
  [string[]]$BeforeTransactionNames,
  [string[]]$BeforeRecoveryNames
) {
  Assert ($Result.ExitCode -eq 6) 'Injected migration failure returned the wrong public exit code.'
  Assert ((@($Result.Output | ForEach-Object { "$_" }) -join "`n").Contains('rollback succeeded.')) 'Installer output did not state that rollback succeeded.'
  Assert ((CoreSnapshot $Repo) -ceq $BeforeCore) 'Rollback did not restore the exact core target snapshot.'
  $StateFile = Join-Path $Repo $StatePath
  Assert ((Get-FileSha256 $StateFile) -ceq $BeforeStateHash) 'Rollback did not restore ownership state byte-identically.'
  $State = Read-ValidatedInstallerState $StateFile
  Assert ($State.profile -ceq $BeforeProfile) 'Rollback changed the prior recorded profile.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Rollback left lock.json.'

  $TransactionsRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/transactions'
  $TransactionDirectories = @(Get-ChildItem -LiteralPath $TransactionsRoot -Directory -Force)
  $NewTransactions = @($TransactionDirectories | Where-Object { $BeforeTransactionNames -cnotcontains $_.Name })
  Assert ($NewTransactions.Count -eq 1) 'Rollback did not retain exactly one new transaction directory.'
  $Transaction = $NewTransactions[0]
  $Journal = ReadText (Join-Path $Transaction.FullName 'journal.json') | ConvertFrom-Json
  Assert ([string]$Journal.status -ceq 'rolled_back') 'Rollback journal status is not rolled_back.'
  foreach ($Directory in $TransactionDirectories) {
    $Candidate = ReadText (Join-Path $Directory.FullName 'journal.json') | ConvertFrom-Json
    Assert ([string]$Candidate.status -cne 'active') 'An active transaction journal remained after successful rollback.'
  }

  $CreatedPaths = @(Get-Content -LiteralPath (Join-Path $Transaction.FullName 'created') | Where-Object { $_ })
  foreach ($RelativePath in $CreatedPaths) {
    Assert (-not (Test-Path -LiteralPath (Join-Path $Repo $RelativePath))) "Rollback left created transaction file: $RelativePath"
  }
  $BackedPaths = @(Get-Content -LiteralPath (Join-Path $Transaction.FullName 'backed') | Where-Object { $_ })
  if ($BackedPaths.Count -gt 0) {
    $BackupDirectory = Join-Path (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups') $Transaction.Name
    Assert (Test-Path -LiteralPath $BackupDirectory -PathType Container) 'Rollback did not retain the corresponding backup directory.'
    foreach ($RelativePath in $BackedPaths) {
      $BackupPath = Join-Path $BackupDirectory $RelativePath
      $TargetPath = Join-Path $Repo $RelativePath
      Assert (Test-Path -LiteralPath $BackupPath -PathType Leaf) "Rollback backup is missing: $RelativePath"
      Assert (Test-Path -LiteralPath $TargetPath -PathType Leaf) "Rollback did not restore backed file: $RelativePath"
      Assert ((Get-FileSha256 $TargetPath) -ceq (Get-FileSha256 $BackupPath)) "Restored file differs from rollback backup: $RelativePath"
    }
  }
  Assert (((Get-RecoveryEvidenceNames $Repo) -join "`n") -ceq ($BeforeRecoveryNames -join "`n")) 'Rollback created uncertain recovery evidence.'
}
function Assert-LegacyReplaceFailure([string]$Repo, [int]$ExpectedExit, [string]$Name) {
  $Before = Snapshot $Repo
  $Backups = Get-InstallBackupCount $Repo
  $Transactions = Get-TransactionCount $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq $ExpectedExit -and $Result.exit_code -eq $ExpectedExit) "$Name returned the wrong exit code."
  Assert ((Snapshot $Repo) -ceq $Before) "$Name mutated the target."
  Assert ((Get-InstallBackupCount $Repo) -eq $Backups) "$Name created a backup."
  Assert ((Get-TransactionCount $Repo) -eq $Transactions) "$Name created a transaction."
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) "$Name left a lock."
}
function Assert-StateCorruptionFailsClosed([string]$Repo, [scriptblock]$Mutate) {
  $StateFile = Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json'
  & $Mutate $StateFile
  $Before = Snapshot $Repo
  $BackupCount = Get-UninstallBackupCount $Repo
  $InstallBackupCount = Get-InstallBackupCount $Repo
  ExpectFailure { & $Verify -Target $Repo } 'PowerShell verify accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -eq $Before) 'PowerShell verify changed the corrupt-state snapshot.'
  ExpectFailure { & $Uninstall -Target $Repo } 'PowerShell normal uninstall accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -eq $Before) 'PowerShell normal uninstall changed the corrupt-state snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'PowerShell normal corrupt-state preflight created a backup.'
  ExpectFailure { & $Uninstall -Target $Repo -OwnedModified replace } 'PowerShell replace-policy uninstall accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -eq $Before) 'PowerShell replace-policy uninstall changed the corrupt-state snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'PowerShell replace-policy corrupt-state preflight created a backup.'
  ExpectFailure { RunInstall $Repo -InstallProfile generic } 'PowerShell normal reinstall accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -eq $Before) 'PowerShell normal reinstall changed the corrupt-state snapshot.'
  Assert ((Get-InstallBackupCount $Repo) -eq $InstallBackupCount) 'PowerShell normal corrupt-state reinstall created a backup.'
  ExpectFailure { RunInstall $Repo -InstallProfile generic -Replace } 'PowerShell replace-policy reinstall accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -eq $Before) 'PowerShell replace-policy reinstall changed the corrupt-state snapshot.'
  Assert ((Get-InstallBackupCount $Repo) -eq $InstallBackupCount) 'PowerShell replace-policy corrupt-state reinstall created a backup.'
  Assert (Test-Path -LiteralPath $StateFile -PathType Leaf) 'PowerShell corrupt-state preflight removed state.'
}
function Assert-ByteCanonicalization([string]$Name, [bool]$Bom, [bool]$Crlf) {
  $Repo = New-Repo "byte-$Name"
  RunInstall $Repo -InstallProfile generic
  $RelativePath = '.env.ai.example'
  $Path = Join-Path $Repo $RelativePath
  $Canonical = ReadText $Path
  $Variant = if ($Crlf) { $Canonical.Replace("`n", "`r`n") } else { $Canonical }
  $Encoding = [Text.UTF8Encoding]::new($Bom)
  [IO.File]::WriteAllText($Path, $Variant, $Encoding)
  $Output = & $Install -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor 6>&1
  Assert ($LASTEXITCODE -eq 0) "Byte canonicalization install failed for $Name."
  Assert (@($Output | ForEach-Object { "$_".Trim() }) -contains "update $RelativePath") "Byte canonicalization did not plan update for $Name."
  $Bytes = [IO.File]::ReadAllBytes($Path)
  Assert (-not ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xef -and $Bytes[1] -eq 0xbb -and $Bytes[2] -eq 0xbf)) "UTF-8 BOM remained for $Name."
  Assert (-not ($Bytes -contains 13)) "CR remained for $Name."
  $State = Get-Content -LiteralPath (Join-Path $Repo $StatePath) -Raw | ConvertFrom-Json
  Assert ($State.managedFiles.$RelativePath -eq (Get-FileSha256 $Path)) "State hash differs from canonical bytes for $Name."
  & $Verify -Target $Repo
  $Second = & $Install -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor 6>&1
  Assert ($LASTEXITCODE -eq 0 -and @($Second | ForEach-Object { "$_".Trim() }) -contains 'no file changes') "Second install was not a no-op for $Name."
}
function Invoke-StateCorruptionScenario([string]$Name, [scriptblock]$Mutate) {
  $Repo = New-Repo "complete-state-$Name"
  RunInstall $Repo -InstallProfile generic
  Assert-StateCorruptionFailsClosed $Repo $Mutate
}
function Rewrite-StateObject([string]$StateFile, [scriptblock]$Mutate) {
  $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  & $Mutate $State
  WriteText $StateFile (($State | ConvertTo-Json -Depth 20) + "`n")
}
function Get-ProjectAgentsFixture {
  return @'
# Repository Guidelines

## Architecture

Project-owned architecture notes stay here.

## Build Commands

- Build: `example build`

## Testing Rules

- Run unit and integration tests before review.
'@
}
function RunInstall([string]$TargetPath, [string]$InstallProfile = 'auto', [switch]$Replace, [switch]$DryRun) {
  $Policy = if ($Replace) { 'replace' } else { 'fail' }
  & $Install -Target $TargetPath -Profile $InstallProfile -SkipBootstrap -SkipDoctor -OwnedModified $Policy -DryRun:$DryRun
  if ($LASTEXITCODE -ne 0) { throw "install.ps1 exited $LASTEXITCODE" }
}
function ExpectFailure([scriptblock]$Block, [string]$Message) {
  $Failed = $false
  try { & $Block } catch { $Failed = $true }
  if (-not $Failed) { throw $Message }
}
function Invoke-ExpectNonzeroExit([scriptblock]$Block, [string]$Message) {
  $Output = @(& $Block *>&1)
  $ExitCode = $LASTEXITCODE
  if ($ExitCode -eq 0) { throw $Message }
  return [pscustomobject]@{ Output = $Output; ExitCode = $ExitCode }
}
function Invoke-WslJson([string[]]$Arguments) {
  $PreviousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $Output = @(& wsl.exe --exec @Arguments 2>$null)
    $ExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
  }
  return [pscustomobject]@{ Result = (($Output -join "`n") | ConvertFrom-Json); ExitCode = $ExitCode }
}
function Scenario([string]$Name, [scriptblock]$Body) {
  if ($env:QBIT_TOOLKIT_TEST_FILTER -and $Name.IndexOf($env:QBIT_TOOLKIT_TEST_FILTER, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return }
  try { & $Body; $Script:Passed++; Write-Host "PASS $Name" }
  catch { $Script:Failed++; Write-Host "FAIL $Name :: $($_.Exception.Message)" -ForegroundColor Red }
}
try {
Scenario 'Fresh TypeScript target installation' {
  $Repo = New-Repo 'fresh-typescript'
  Set-Content -LiteralPath (Join-Path $Repo 'tsconfig.json') -Value '{}' -NoNewline
  RunInstall $Repo -InstallProfile 'typescript'
  & $Verify -Target $Repo
  Assert ((ReadText (Join-Path $Repo '.codex/config.toml')) -match 'enabled = true') 'Serena should be enabled.'
  Assert (Test-Path (Join-Path $Repo '.ai/tooling/language-servers/package.json')) 'TypeScript language server package missing.'
}
Scenario 'Fresh generic target installation' {
  $Repo = New-Repo 'fresh-generic'
  RunInstall $Repo -InstallProfile 'generic'
  & $Verify -Target $Repo
  $State = Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  $SerenaProject = ReadText (Join-Path $Repo '.serena/project.yml')
  Assert ($State.profile -ceq 'generic') 'Generic install did not record generic profile.'
  Assert ((ReadText (Join-Path $Repo '.codex/config.toml')) -match 'enabled = true') 'Generic profile should enable Serena.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*powershell\s*$') 'Shared PowerShell Serena language missing.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*bash\s*$') 'Shared Bash Serena language missing.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*python\s*$') 'Shared Python Serena language missing.'
  Assert (Test-Path (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'Shared language-server package missing.'
}
Scenario 'Fresh Rust target installation' {
  $Repo = New-Repo 'fresh-rust'
  Set-Content -LiteralPath (Join-Path $Repo 'Cargo.toml') -Value "[package]`nname = `"demo`"`nedition = `"2024`"`n" -NoNewline
  RunInstall $Repo -InstallProfile 'rust'
  & $Verify -Target $Repo
  $State = Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  $SerenaProject = ReadText (Join-Path $Repo '.serena/project.yml')
  Assert ($State.profile -ceq 'rust') 'Rust install did not record rust profile.'
  Assert ((ReadText (Join-Path $Repo '.codex/config.toml')) -match 'enabled = true') 'Rust profile should enable Serena.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*powershell\s*$') 'Shared PowerShell Serena language missing.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*bash\s*$') 'Shared Bash Serena language missing.'
  Assert ($SerenaProject -match '(?m)^\s*-\s*python\s*$') 'Shared Python Serena language missing.'
  Assert (Test-Path (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'Shared language-server package missing.'
}
Scenario 'Auto profile detection for TypeScript' {
  $Repo = New-Repo 'auto-typescript'
  Set-Content -LiteralPath (Join-Path $Repo 'package.json') -Value '{"devDependencies":{"typescript":"5.9.3"}}'
  RunInstall $Repo
  $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
  Assert ($State.profile -eq 'typescript') 'Auto profile did not choose TypeScript.'
}
Scenario 'Auto profile detection for Rust' {
  $Repo = New-Repo 'auto-rust'
  Set-Content -LiteralPath (Join-Path $Repo 'Cargo.toml') -Value '[package]' -NoNewline
  RunInstall $Repo
  $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
  Assert ($State.profile -eq 'rust') 'Auto profile did not choose Rust.'
}
Scenario 'TypeScript wins over Rust in auto profile' {
  $Repo = New-Repo 'auto-ts-rust'
  Set-Content -LiteralPath (Join-Path $Repo 'Cargo.toml') -Value '[package]' -NoNewline
  Set-Content -LiteralPath (Join-Path $Repo 'tsconfig.json') -Value '{}' -NoNewline
  RunInstall $Repo
  $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
  Assert ($State.profile -eq 'typescript') 'TypeScript did not take precedence over Rust.'
}
Scenario 'Auto profile fallback to generic' {
  $Repo = New-Repo 'auto-generic'
  RunInstall $Repo
  $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
  Assert ($State.profile -eq 'generic') 'Auto profile did not choose generic.'
}
Scenario 'DryRun produces no file changes' {
  $Repo = New-Repo 'dryrun'
  $Before = Snapshot $Repo
  RunInstall $Repo -InstallProfile 'generic' -DryRun
  $After = Snapshot $Repo
  Assert ($Before -eq $After) 'DryRun changed target files.'
}
Scenario 'Repeated installation is idempotent' {
  $Repo = New-Repo 'idempotent'
  RunInstall $Repo -InstallProfile 'typescript'
  $Before = Snapshot $Repo
  Start-Sleep -Seconds 1
  RunInstall $Repo -InstallProfile 'typescript'
  $After = Snapshot $Repo
  Assert ($Before -eq $After) 'Repeated install changed files.'
}
Scenario 'Existing gitignore content is preserved' {
  $Repo = New-Repo 'gitignore-preserve'
  Set-Content -LiteralPath (Join-Path $Repo '.gitignore') -Value "custom.log`n"
  RunInstall $Repo -InstallProfile 'generic'
  Assert ((ReadText (Join-Path $Repo '.gitignore')) -match 'custom\.log') 'Existing .gitignore content lost.'
}
Scenario 'Existing gitattributes content is preserved' {
  $Repo = New-Repo 'gitattributes-preserve'
  Set-Content -LiteralPath (Join-Path $Repo '.gitattributes') -Value "*.txt text eol=lf`n"
  RunInstall $Repo -InstallProfile 'generic'
  Assert ((ReadText (Join-Path $Repo '.gitattributes')) -match '\*\.txt text eol=lf') 'Existing .gitattributes content lost.'
}
Scenario 'Managed blocks are not duplicated' {
  $Repo = New-Repo 'block-idempotent'
  RunInstall $Repo -InstallProfile 'generic'
  RunInstall $Repo -InstallProfile 'generic'
  Assert (((ReadText (Join-Path $Repo '.gitignore')) | Select-String 'qbit-toolkit:codex-ai-tooling' -AllMatches).Matches.Count -eq 2) 'Gitignore markers duplicated.'
  Assert (((ReadText (Join-Path $Repo '.gitattributes')) | Select-String 'qbit-toolkit:codex-ai-tooling' -AllMatches).Matches.Count -eq 2) 'Gitattributes markers duplicated.'
  Assert (((ReadText (Join-Path $Repo 'AGENTS.md')) | Select-String 'qbit-toolkit:codex-ai-tooling' -AllMatches).Matches.Count -eq 2) 'AGENTS markers duplicated.'
}
Scenario 'Generated whole-file effective content hashes and reinstalls idempotently' {
  $Repo = New-Repo 'effective-whole-file'
  RunInstall $Repo -InstallProfile 'generic'
  $RelativePath = '.env.ai.example'
  $Path = Join-Path $Repo $RelativePath
  $Installed = ReadText $Path
  Assert ($Installed.EndsWith("`n")) 'Fixture managed file did not have canonical terminal LF.'
  $Raw = $Installed.Substring(0, $Installed.Length - 1)
  $FixturePlan = @{ $RelativePath = [ordered]@{ RelativePath = $RelativePath; Content = $Raw; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf } }
  Invoke-TransactionalWrite $Repo $FixturePlan
  $StateFile = Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json'
  $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  $ActualHash = Get-FileSha256 $Path
  Assert ($State.managedFiles.$RelativePath -eq $ActualHash) 'Installed state hash did not match effective written file bytes.'
  Assert ($ActualHash -ne (Get-TextSha256 $Raw)) 'Installed state hash matched untransformed raw fixture content.'
  & $Verify -Target $Repo
  $BeforeSecondInstall = Snapshot $Repo
  $SecondOutput = & $Install -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor 6>&1
  Assert ($LASTEXITCODE -eq 0) 'Second effective-content install failed.'
  Assert (@($SecondOutput | ForEach-Object { "$_".Trim() }) -contains 'no file changes') 'Second effective-content install planned an update.'
  Assert ((Snapshot $Repo) -eq $BeforeSecondInstall) 'Second effective-content install changed the target.'
  & $Uninstall -Target $Repo
  Assert (-not (Test-Path -LiteralPath $StateFile)) 'Effective-content uninstall left state behind.'
}
Scenario 'PowerShell whole managed CRLF without BOM is rewritten byte-exactly' { Assert-ByteCanonicalization 'crlf-no-bom' $false $true }
Scenario 'PowerShell whole managed LF with UTF-8 BOM is rewritten byte-exactly' { Assert-ByteCanonicalization 'lf-bom' $true $false }
Scenario 'PowerShell whole managed CRLF with UTF-8 BOM is rewritten byte-exactly' { Assert-ByteCanonicalization 'crlf-bom' $true $true }
Scenario 'PowerShell JSON display name escaping preserves decoded values' {
  $Repo=New-Repo 'json-display-name'; $Display='Qbit "CLI" \ Tooling'
  & $Install -Target $Repo -Profile typescript -ProjectDisplayName $Display -SkipBootstrap -SkipDoctor
  Assert ($LASTEXITCODE -eq 0) 'Escaped display-name install failed.'
  $State=Get-Content -LiteralPath (Join-Path $Repo $StatePath) -Raw | ConvertFrom-Json
  Assert ($State.projectDisplayName -ceq $Display) 'Decoded state display name changed.'
  Get-ChildItem -LiteralPath (Join-Path $Repo '.ai/tooling') -Recurse -File | Where-Object { $_.Name -ceq 'package.json' -or $_.Name -ceq 'package-lock.json' } | ForEach-Object {
    $Reader = [Runtime.Serialization.Json.JsonReaderWriterFactory]::CreateJsonReader([IO.File]::ReadAllBytes($_.FullName),[Xml.XmlDictionaryReaderQuotas]::Max)
    try { while ($Reader.Read()) {} } finally { $Reader.Close() }
  }
  & $Verify -Target $Repo
  & $Uninstall -Target $Repo
}
Scenario 'PowerShell project display name control characters fail before mutation' {
  $Repo=New-Repo 'display-control'; $Before=Snapshot $Repo
  $Result=Invoke-ExpectNonzeroExit { & $Install -Target $Repo -Profile generic -ProjectDisplayName "bad`tname" -SkipBootstrap -SkipDoctor } 'Control-character display name was accepted.'
  Assert ((@($Result.Output | ForEach-Object { "$_" }) -join "`n").Contains('ProjectDisplayName must not contain control characters.')) 'Control-character rejection message was missing.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Rejected display name changed target.'
  Assert ((Get-InstallBackupCount $Repo) -eq 0) 'Rejected display name created a backup.'
  Assert ((Get-TransactionCount $Repo) -eq 0) 'Rejected display name created a transaction.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo $StatePath))) 'Rejected display name created state.'
}
Scenario 'PowerShell all display-name controls fail before fresh install or reinstall mutation' {
  $Cases = @("bad`tname","bad`nname","bad`n","bad`rname",("bad"+[char]8+'name'),("bad"+[char]12+'name'),("bad"+[char]127+'name'))
  foreach ($Case in $Cases) {
    $Fresh=New-Repo ('display-control-'+[guid]::NewGuid().ToString('n')); $FreshBefore=Snapshot $Fresh
    $Result=Invoke-ExpectNonzeroExit { & $Install -Target $Fresh -Profile generic -ProjectDisplayName $Case -SkipBootstrap -SkipDoctor } 'Control display name passed fresh install.'
    Assert ((@($Result.Output | ForEach-Object { "$_" }) -join "`n").Contains('ProjectDisplayName must not contain control characters.')) 'Fresh control-character rejection message was missing.'
    Assert ((Snapshot $Fresh) -ceq $FreshBefore -and (Get-InstallBackupCount $Fresh) -eq 0) 'Rejected fresh display name mutated target.'
    Assert ((Get-TransactionCount $Fresh) -eq 0) 'Rejected fresh display name created a transaction.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $Fresh $StatePath))) 'Rejected fresh display name created state.'
  }
  $Repo=New-Repo 'display-control-reinstall'; RunInstall $Repo -InstallProfile generic
  foreach ($Case in $Cases) {
    $Before=Snapshot $Repo; $Backups=Get-InstallBackupCount $Repo; $Transactions=Get-TransactionCount $Repo
    $Result=Invoke-ExpectNonzeroExit { & $Install -Target $Repo -Profile generic -ProjectDisplayName $Case -SkipBootstrap -SkipDoctor } 'Control display name passed reinstall.'
    Assert ((@($Result.Output | ForEach-Object { "$_" }) -join "`n").Contains('ProjectDisplayName must not contain control characters.')) 'Reinstall control-character rejection message was missing.'
    Assert ((Snapshot $Repo) -ceq $Before -and (Get-InstallBackupCount $Repo) -eq $Backups) 'Rejected display-name reinstall mutated target.'
    Assert ((Get-TransactionCount $Repo) -eq $Transactions) 'Rejected display-name reinstall created a transaction.'
  }
}
Scenario 'PowerShell duplicate normalized origins are written once' {
  $Repo=New-Repo 'origin-deduplicate'
  & $Install -Target $Repo -Profile generic -AllowedOrigin @('http://localhost:3000/','http://localhost:3000','http://localhost:3000','http://127.0.0.1:3000') -SkipBootstrap -SkipDoctor
  Assert ($LASTEXITCODE -eq 0) 'Duplicate-origin install failed.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  Assert ((@($State.allowedOrigins) -join '|') -ceq 'http://localhost:3000|http://127.0.0.1:3000') 'Origins were not normalized, deduplicated, and first-order-preserved.'
}
Scenario 'PowerShell IPv6 origins are literally deduplicated in first-occurrence order' {
  $Repo=New-Repo 'origin-ipv6-deduplicate'
  & $Install -Target $Repo -Profile generic -AllowedOrigin @('http://[::1]:3000','http://localhost:3000','http://[::1]:3000') -SkipBootstrap -SkipDoctor
  Assert ($LASTEXITCODE -eq 0) 'IPv6 duplicate-origin install failed.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  Assert ((@($State.allowedOrigins) -join '|') -ceq 'http://[::1]:3000|http://localhost:3000') 'IPv6 origins were not literally deduplicated in first-occurrence order.'
  Assert (@($State.allowedOrigins | Where-Object { $_ -ceq 'http://[::1]:3000' }).Count -eq 1) 'IPv6 origin was not written exactly once.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell installedAtUtc is preserved for every valid reinstall and reset after uninstall' {
  $Repo=New-Repo 'installed-at-policy'; & $Install -Target $Repo -Profile typescript -ProjectDisplayName First -SkipBootstrap -SkipDoctor
  $First=(Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc
  & $Install -Target $Repo -Profile typescript -ProjectDisplayName First -SkipBootstrap -SkipDoctor
  Assert ((Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc -ceq $First) 'Idempotent reinstall replaced installedAtUtc.'
  & $Install -Target $Repo -Profile typescript -AllowedOrigin @('http://localhost:3000') -SkipBootstrap -SkipDoctor
  Assert ((Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc -ceq $First) 'Origin change replaced installedAtUtc.'
  & $Install -Target $Repo -Profile typescript -ProjectDisplayName Second -AllowedOrigin @('http://localhost:3000') -SkipBootstrap -SkipDoctor
  Assert ((Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc -ceq $First) 'Display-name change replaced installedAtUtc.'
  & $Install -Target $Repo -Profile rust -ProjectDisplayName Second -AllowedOrigin @('http://localhost:3000') -SkipBootstrap -SkipDoctor
  Assert ((Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc -ceq $First) 'Profile migration replaced installedAtUtc.'
  & $Uninstall -Target $Repo; Start-Sleep -Seconds 1
  & $Install -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor
  Assert ((Read-ValidatedInstallerState (Join-Path $Repo $StatePath)).installedAtUtc -cne $First) 'Fresh install after uninstall reused installedAtUtc.'
}
Scenario 'PowerShell installedRelativePaths is unique deterministic expected union' {
  $Repo=New-Repo 'installed-manifest'; RunInstall $Repo -InstallProfile typescript
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  $Expected=@(Get-ExpectedInstalledPaths $InstallerRoot 'typescript')
  Assert (@($State.installedRelativePaths).Count -eq @($State.installedRelativePaths | Select-Object -Unique).Count) 'installedRelativePaths contains duplicates.'
  Assert ((@($State.installedRelativePaths) -join "`n") -ceq ($Expected -join "`n")) 'installedRelativePaths differs from deterministic expected union.'
  Assert (@($State.installedRelativePaths | Where-Object { $_ -eq $StatePath }).Count -eq 1) 'State path does not appear exactly once.'
}
Scenario 'PowerShell profile migration typescript to rust preserves shared files' {
  $Repo=New-Repo 'migration-ts-rust'; RunInstall $Repo -InstallProfile typescript; RunInstall $Repo -InstallProfile rust
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'Shared package was not preserved.'
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package-lock.json') -PathType Leaf) 'Shared package lock was not preserved.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath); Assert ($State.profile -eq 'rust') 'Migration profile is not rust.'
  & $Verify -Target $Repo; & $Uninstall -Target $Repo
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json'))) 'Uninstall left the shared package behind.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package-lock.json'))) 'Uninstall left the shared package lock behind.'
}
Scenario 'PowerShell profile migration typescript to generic preserves shared files' {
  $Repo=New-Repo 'migration-ts-generic'; RunInstall $Repo -InstallProfile typescript; RunInstall $Repo -InstallProfile generic
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers') -PathType Container) 'Shared language-server directory was not preserved.'
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'Shared package was not preserved.'
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package-lock.json') -PathType Leaf) 'Shared package lock was not preserved.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath); Assert ($State.profile -ceq 'generic') 'Migration profile is not generic.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell profile migration rust to typescript creates and owns files' {
  $Repo=New-Repo 'migration-rust-ts'; RunInstall $Repo -InstallProfile rust; RunInstall $Repo -InstallProfile typescript
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'TypeScript package was not created.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath); Assert ($State.managedFiles.PSObject.Properties.Name -contains '.ai/tooling/language-servers/package.json') 'TypeScript package is not owned.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell modified stale file blocks migration before mutation' {
  $Repo=New-Repo 'migration-modified-block'; RunInstall $Repo -InstallProfile typescript
  Add-Content -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json') -Value 'modified'
  $Before=Snapshot $Repo; $Backups=Get-InstallBackupCount $Repo
  ExpectFailure { RunInstall $Repo -InstallProfile rust } 'Modified stale file migrated without replace policy.'
  Assert ((Snapshot $Repo) -ceq $Before -and (Get-InstallBackupCount $Repo) -eq $Backups) 'Blocked migration mutated target or created backup.'
}
Scenario 'PowerShell replace-policy migration backs up and restores modified shared file' {
  $Repo=New-Repo 'migration-modified-force'; RunInstall $Repo -InstallProfile typescript
  $Shared='.ai/tooling/language-servers/package.json'; $SharedPath=Join-Path $Repo $Shared
  $CanonicalHash=Get-FileSha256 $SharedPath; Add-Content -LiteralPath $SharedPath -Value 'modified'; $ModifiedHash=Get-FileSha256 $SharedPath
  RunInstall $Repo -InstallProfile rust -Replace
  Assert (Test-Path -LiteralPath $SharedPath -PathType Leaf) 'Replace-policy migration removed the shared file.'
  Assert ((Get-FileSha256 $SharedPath) -ceq $CanonicalHash) 'Replace-policy migration did not restore canonical shared content.'
  $BackedUp=@(Get-ChildItem -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups') -Recurse -File | Where-Object { $_.FullName.Replace('\','/').EndsWith($Shared) -and (Get-FileSha256 $_.FullName) -ceq $ModifiedHash })
  Assert ($BackedUp.Count -gt 0) 'Replace-policy migration did not back up the modified shared file.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell missing shared file is recreated during profile migration' {
  $Repo=New-Repo 'migration-missing-stale'; RunInstall $Repo -InstallProfile typescript
  $SharedPath=Join-Path $Repo '.ai/tooling/language-servers/package.json'; $CanonicalHash=Get-FileSha256 $SharedPath
  Remove-Item -LiteralPath $SharedPath -Force
  RunInstall $Repo -InstallProfile rust
  Assert (Test-Path -LiteralPath $SharedPath -PathType Leaf) 'Missing shared file was not recreated during migration.'
  Assert ((Get-FileSha256 $SharedPath) -ceq $CanonicalHash) 'Recreated shared file differs from canonical installer content.'
  $State=Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  Assert ($State.profile -ceq 'rust') 'Profile migration did not complete.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell migration preserves shared files and DryRun is write-free' {
  $Repo=New-Repo 'migration-dryrun'; RunInstall $Repo -InstallProfile typescript; $Before=Snapshot $Repo; $Backups=Get-InstallBackupCount $Repo; $Transactions=Get-TransactionCount $Repo
  $Output=& $Install -Target $Repo -Profile rust -DryRun -SkipBootstrap -SkipDoctor 6>&1
  $ExitCode=$LASTEXITCODE
  Assert ($ExitCode -eq 0) 'Migration DryRun failed.'
  Assert (-not (@($Output | ForEach-Object { "$_".Trim() }) -contains 'remove .ai/tooling/language-servers/package.json')) 'DryRun reported removal of the shared package.'
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package.json') -PathType Leaf) 'DryRun removed the shared package.'
  Assert (Test-Path -LiteralPath (Join-Path $Repo '.ai/tooling/language-servers/package-lock.json') -PathType Leaf) 'DryRun removed the shared package lock.'
  Assert ((Snapshot $Repo) -ceq $Before -and (Get-InstallBackupCount $Repo) -eq $Backups) 'Migration DryRun changed target.'
  Assert ((Get-TransactionCount $Repo) -eq $Transactions) 'Migration DryRun left a transaction.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Migration DryRun left a lock.'
}
Scenario 'PowerShell migration injected failure restores core target and retains rollback audit' {
  $Repo=New-Repo 'migration-rollback'; RunInstall $Repo -InstallProfile typescript
  $StateFile=Join-Path $Repo $StatePath; $BeforeStateHash=Get-FileSha256 $StateFile
  $BeforeCore=CoreSnapshot $Repo; $BeforeTransactions=@(Get-TransactionNames $Repo); $BeforeRecovery=@(Get-RecoveryEvidenceNames $Repo)
  $Old=$env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES='1'
  try { $Result=Invoke-ExpectNonzeroExit { & $Install -Target $Repo -Profile rust -SkipBootstrap -SkipDoctor } 'Injected migration failure succeeded.' } finally { $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES=$Old }
  Assert-SuccessfulRollbackAudit $Repo $Result $BeforeCore $BeforeStateHash 'typescript' $BeforeTransactions $BeforeRecovery
  & $Verify -Target $Repo
}
Scenario 'PowerShell migration recreation failure rolls back recreated shared file' {
  $Repo=New-Repo 'migration-create-rollback'; RunInstall $Repo -InstallProfile rust
  $SharedPath=Join-Path $Repo '.ai/tooling/language-servers/package.json'; Remove-Item -LiteralPath $SharedPath -Force
  $StateFile=Join-Path $Repo $StatePath; $BeforeStateHash=Get-FileSha256 $StateFile
  $BeforeCore=CoreSnapshot $Repo; $BeforeTransactions=@(Get-TransactionNames $Repo); $BeforeRecovery=@(Get-RecoveryEvidenceNames $Repo)
  $Old=$env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES; $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES='1'
  try { $Result=Invoke-ExpectNonzeroExit { & $Install -Target $Repo -Profile typescript -SkipBootstrap -SkipDoctor } 'Injected recreation migration failure succeeded.' } finally { $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES=$Old }
  Assert-SuccessfulRollbackAudit $Repo $Result $BeforeCore $BeforeStateHash 'rust' $BeforeTransactions $BeforeRecovery
  Assert (-not (Test-Path -LiteralPath $SharedPath)) 'Rollback left the recreated shared package behind.'
}
Scenario 'Conflicting unmanaged file fails with default policy' {
  $Repo = New-Repo 'conflict'
  New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.codex') | Out-Null
  Set-Content -LiteralPath (Join-Path $Repo '.codex/config.toml') -Value 'user content'
  ExpectFailure { RunInstall $Repo -InstallProfile 'generic' } 'Conflict did not fail.'
}
Scenario 'Replace policy never overwrites an unmanaged conflict' {
  $Repo = New-Repo 'replace-unowned'
  New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.codex') | Out-Null
  Set-Content -LiteralPath (Join-Path $Repo '.codex/config.toml') -Value 'user content'
  $Before = Snapshot $Repo
  ExpectFailure { RunInstall $Repo -InstallProfile 'generic' -Replace } 'Replace policy overwrote an unowned conflict.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Replace policy mutated an unowned conflict.'
}
Scenario 'Failed installation restores backup' {
  $Repo = New-Repo 'rollback'
  Set-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'original' -NoNewline
  $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES = '1'
  ExpectFailure { RunInstall $Repo -InstallProfile 'generic' -Replace } 'Injected failure did not fail.'
  Remove-Item Env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES -ErrorAction SilentlyContinue
  Assert ((Get-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Raw) -eq 'original') 'Rollback did not restore original file.'
  Assert (-not (Test-Path (Join-Path $Repo '.codex/config.toml'))) 'Rollback left newly created file.'
}
Scenario 'Existing AGENTS installs without replacement and preserves content' {
  $Repo = New-Repo 'agents-preserve'
  $Original = Get-ProjectAgentsFixture
  Set-Content -LiteralPath (Join-Path $Repo 'AGENTS.md') -Value $Original -NoNewline
  RunInstall $Repo -InstallProfile 'rust'
  $After = ReadText (Join-Path $Repo 'AGENTS.md')
  Assert ($After.Contains($Original.Replace("`r`n","`n"))) 'Existing AGENTS content was not preserved.'
  Assert (((ReadText (Join-Path $Repo 'AGENTS.md')) | Select-String '<!-- qbit-toolkit:codex-ai-tooling:start -->' -AllMatches).Matches.Count -eq 1) 'AGENTS managed block missing or duplicated.'
}
Scenario 'PowerShell default policy rejects modified owned AGENTS block without mutation' {
  $Repo = New-Repo 'agents-default-conflict'
  $Original = Get-ProjectAgentsFixture
  Set-Content -LiteralPath (Join-Path $Repo 'AGENTS.md') -Value $Original -NoNewline
  RunInstall $Repo -InstallProfile 'generic'
  $Managed = ReadText (Join-Path $Repo 'AGENTS.md')
  $Edited = $Managed -replace 'Qbit AI tooling', 'Modified owned block'
  Set-Content -LiteralPath (Join-Path $Repo 'AGENTS.md') -Value $Edited -NoNewline
  $Before = Snapshot $Repo
  $BackupCount = Get-InstallBackupCount $Repo
  $TransactionRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/transactions'
  $TransactionCount = if (Test-Path $TransactionRoot) { @(Get-ChildItem $TransactionRoot -Directory).Count } else { 0 }
  $Result = (& $Install -Operation update -Target $Repo -Profile generic -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 4 -and $Result.exit_code -eq 4) 'Default policy did not return exit 4.'
  Assert (($Result.conflicts -join "`n") -match 'AGENTS\.md') 'Conflict did not identify AGENTS.md.'
  $null = & $Install -Operation update -Target $Repo -Profile generic -Format text -NonInteractive 2>$null
  Assert ($LASTEXITCODE -eq 4) 'Default policy text mode did not return exit 4.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Default-policy conflict changed the target.'
  Assert ((Get-InstallBackupCount $Repo) -eq $BackupCount) 'Default-policy conflict created a backup.'
  $TransactionCountAfter = if (Test-Path $TransactionRoot) { @(Get-ChildItem $TransactionRoot -Directory).Count } else { 0 }
  Assert ($TransactionCountAfter -eq $TransactionCount) 'Default-policy conflict created a transaction.'
  Assert (-not (Test-Path (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Default-policy conflict left a lock.'
}
Scenario 'PowerShell replace policy backs up and replaces only modified owned AGENTS block' {
  $Repo = New-Repo 'agents-replace'
  $Original = "prefix trailing  `n"
  WriteText (Join-Path $Repo 'AGENTS.md') $Original
  RunInstall $Repo -InstallProfile generic
  $Suffix = 'suffix trailing  '
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) + $Suffix)
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling', 'Modified owned block')
  $PriorHash = (Get-FileHash -LiteralPath (Join-Path $Repo 'AGENTS.md') -Algorithm SHA256).Hash
  $BackupRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups'
  $BackupCount = @(Get-ChildItem $BackupRoot -Recurse -File -Filter AGENTS.md).Count
  & $Install -Operation update -Target $Repo -Profile generic -OwnedModified replace -NonInteractive
  Assert ($LASTEXITCODE -eq 0) 'Replace-policy update failed.'
  $Backups = @(Get-ChildItem $BackupRoot -Recurse -File -Filter AGENTS.md)
  Assert ($Backups.Count -eq ($BackupCount + 1)) 'Replace-policy update did not add exactly one AGENTS backup.'
  Assert (@($Backups | Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -ceq $PriorHash }).Count -ge 1) 'Complete pre-replacement AGENTS file was not backed up.'
  $After = ReadText (Join-Path $Repo 'AGENTS.md')
  Assert ($After.StartsWith($Original, [StringComparison]::Ordinal)) 'Project-owned prefix changed.'
  Assert ($After.EndsWith($Suffix, [StringComparison]::Ordinal)) 'Project-owned suffix changed.'
  Assert ($After -match 'Qbit AI tooling' -and $After -notmatch 'Modified owned block') 'Canonical managed block was not restored.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell plan plus replace reports exact owned file and block actions without mutation' {
  $Repo = New-Repo 'plan-replace-owned'
  WriteText (Join-Path $Repo 'AGENTS.md') "prefix`n"
  RunInstall $Repo -InstallProfile generic
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling', 'Modified owned block')
  Add-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'modified owned file'
  $Before = Snapshot $Repo
  $BackupCount = Get-InstallBackupCount $Repo
  $TransactionRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/transactions'
  $TransactionCount = @(Get-ChildItem $TransactionRoot -Directory).Count
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 0 -and $Result.exit_code -eq 0 -and $Result.success) 'Plan plus replace failed.'
  $Expected = @('update .env.ai.example','update .qbit-toolkit/codex-ai-tooling/manifest.json','update .qbit/toolkit/installed/codex-ai-tooling.json','update AGENTS.md')
  Assert (($Result.planned_actions -join "`n") -ceq ($Expected -join "`n")) 'Plan plus replace actions differ from the exact expected set.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Plan plus replace changed the target.'
  Assert ((Get-InstallBackupCount $Repo) -eq $BackupCount) 'Plan plus replace created a backup.'
  Assert (@(Get-ChildItem $TransactionRoot -Directory).Count -eq $TransactionCount) 'Plan plus replace created a transaction.'
  Assert (-not (Test-Path (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Plan plus replace left a lock.'
}
Scenario 'PowerShell and Bash plan plus replace wrappers have semantic parity' {
  $Repo = New-Repo 'plan-replace-parity'
  WriteText (Join-Path $Repo 'AGENTS.md') "prefix`n"
  RunInstall $Repo -InstallProfile generic
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling', 'Modified owned block')
  Add-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'modified owned file'
  $Before = Snapshot $Repo
  $PowerShellResult = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  $PowerShellExit = $LASTEXITCODE
  $WslInstaller = ((& wsl.exe --exec wslpath -u $BashInstall) -join '').Trim()
  $WslTarget = ((& wsl.exe --exec wslpath -u $Repo) -join '').Trim()
  $BashInvocation = Invoke-WslJson @('bash',$WslInstaller,'--operation','plan','--target',$WslTarget,'--profile','generic','--owned-modified','replace','--format','json','--non-interactive')
  $BashResult = $BashInvocation.Result
  $BashExit = $BashInvocation.ExitCode
  Assert ($PowerShellExit -eq $BashExit) 'Host plan exit codes differ.'
  Assert ($PowerShellResult.success -eq $BashResult.success) 'Host plan success values differ.'
  Assert ($PowerShellResult.detected_state -ceq $BashResult.detected_state) 'Host detected_state values differ.'
  Assert (($PowerShellResult.planned_actions -join "`n") -ceq ($BashResult.planned_actions -join "`n")) 'Host planned_actions differ.'
  Assert (($PowerShellResult.conflicts -join "`n") -ceq ($BashResult.conflicts -join "`n")) 'Host conflicts differ.'
  Assert ((ConvertTo-Json -InputObject @($PowerShellResult.errors) -Depth 10 -Compress) -ceq (ConvertTo-Json -InputObject @($BashResult.errors) -Depth 10 -Compress)) 'Host errors differ semantically.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Host parity planning changed the target.'
}
Scenario 'PowerShell replace rejects unowned and malformed managed markers without mutation' {
  $Repo = New-Repo 'replace-unowned-marker'
  WriteText (Join-Path $Repo 'AGENTS.md') "$AgentsBeginMarker`nunowned`n$AgentsEndMarker`n"
  $Before = Snapshot $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 4 -and $Result.exit_code -eq 4) 'Replace policy accepted unowned managed markers.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Unowned marker rejection changed the target.'
  $Repo = New-Repo 'replace-malformed-marker'
  RunInstall $Repo -InstallProfile generic
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')).Replace($AgentsEndMarker,$AgentsBeginMarker))
  $Before = Snapshot $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 4 -and $Result.exit_code -eq 4) 'Replace policy accepted malformed managed markers.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Malformed marker rejection changed the target.'
  $Repo = New-Repo 'replace-missing-state'
  RunInstall $Repo -InstallProfile generic
  Remove-Item -LiteralPath (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json')
  $Before = Snapshot $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 4 -and $Result.exit_code -eq 4) 'Replace policy accepted missing ownership state.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Missing-state rejection changed the target.'
  $Repo = New-Repo 'replace-corrupt-state'
  RunInstall $Repo -InstallProfile generic
  Add-Content -LiteralPath (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Value 'not-json'
  $Before = Snapshot $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 5 -and $Result.exit_code -eq 5) 'Replace policy accepted corrupt ownership state.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Corrupt-state rejection changed the target.'
}
Scenario 'PowerShell unchanged owned legacy AGENTS migrates under fail and replace policies' {
  foreach ($Policy in @('fail','replace')) {
    $Repo = New-Repo "legacy-unchanged-$Policy"
    $Prefix = "prefix trailing  `n"
    $Suffix = 'suffix trailing  '
    WriteText (Join-Path $Repo 'AGENTS.md') $Prefix
    RunInstall $Repo -InstallProfile generic
    WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) + $Suffix)
    $null = ConvertTo-ValidLegacyAgentsFixture $Repo
    $PriorHash = Get-FileSha256 (Join-Path $Repo 'AGENTS.md')
    $BackupRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups'
    $BackupCount = @(Get-ChildItem -LiteralPath $BackupRoot -Recurse -File -Filter AGENTS.md).Count
    $IndexBefore = (& git -C $Repo ls-files --stage) -join "`n"
    & $Install -Operation update -Target $Repo -Profile generic -OwnedModified $Policy -NonInteractive
    Assert ($LASTEXITCODE -eq 0) "Unchanged legacy migration failed under $Policy."
    $After = ReadText (Join-Path $Repo 'AGENTS.md')
    Assert (([regex]::Matches($After,[regex]::Escape($AgentsBeginMarker))).Count -eq 1 -and ([regex]::Matches($After,[regex]::Escape($AgentsEndMarker))).Count -eq 1) 'Current AGENTS markers are not unique after legacy migration.'
    Assert ($After -notmatch [regex]::Escape('<!-- >>> qbit-toolkit:codex-ai-tooling -->') -and $After -notmatch [regex]::Escape('<!-- <<< qbit-toolkit:codex-ai-tooling -->')) 'Legacy markers remained after migration.'
    Assert ($After.StartsWith($Prefix,[StringComparison]::Ordinal) -and $After.EndsWith($Suffix,[StringComparison]::Ordinal)) 'Project-owned prefix or suffix changed during legacy migration.'
    $Backups = @(Get-ChildItem -LiteralPath $BackupRoot -Recurse -File -Filter AGENTS.md)
    Assert ($Backups.Count -eq ($BackupCount + 1)) 'Legacy migration did not add exactly one AGENTS backup.'
    Assert (@($Backups | Where-Object { (Get-FileSha256 $_.FullName) -ceq $PriorHash }).Count -ge 1) 'Legacy migration backup is not byte-identical to the prior AGENTS file.'
    $State = Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
    $CurrentHash = Get-TextSha256 (Get-CompleteManagedBlock $After $AgentsBeginMarker $AgentsEndMarker)
    Assert ($State.managedBlocks.'AGENTS.md'.sha256 -ceq $CurrentHash) 'Compatibility ownership hash was not updated after legacy migration.'
    Assert-PortableOwnershipState $Repo $State
    Assert (((& git -C $Repo ls-files --stage) -join "`n") -ceq $IndexBefore) 'Legacy migration changed the Git index.'
    & $Verify -Target $Repo
    Assert ($LASTEXITCODE -eq 0) 'Verify failed after unchanged legacy migration.'
  }
}
Scenario 'PowerShell modified owned legacy AGENTS default policy fails without mutation' {
  $Repo = New-Repo 'legacy-modified-default'
  WriteText (Join-Path $Repo 'AGENTS.md') "prefix`n"
  RunInstall $Repo -InstallProfile generic
  $null = ConvertTo-ValidLegacyAgentsFixture $Repo
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling','Modified legacy body')
  $Before = Snapshot $Repo; $Backups = Get-InstallBackupCount $Repo; $Transactions = Get-TransactionCount $Repo
  $Result = (& $Install -Operation update -Target $Repo -Profile generic -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 4 -and $Result.exit_code -eq 4) 'Modified legacy default policy did not return exit 4.'
  Assert (($Result.conflicts -join "`n") -match 'AGENTS\.md') 'Modified legacy conflict did not identify AGENTS.md.'
  $null = & $Install -Operation update -Target $Repo -Profile generic -Format text -NonInteractive 2>$null
  Assert ($LASTEXITCODE -eq 4) 'Modified legacy default policy text mode did not return exit 4.'
  Assert ((Snapshot $Repo) -ceq $Before -and (Get-InstallBackupCount $Repo) -eq $Backups -and (Get-TransactionCount $Repo) -eq $Transactions) 'Modified legacy conflict mutated the target, backup set, or transactions.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Modified legacy conflict left a lock.'
}
Scenario 'PowerShell modified owned legacy AGENTS replace migrates transactionally' {
  $Repo = New-Repo 'legacy-modified-replace'
  $Prefix = "prefix trailing  `n"; $Suffix = 'suffix trailing  '
  WriteText (Join-Path $Repo 'AGENTS.md') $Prefix
  RunInstall $Repo -InstallProfile generic
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) + $Suffix)
  $null = ConvertTo-ValidLegacyAgentsFixture $Repo
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling','Modified legacy body')
  $PriorHash = Get-FileSha256 (Join-Path $Repo 'AGENTS.md')
  $IndexBefore = (& git -C $Repo ls-files --stage) -join "`n"
  $BackupRoot = Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups'; $BackupCount = @(Get-ChildItem $BackupRoot -Recurse -File -Filter AGENTS.md).Count
  & $Install -Operation update -Target $Repo -Profile generic -OwnedModified replace -NonInteractive
  Assert ($LASTEXITCODE -eq 0) 'Modified legacy replace migration failed.'
  $Backups = @(Get-ChildItem $BackupRoot -Recurse -File -Filter AGENTS.md)
  Assert ($Backups.Count -eq ($BackupCount + 1)) 'Modified legacy replace did not add exactly one AGENTS backup.'
  Assert (@($Backups | Where-Object { (Get-FileSha256 $_.FullName) -ceq $PriorHash }).Count -ge 1) 'Modified legacy complete file backup was not preserved.'
  $After = ReadText (Join-Path $Repo 'AGENTS.md')
  Assert ($After.StartsWith($Prefix,[StringComparison]::Ordinal) -and $After.EndsWith($Suffix,[StringComparison]::Ordinal)) 'Modified legacy migration changed project-owned bytes.'
  Assert ($After -match [regex]::Escape($AgentsBeginMarker) -and $After -notmatch 'Modified legacy body' -and $After -notmatch '<!-- >>> qbit-toolkit:codex-ai-tooling -->') 'Modified legacy migration did not install the canonical current block.'
  $State = Read-ValidatedInstallerState (Join-Path $Repo $StatePath)
  Assert ($State.managedBlocks.'AGENTS.md'.sha256 -ceq (Get-TextSha256 (Get-CompleteManagedBlock $After $AgentsBeginMarker $AgentsEndMarker))) 'Modified legacy migration recorded the wrong block hash.'
  Assert-PortableOwnershipState $Repo $State
  Assert (((& git -C $Repo ls-files --stage) -join "`n") -ceq $IndexBefore) 'Modified legacy migration changed the Git index.'
  & $Verify -Target $Repo
}
Scenario 'PowerShell modified owned legacy AGENTS plan plus replace is write-free' {
  $Repo = New-Repo 'legacy-plan-replace'
  WriteText (Join-Path $Repo 'AGENTS.md') "prefix`n"
  RunInstall $Repo -InstallProfile generic
  $null = ConvertTo-ValidLegacyAgentsFixture $Repo
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling','Modified legacy body')
  $Before = Snapshot $Repo; $Backups = Get-InstallBackupCount $Repo; $Transactions = Get-TransactionCount $Repo
  $Result = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json
  Assert ($LASTEXITCODE -eq 0 -and $Result.exit_code -eq 0 -and $Result.success) 'Legacy plan plus replace failed.'
  $Expected = @('update .qbit-toolkit/codex-ai-tooling/manifest.json','update .qbit/toolkit/installed/codex-ai-tooling.json','update AGENTS.md')
  Assert (($Result.planned_actions -join "`n") -ceq ($Expected -join "`n")) 'Legacy plan plus replace actions differ from the exact required set.'
  Assert ((Snapshot $Repo) -ceq $Before -and (Get-InstallBackupCount $Repo) -eq $Backups -and (Get-TransactionCount $Repo) -eq $Transactions) 'Legacy plan plus replace mutated target state.'
  Assert (-not (Test-Path -LiteralPath (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/lock.json'))) 'Legacy plan plus replace left a lock.'
}
Scenario 'PowerShell and Bash modified legacy plan plus replace have semantic parity' {
  $Repo = New-Repo 'legacy-plan-parity'
  WriteText (Join-Path $Repo 'AGENTS.md') "prefix`n"
  RunInstall $Repo -InstallProfile generic
  $null = ConvertTo-ValidLegacyAgentsFixture $Repo
  WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')) -replace 'Qbit AI tooling','Modified legacy body')
  $Before = Snapshot $Repo
  $PowerShellResult = (& $Install -Operation plan -Target $Repo -Profile generic -OwnedModified replace -Format json -NonInteractive 2>$null) | ConvertFrom-Json; $PowerShellExit = $LASTEXITCODE
  $WslInstaller = ((& wsl.exe --exec wslpath -u $BashInstall) -join '').Trim(); $WslTarget = ((& wsl.exe --exec wslpath -u $Repo) -join '').Trim()
  $BashInvocation = Invoke-WslJson @('bash',$WslInstaller,'--operation','plan','--target',$WslTarget,'--profile','generic','--owned-modified','replace','--format','json','--non-interactive'); $BashResult = $BashInvocation.Result; $BashExit = $BashInvocation.ExitCode
  Assert ($PowerShellExit -eq $BashExit -and $PowerShellResult.exit_code -eq $BashResult.exit_code -and $PowerShellResult.success -eq $BashResult.success) 'Legacy host plan status differs.'
  Assert ($PowerShellResult.detected_state -ceq $BashResult.detected_state) 'Legacy host detected_state differs.'
  Assert (($PowerShellResult.planned_actions -join "`n") -ceq ($BashResult.planned_actions -join "`n")) 'Legacy host planned_actions differ.'
  Assert (($PowerShellResult.conflicts -join "`n") -ceq ($BashResult.conflicts -join "`n")) 'Legacy host conflicts differ.'
  Assert ((ConvertTo-Json -InputObject @($PowerShellResult.errors) -Depth 10 -Compress) -ceq (ConvertTo-Json -InputObject @($BashResult.errors) -Depth 10 -Compress)) 'Legacy host errors differ.'
  Assert ((Snapshot $Repo) -ceq $Before) 'Legacy host parity planning mutated the fixture.'
}
Scenario 'PowerShell legacy negative cases fail closed under replace' {
  $LegacyBegin = '<!-- >>> qbit-toolkit:codex-ai-tooling -->'; $LegacyEnd = '<!-- <<< qbit-toolkit:codex-ai-tooling -->'
  $Repo = New-Repo 'legacy-unowned'; WriteText (Join-Path $Repo 'AGENTS.md') "$LegacyBegin`nunowned`n$LegacyEnd`n"; Assert-LegacyReplaceFailure $Repo 4 'Unowned legacy markers'
  $Repo = New-Repo 'legacy-missing-end'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md')).Replace($LegacyEnd,'')); Assert-LegacyReplaceFailure $Repo 4 'Missing legacy end marker'
  $Repo = New-Repo 'legacy-reversed'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; $Text=(ReadText (Join-Path $Repo 'AGENTS.md')).Replace($LegacyBegin,'LEGACY-TEMP').Replace($LegacyEnd,$LegacyBegin).Replace('LEGACY-TEMP',$LegacyEnd); WriteText (Join-Path $Repo 'AGENTS.md') $Text; Assert-LegacyReplaceFailure $Repo 4 'Reversed legacy markers'
  $Repo = New-Repo 'legacy-duplicate'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; $Block=Get-CompleteManagedBlock (ReadText (Join-Path $Repo 'AGENTS.md')) $LegacyBegin $LegacyEnd; WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md'))+$Block); Assert-LegacyReplaceFailure $Repo 4 'Duplicate legacy blocks'
  $Repo = New-Repo 'legacy-simultaneous'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; WriteText (Join-Path $Repo 'AGENTS.md') ((ReadText (Join-Path $Repo 'AGENTS.md'))+"$AgentsBeginMarker`ncurrent`n$AgentsEndMarker`n"); Assert-LegacyReplaceFailure $Repo 4 'Simultaneous current and legacy blocks'
  $Repo = New-Repo 'legacy-missing-state'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; Remove-Item -LiteralPath (Join-Path $Repo $StatePath); Assert-LegacyReplaceFailure $Repo 4 'Missing legacy ownership state'
  $Repo = New-Repo 'legacy-corrupt-state'; RunInstall $Repo -InstallProfile generic; $null=ConvertTo-ValidLegacyAgentsFixture $Repo; Add-Content -LiteralPath (Join-Path $Repo $StatePath) -Value 'not-json'; Assert-LegacyReplaceFailure $Repo 5 'Corrupt legacy ownership state'
}
Scenario 'Malformed AGENTS markers fail safely' {
  $Repo = New-Repo 'agents-malformed'
  WriteText (Join-Path $Repo 'AGENTS.md') "<!-- qbit-toolkit:codex-ai-tooling:start -->`nmissing end`n"
  ExpectFailure { RunInstall $Repo -InstallProfile 'generic' } 'Malformed AGENTS marker did not fail.'
}
Scenario 'AGENTS boundary variants round trip exactly' {
  $Cases = [ordered]@{
    'no-final-newline' = "# Repo`nTrailing spaces  "
    'one-final-newline' = "# Repo`nTrailing spaces  `n"
    'multiple-trailing-blanks' = "# Repo`nTrailing spaces  `n`n`n"
    'empty-existing-file' = ''
  }
  foreach ($Name in $Cases.Keys) {
    $Repo = New-Repo "agents-roundtrip-$Name"
    $Original = $Cases[$Name]
    WriteText (Join-Path $Repo 'AGENTS.md') $Original
    RunInstall $Repo -InstallProfile 'rust'
    & $Uninstall -Target $Repo
    Assert (Test-Path (Join-Path $Repo 'AGENTS.md')) "AGENTS.md missing after $Name round trip."
    Assert ((ReadText (Join-Path $Repo 'AGENTS.md')) -eq $Original) "AGENTS.md changed after $Name round trip."
  }
  $AbsentRepo = New-Repo 'agents-roundtrip-absent'
  RunInstall $AbsentRepo -InstallProfile 'generic'
  & $Uninstall -Target $AbsentRepo
  Assert (-not (Test-Path (Join-Path $AbsentRepo 'AGENTS.md'))) 'Installer-created AGENTS.md was not removed.'
}
Scenario 'AGENTS valid block with prefix suffix round trips exactly' {
  $Repo = New-Repo 'agents-valid-prefix-suffix'
  $Path = Join-Path $Repo 'AGENTS.md'
  $Prefix = "prefix trailing  `n`n"
  $Suffix = "`nsuffix trailing  `n`n"
  $Expected = $Prefix + $Suffix
  WriteText $Path $Expected
  RunInstall $Repo -InstallProfile 'generic'
  $OldBlock = "<!-- qbit-toolkit:codex-ai-tooling:start -->`nold managed`n<!-- qbit-toolkit:codex-ai-tooling:end -->`n"
  WriteText $Path ($Prefix + "`n" + $OldBlock + $Suffix)
  RunInstall $Repo -InstallProfile 'generic' -Replace
  Assert ((ReadText $Path) -match 'Qbit AI tooling') 'Managed AGENTS block was not updated.'
  & $Uninstall -Target $Repo
  Assert ((ReadText $Path) -eq $Expected) 'AGENTS prefix/suffix not preserved after valid block removal.'
}
Scenario 'AGENTS managed-block replacement preserves suffix without final LF' {
  $Repo = New-Repo 'agents-valid-no-final-lf'
  RunInstall $Repo -InstallProfile 'generic'
  $Path = Join-Path $Repo 'AGENTS.md'
  $CanonicalBlock = Get-CompleteManagedBlock (ReadText $Path) '<!-- qbit-toolkit:codex-ai-tooling:start -->' '<!-- qbit-toolkit:codex-ai-tooling:end -->'
  $Prefix = "project-owned prefix`n"
  $Suffix = 'project-owned suffix trailing  '
  $OldBlock = "<!-- qbit-toolkit:codex-ai-tooling:start -->`nold managed block`n<!-- qbit-toolkit:codex-ai-tooling:end -->`n"
  WriteText $Path ($Prefix + $OldBlock + $Suffix)
  RunInstall $Repo -InstallProfile 'generic' -Replace
  $ExpectedInstalled = $Prefix + $CanonicalBlock + $Suffix
  $Installed = ReadText $Path
  Assert ($Installed -eq $ExpectedInstalled) 'Installed AGENTS.md did not match exact canonical replacement content.'
  Assert (-not $Installed.EndsWith("`n")) 'Installed AGENTS.md gained a terminal LF.'
  & $Verify -Target $Repo
  & $Uninstall -Target $Repo
  $ExpectedRemaining = $Prefix + $Suffix
  $Remaining = ReadText $Path
  Assert ($Remaining -eq $ExpectedRemaining) 'Uninstalled AGENTS.md did not preserve exact project-owned content.'
  Assert (-not $Remaining.EndsWith("`n")) 'Uninstalled AGENTS.md gained a terminal LF.'
}
Scenario '.gitignore managed-block replacement preserves suffix without final LF' {
  $Repo = New-Repo 'gitignore-valid-no-final-lf'
  RunInstall $Repo -InstallProfile 'generic'
  $Path = Join-Path $Repo '.gitignore'
  $CanonicalBlock = Get-CompleteManagedBlock (ReadText $Path) '# qbit-toolkit:codex-ai-tooling:start' '# qbit-toolkit:codex-ai-tooling:end'
  $Prefix = "project-owned.log`n"
  $Suffix = 'project-owned-suffix.log  '
  $OldBlock = "# qbit-toolkit:codex-ai-tooling:start`nold managed block`n# qbit-toolkit:codex-ai-tooling:end`n"
  WriteText $Path ($Prefix + $OldBlock + $Suffix)
  RunInstall $Repo -InstallProfile 'generic' -Replace
  $ExpectedInstalled = $Prefix + $CanonicalBlock + $Suffix
  $Installed = ReadText $Path
  Assert ($Installed -eq $ExpectedInstalled) 'Installed .gitignore did not match exact canonical replacement content.'
  Assert (-not $Installed.EndsWith("`n")) 'Installed .gitignore gained a terminal LF.'
  & $Verify -Target $Repo
  & $Uninstall -Target $Repo
  $ExpectedRemaining = $Prefix + $Suffix
  Assert ((ReadText $Path) -eq $ExpectedRemaining) 'Uninstalled .gitignore did not preserve exact project-owned content.'
}
Scenario 'Reversed AGENTS markers fail with snapshot unchanged' {
  $Repo = New-Repo 'agents-reversed-snapshot'
  WriteText (Join-Path $Repo 'AGENTS.md') "<!-- qbit-toolkit:codex-ai-tooling:end -->`nbody`n<!-- qbit-toolkit:codex-ai-tooling:start -->`n"
  $Before = Snapshot $Repo
  ExpectFailure { RunInstall $Repo -InstallProfile 'generic' } 'Reversed AGENTS markers did not fail.'
  Assert ((Snapshot $Repo) -eq $Before) 'Malformed install changed target snapshot.'
}
Scenario 'Malformed AGENTS uninstall fails with snapshot unchanged' {
  $Repo = New-Repo 'agents-malformed-uninstall'
  WriteText (Join-Path $Repo 'AGENTS.md') "# Repo`n"
  RunInstall $Repo -InstallProfile 'generic'
  $Text = ReadText (Join-Path $Repo 'AGENTS.md')
  WriteText (Join-Path $Repo 'AGENTS.md') ($Text -replace [regex]::Escape('<!-- qbit-toolkit:codex-ai-tooling:end -->'), '<!-- qbit-toolkit:codex-ai-tooling:start -->')
  $Before = Snapshot $Repo
  ExpectFailure { & $Uninstall -Target $Repo } 'Malformed AGENTS uninstall did not fail.'
  Assert ((Snapshot $Repo) -eq $Before) 'Malformed uninstall changed target snapshot.'
}
Scenario 'Uninstall removes only owned files' {
  $Repo = New-Repo 'uninstall-safe'
  Set-Content -LiteralPath (Join-Path $Repo 'USER.txt') -Value 'keep'
  Set-Content -LiteralPath (Join-Path $Repo '.gitignore') -Value "keep.log`n"
  RunInstall $Repo -InstallProfile 'generic'
  & $Uninstall -Target $Repo
  Assert (Test-Path (Join-Path $Repo 'USER.txt')) 'Uninstall removed unrelated file.'
  Assert ((ReadText (Join-Path $Repo '.gitignore')) -match 'keep\.log') 'Uninstall removed unrelated .gitignore content.'
  Assert (-not ((ReadText (Join-Path $Repo '.gitignore')) -match 'qbit-toolkit:codex-ai-tooling')) 'Managed block remained after uninstall.'
}
Scenario 'Uninstall preserves original AGENTS content' {
  $Repo = New-Repo 'agents-uninstall-preserve'
  $Original = Get-ProjectAgentsFixture
  WriteText (Join-Path $Repo 'AGENTS.md') $Original
  RunInstall $Repo -InstallProfile 'rust'
  & $Uninstall -Target $Repo
  Assert ((ReadText (Join-Path $Repo 'AGENTS.md')) -eq $Original) 'Uninstall did not preserve original AGENTS content.'
}
Scenario 'Unrelated AGENTS edits do not block uninstall' {
  $Repo = New-Repo 'agents-unrelated-edit'
  $Original = Get-ProjectAgentsFixture
  Set-Content -LiteralPath (Join-Path $Repo 'AGENTS.md') -Value $Original -NoNewline
  RunInstall $Repo -InstallProfile 'generic'
  Add-Content -LiteralPath (Join-Path $Repo 'AGENTS.md') -Value "`nAdditional project-owned instruction."
  & $Uninstall -Target $Repo
  Assert ((ReadText (Join-Path $Repo 'AGENTS.md')) -match 'Additional project-owned instruction') 'Unrelated AGENTS edit was lost.'
}
Scenario 'Verify fails after managed AGENTS block modification' {
  $Repo = New-Repo 'verify-block-modified'
  WriteText (Join-Path $Repo 'AGENTS.md') "# Repo`n"
  RunInstall $Repo -InstallProfile 'generic'
  $Text = ReadText (Join-Path $Repo 'AGENTS.md')
  WriteText (Join-Path $Repo 'AGENTS.md') ($Text -replace 'Qbit AI tooling', 'Modified AI tooling')
  ExpectFailure { & $Verify -Target $Repo } 'Verify did not fail after managed block modification.'
}
Scenario 'Verify passes after unrelated AGENTS outside-block modification' {
  $Repo = New-Repo 'verify-block-outside-edit'
  WriteText (Join-Path $Repo 'AGENTS.md') "# Repo`n"
  RunInstall $Repo -InstallProfile 'generic'
  WriteText (Join-Path $Repo 'AGENTS.md') ("# Repo updated outside block`n" + (ReadText (Join-Path $Repo 'AGENTS.md')).Substring("# Repo`n".Length))
  & $Verify -Target $Repo
}
Scenario 'Normal uninstall fails after managed AGENTS block modification' {
  $Repo = New-Repo 'uninstall-block-modified'
  WriteText (Join-Path $Repo 'AGENTS.md') "# Repo`n"
  RunInstall $Repo -InstallProfile 'generic'
  $Text = ReadText (Join-Path $Repo 'AGENTS.md')
  WriteText (Join-Path $Repo 'AGENTS.md') ($Text -replace 'Qbit AI tooling', 'Modified AI tooling')
  ExpectFailure { & $Uninstall -Target $Repo } 'Normal uninstall did not fail after managed block modification.'
}
Scenario 'Replace-policy uninstall backs up and removes modified AGENTS block' {
  $Repo = New-Repo 'uninstall-block-force'
  WriteText (Join-Path $Repo 'AGENTS.md') "# Repo`n"
  RunInstall $Repo -InstallProfile 'generic'
  $Text = ReadText (Join-Path $Repo 'AGENTS.md')
  WriteText (Join-Path $Repo 'AGENTS.md') ($Text -replace 'Qbit AI tooling', 'Modified AI tooling')
  & $Uninstall -Target $Repo -OwnedModified replace
  Assert (-not ((ReadText (Join-Path $Repo 'AGENTS.md')) -match 'qbit-toolkit:codex-ai-tooling')) 'Replace-policy uninstall left AGENTS block.'
  Assert (Test-Path (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups')) 'Replace-policy AGENTS uninstall backup missing.'
}
Scenario 'Modified managed file blocks normal uninstall' {
  $Repo = New-Repo 'uninstall-modified'
  RunInstall $Repo -InstallProfile 'generic'
  Add-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'modified'
  ExpectFailure { & $Uninstall -Target $Repo } 'Modified managed file did not block uninstall.'
}
Scenario 'Replace-policy uninstall backs up modified files' {
  $Repo = New-Repo 'uninstall-force'
  RunInstall $Repo -InstallProfile 'generic'
  Add-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'modified'
  & $Uninstall -Target $Repo -OwnedModified replace
  Assert (Test-Path (Join-Path $Repo '.qbit-toolkit/codex-ai-tooling/backups')) 'Replace-policy uninstall backup missing.'
}
Scenario 'Missing state-declared managed file blocks normal and forced uninstall preflight' {
  $Repo = New-Repo 'uninstall-missing-managed-file'
  RunInstall $Repo -InstallProfile 'generic'
  $StateFile = Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json'
  $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  $ManagedProperty = $State.managedFiles.PSObject.Properties | Select-Object -First 1
  Assert ($null -ne $ManagedProperty) 'Installed state declared no managed files.'
  Remove-Item -LiteralPath (Join-Path $Repo $ManagedProperty.Name) -Force
  Assert (Test-Path -LiteralPath $StateFile -PathType Leaf) 'State file was missing before uninstall preflight.'
  $Before = Snapshot $Repo
  $BackupCount = Get-UninstallBackupCount $Repo
  ExpectFailure { & $Uninstall -Target $Repo } 'Normal uninstall accepted a missing state-declared managed file.'
  Assert ((Snapshot $Repo) -eq $Before) 'Normal missing-file preflight changed the target snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'Normal missing-file preflight created an uninstall backup.'
  ExpectFailure { & $Uninstall -Target $Repo -OwnedModified replace } 'Replace-policy uninstall accepted a missing state-declared managed file.'
  Assert ((Snapshot $Repo) -eq $Before) 'Replace-policy missing-file preflight changed the target snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'Replace-policy missing-file preflight created an uninstall backup.'
  Assert (Test-Path -LiteralPath $StateFile -PathType Leaf) 'Missing-file preflight removed the state file.'
}
Scenario 'Missing state-declared managed-block file blocks normal and forced uninstall preflight' {
  $Repo = New-Repo 'uninstall-missing-managed-block-file'
  RunInstall $Repo -InstallProfile 'generic'
  $StateFile = Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json'
  $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
  $BlockProperty = $State.managedBlocks.PSObject.Properties | Where-Object Name -eq 'AGENTS.md' | Select-Object -First 1
  if ($null -eq $BlockProperty) { $BlockProperty = $State.managedBlocks.PSObject.Properties | Select-Object -First 1 }
  Assert ($null -ne $BlockProperty) 'Installed state declared no managed blocks.'
  Remove-Item -LiteralPath (Join-Path $Repo $BlockProperty.Name) -Force
  Assert (Test-Path -LiteralPath $StateFile -PathType Leaf) 'State file was missing before managed-block preflight.'
  $Before = Snapshot $Repo
  $BackupCount = Get-UninstallBackupCount $Repo
  ExpectFailure { & $Uninstall -Target $Repo } 'Normal uninstall accepted a missing state-declared managed-block file.'
  Assert ((Snapshot $Repo) -eq $Before) 'Normal missing-block preflight changed the target snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'Normal missing-block preflight created an uninstall backup.'
  ExpectFailure { & $Uninstall -Target $Repo -OwnedModified replace } 'Replace-policy uninstall accepted a missing state-declared managed-block file.'
  Assert ((Snapshot $Repo) -eq $Before) 'Replace-policy missing-block preflight changed the target snapshot.'
  Assert ((Get-UninstallBackupCount $Repo) -eq $BackupCount) 'Replace-policy missing-block preflight created an uninstall backup.'
  Assert (Test-Path -LiteralPath $StateFile -PathType Leaf) 'Missing-block preflight removed the state file.'
}
Scenario 'PowerShell missing required managed-block record state fails closed' {
  $Repo = New-Repo 'powershell-state-missing-required-block'
  RunInstall $Repo -InstallProfile 'generic'
  Assert-StateCorruptionFailsClosed $Repo {
    param($StateFile)
    $State = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    $State.managedBlocks.PSObject.Properties.Remove('.gitattributes')
    WriteText $StateFile (($State | ConvertTo-Json -Depth 10) + "`n")
  }
}
Scenario 'PowerShell duplicate managed-file path state fails closed' {
  $Repo = New-Repo 'powershell-state-duplicate-managed-file'
  RunInstall $Repo -InstallProfile 'generic'
  Assert-StateCorruptionFailsClosed $Repo {
    param($StateFile)
    $Text = ReadText $StateFile
    $Match = [regex]::Match($Text, '(?m)^(    "[^"]+": "[0-9a-f]{64}",)$')
    Assert $Match.Success 'Could not locate a managed-file state entry to duplicate.'
    WriteText $StateFile ($Text.Substring(0, $Match.Index) + $Match.Value + "`n" + $Match.Value + $Text.Substring($Match.Index + $Match.Length))
  }
}
Scenario 'PowerShell leading non-JSON state garbage fails every consumer closed' {
  Invoke-StateCorruptionScenario 'leading-garbage' { param($StateFile) WriteText $StateFile ("garbage`n" + (ReadText $StateFile)) }
}
Scenario 'PowerShell trailing state garbage fails every consumer closed' {
  Invoke-StateCorruptionScenario 'trailing-garbage' { param($StateFile) WriteText $StateFile ((ReadText $StateFile) + 'garbage') }
}
Scenario 'PowerShell duplicate top-level state key fails every consumer closed' {
  Invoke-StateCorruptionScenario 'duplicate-top-level' { param($StateFile) $Text=ReadText $StateFile; $Match=[regex]::Match($Text,'(?m)^  "profile": "[^"]+",$'); Assert $Match.Success 'Profile line missing.'; WriteText $StateFile ($Text.Insert($Match.Index + $Match.Length, "`n" + $Match.Value)) }
}
Scenario 'PowerShell missing required top-level state field fails every consumer closed' {
  Invoke-StateCorruptionScenario 'missing-top-level' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.PSObject.Properties.Remove('dockerImageName') } }
}
Scenario 'PowerShell malformed JSON string escape fails every consumer closed' {
  Invoke-StateCorruptionScenario 'malformed-escape' { param($StateFile) WriteText $StateFile ((ReadText $StateFile) -replace '(?m)^  "projectDisplayName": .*,$','  "projectDisplayName": "bad\q",') }
}
Scenario 'PowerShell duplicate installedRelativePaths entry fails every consumer closed' {
  Invoke-StateCorruptionScenario 'duplicate-installed-path' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedRelativePaths=@($State.installedRelativePaths)+@($State.installedRelativePaths[0]) } }
}
Scenario 'PowerShell missing state path from installedRelativePaths fails every consumer closed' {
  Invoke-StateCorruptionScenario 'missing-state-installed-path' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedRelativePaths=@($State.installedRelativePaths | Where-Object { $_ -ne '.qbit/toolkit/installed/codex-ai-tooling.json' }) } }
}
Scenario 'PowerShell unexpected installedRelativePaths entry fails every consumer closed' {
  Invoke-StateCorruptionScenario 'unexpected-installed-path' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedRelativePaths=@($State.installedRelativePaths)+@('unexpected-owned.txt') } }
}
Scenario 'PowerShell managed file removed only from managedFiles fails every consumer closed' {
  Invoke-StateCorruptionScenario 'missing-managed-only' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Name=@($State.managedFiles.PSObject.Properties)[0].Name; $State.managedFiles.PSObject.Properties.Remove($Name) } }
}
Scenario 'PowerShell managed file removed from both ownership sections fails every consumer closed' {
  Invoke-StateCorruptionScenario 'missing-managed-both' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Name=@($State.managedFiles.PSObject.Properties)[0].Name; $State.managedFiles.PSObject.Properties.Remove($Name); $State.installedRelativePaths=@($State.installedRelativePaths | Where-Object { $_ -ne $Name }) } }
}
Scenario 'PowerShell managed file outside expected profile manifest fails every consumer closed' {
  Invoke-StateCorruptionScenario 'unexpected-managed-manifest' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.managedFiles | Add-Member -NotePropertyName 'unexpected-owned.txt' -NotePropertyValue ('a' * 64); $State.installedRelativePaths=@($State.installedRelativePaths)+@('unexpected-owned.txt') } }
}
Scenario 'PowerShell truncated complete state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'truncated-complete-state' { param($StateFile) $Text=ReadText $StateFile; $Cut=$Text.IndexOf('  "managedFiles": {',[StringComparison]::Ordinal); WriteText $StateFile $Text.Substring(0,$Cut+22) }
}
Scenario 'PowerShell escaped newline display-name state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'escaped-display-newline' { param($StateFile) WriteText $StateFile ((ReadText $StateFile) -replace '(?m)^  "projectDisplayName": .*,$','  "projectDisplayName": "Qbit\nCLI",') }
}
Scenario 'PowerShell escaped Unicode tab display-name state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'escaped-display-tab' { param($StateFile) WriteText $StateFile ((ReadText $StateFile) -replace '(?m)^  "projectDisplayName": .*,$','  "projectDisplayName": "Qbit\u0009CLI",') }
}
Scenario 'PowerShell duplicate allowed origin state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'duplicate-origin' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.allowedOrigins=@($State.allowedOrigins[0],$State.allowedOrigins[0],$State.allowedOrigins[1]) } }
}
Scenario 'PowerShell duplicate IPv6 origin state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'duplicate-ipv6-origin' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.allowedOrigins=@('http://[::1]:3000','http://[::1]:3000','http://localhost:3000') } }
}
Scenario 'PowerShell impossible UTC timestamp state fails every consumer closed' {
  Invoke-StateCorruptionScenario 'invalid-calendar-time' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedAtUtc='2026-02-30T00:00:00Z' } }
}
Scenario 'PowerShell wrong-cased managedFiles path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'wrong-case-managed' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Property=@($State.managedFiles.PSObject.Properties)[0]; $State.managedFiles.PSObject.Properties.Remove($Property.Name); $State.managedFiles | Add-Member -NotePropertyName ($Property.Name.ToUpperInvariant()) -NotePropertyValue $Property.Value } }
}
Scenario 'PowerShell wrong-cased installedRelativePaths path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'wrong-case-installed' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedRelativePaths=@($State.installedRelativePaths | ForEach-Object { if ($_ -ceq '.env.ai.example') { '.ENV.AI.EXAMPLE' } else { $_ } }) } }
}
Scenario 'PowerShell wrong-cased managed-block path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'wrong-case-block' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Record=$State.managedBlocks.'.gitignore'; $State.managedBlocks.PSObject.Properties.Remove('.gitignore'); $State.managedBlocks | Add-Member -NotePropertyName '.GitIgnore' -NotePropertyValue $Record } }
}
Scenario 'PowerShell non-ASCII managedFiles path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'non-ascii-managed' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Property=@($State.managedFiles.PSObject.Properties)[0]; $State.managedFiles.PSObject.Properties.Remove($Property.Name); $State.managedFiles | Add-Member -NotePropertyName 'owned/café.txt' -NotePropertyValue $Property.Value } }
}
Scenario 'PowerShell non-ASCII installedRelativePaths path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'non-ascii-installed' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $State.installedRelativePaths=@($State.installedRelativePaths | ForEach-Object { if ($_ -ceq '.env.ai.example') { 'owned/café.txt' } else { $_ } }) } }
}
Scenario 'PowerShell non-ASCII managed-block path fails every consumer closed' {
  Invoke-StateCorruptionScenario 'non-ascii-block' { param($StateFile) Rewrite-StateObject $StateFile { param($State) $Record=$State.managedBlocks.'.gitignore'; $State.managedBlocks.PSObject.Properties.Remove('.gitignore'); $State.managedBlocks | Add-Member -NotePropertyName 'café.block' -NotePropertyValue $Record } }
}
Scenario 'Verify detects modified file hashes' {
  $Repo = New-Repo 'verify-modified'
  RunInstall $Repo -InstallProfile 'generic'
  Add-Content -LiteralPath (Join-Path $Repo '.env.ai.example') -Value 'modified'
  ExpectFailure { & $Verify -Target $Repo } 'Verify did not detect modified file.'
}
Scenario 'No target root package manager commands are executed' {
  $Repo = New-Repo 'no-root-pm'
  $Bin = Join-Path $TempRoot 'fake-bin'; New-Item -ItemType Directory -Force -Path $Bin | Out-Null
  Set-Content -LiteralPath (Join-Path $Bin 'npm.cmd') -Value "@echo called > `"$TempRoot\npm-called.txt`"`r`nexit /b 99`r`n"
  $OldPath = $env:PATH; $env:PATH = "$Bin;$OldPath"
  try { RunInstall $Repo -InstallProfile 'generic' } finally { $env:PATH = $OldPath }
  Assert (-not (Test-Path (Join-Path $TempRoot 'npm-called.txt'))) 'Installer invoked npm during skipped bootstrap.'
}
Scenario 'No browser installation is attempted' {
  $Repo = New-Repo 'no-browser'
  RunInstall $Repo -InstallProfile 'generic'
  foreach($Rel in @('.ai/scripts/bootstrap.ps1','.ai/scripts/bootstrap.sh','.ai/scripts/doctor.ps1','.ai/scripts/doctor.sh')){
    $Text = ReadText (Join-Path $Repo $Rel)
    Assert (-not ($Text -match ('install-' + 'browser|playwright\s+' + 'install|--with-deps|chrom' + 'ium|ch' + 'rome'))) "Browser install token in $Rel"
  }
}
Scenario 'No source-specific absolute path is written' {
  $Repo = New-Repo 'no-absolute-path'
  RunInstall $Repo -InstallProfile 'generic'
  $PathPattern = 'D:\\Projects\\' + 'Hen' + 'kel|D:\\Projects\\' + 'Q' + 'bit|C:\\' + 'Users' + '\\|/' + 'Users' + '/[^/]+/|/' + 'home' + '/[^/]+/'
  $Matches = Get-ChildItem -LiteralPath $Repo -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' } | Select-String -Pattern $PathPattern
  Assert (-not $Matches) 'Absolute source path found in installed output.'
}
Scenario 'No reference-project string remains' {
  $Repo = New-Repo 'no-reference-name'
  RunInstall $Repo -InstallProfile 'typescript'
  $ReferencePattern = 'hen' + 'kel'
  $Matches = Get-ChildItem -LiteralPath $Repo -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' } | Select-String -Pattern $ReferencePattern -CaseSensitive:$false
  Assert (-not $Matches) 'Reference-project string found in installed output.'
}
Scenario 'No unresolved placeholders remain' {
  $Repo = New-Repo 'no-placeholders'
  RunInstall $Repo -InstallProfile 'typescript'
  $Matches = Get-ChildItem -LiteralPath $Repo -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' } | Select-String -Pattern '\{\{[A-Z0-9_]+\}\}'
  Assert (-not $Matches) 'Unresolved placeholder found in installed output.'
}
Scenario 'Sentry is absent from installed configuration' {
  $Repo = New-Repo 'no-sentry'
  RunInstall $Repo -InstallProfile 'generic'
  $Config = ReadText (Join-Path $Repo '.codex/config.toml')
  Assert (-not ($Config -match 'sentry|find_organizations|search_issues|update_issue|execute_sentry_tool|analyze_issue_with_seer')) 'Sentry configuration or tools are present.'
}
Scenario 'Graphify and Playwright are not MCP servers' {
  $Repo = New-Repo 'no-graphify-playwright-mcp'
  RunInstall $Repo -InstallProfile 'generic'
  $Config = ReadText (Join-Path $Repo '.codex/config.toml')
  Assert (-not ($Config -match 'mcp_servers\.(graphify|playwright)')) 'Graphify or Playwright MCP server configured.'
}
Scenario 'Installed shell scripts use LF' {
  $Repo = New-Repo 'lf-shell'
  RunInstall $Repo -InstallProfile 'typescript'
  $Bad = Get-ChildItem -LiteralPath $Repo -Recurse -Filter *.sh -File -Force | Where-Object { [IO.File]::ReadAllBytes($_.FullName) -contains 13 }
  Assert (-not $Bad) 'CRLF found in installed shell script.'
}
Scenario 'Installer state contains no secret or absolute path' {
  $Repo = New-Repo 'state-clean'
  RunInstall $Repo -InstallProfile 'generic'
  $Text = ReadText (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json')
  $StatePathPattern = 'sk-[A-Za-z0-9_-]{20,}|D:\\Projects|C:\\' + 'Users' + '|/' + 'Users' + '/[^/]+/|/' + 'home' + '/[^/]+/'
  Assert (-not ($Text -match $StatePathPattern)) 'State contains secret-looking value or absolute path.'
}
Scenario 'Rust Bootstrap and Doctor contain no target Cargo operations' {
  $Repo = New-Repo 'rust-no-cargo-root'
  Set-Content -LiteralPath (Join-Path $Repo 'Cargo.toml') -Value '[package]' -NoNewline
  RunInstall $Repo
  foreach($Rel in @('.ai/scripts/bootstrap.ps1','.ai/scripts/bootstrap.sh','.ai/scripts/doctor.ps1','.ai/scripts/doctor.sh')){
    $Text = ReadText (Join-Path $Repo $Rel)
    Assert (-not ($Text -match 'cargo\s+(build|fetch|install)')) "Target Cargo operation token in $Rel"
  }
}
}
finally {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
$Script:Skipped++
Write-Host 'SKIP Docker-dependent feature checks: run tools/test.ps1 -Layer docker for actual Bootstrap/Doctor validation'
Write-Host "RESULT passed=$Script:Passed failed=$Script:Failed skipped=$Script:Skipped"
if ($Script:Failed -gt 0) { exit 1 }
