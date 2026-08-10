[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:Passed = 0
$Script:Failed = 0
$Script:Skipped = 0
$InstallerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $InstallerRoot 'lib/installer.ps1')

function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function AssertEqual($Expected, $Actual, [string]$Message) { if ($Expected -ne $Actual) { throw "$Message Expected=[$Expected] Actual=[$Actual]" } }
function AssertThrows([scriptblock]$Block, [string]$Message) {
  $Thrown = $false
  try { & $Block | Out-Null } catch { $Thrown = $true }
  if (-not $Thrown) { throw $Message }
}
function Scenario([string]$Name, [scriptblock]$Body) {
  try { & $Body; $Script:Passed++; Write-Host "PASS $Name" }
  catch { $Script:Failed++; Write-Host "FAIL $Name :: $($_.Exception.Message)" -ForegroundColor Red }
}
function New-TempDir([string]$Name) {
  $Path = Join-Path ([System.IO.Path]::GetTempPath()) ('qbit-unit-' + $Name + '-' + [System.Guid]::NewGuid().ToString('n'))
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  return $Path
}
function New-StateTimestampFixture(
  [string]$Name,
  [string]$TimestampToken,
  [string]$SeparatorToken = '1',
  [string]$AllowedOriginsToken = '["http://localhost:3000", "http://127.0.0.1:3000"]',
  [string]$InstalledPathsToken = '[".gitattributes", ".gitignore", ".qbit/toolkit/installed/codex-ai-tooling.json", "AGENTS.md"]'
) {
  $Root = New-TempDir $Name
  $TempRoots.Add($Root)
  $Path = Join-Path $Root 'state.json'
  $Hash = 'a' * 64
  $Json = @"
{
  "schemaVersion": "1.0",
  "installerId": "installer.codex-ai-tooling",
  "installerVersion": "1.0.0",
  "toolkitSchemaVersion": "1.0",
  "profile": "generic",
  "projectSlug": "state-timestamp",
  "projectDisplayName": "State Timestamp",
  "allowedOrigins": $AllowedOriginsToken,
  "dockerImageName": "state-timestamp-ai-tooling:serena-1.5.3-graphify-0.9.12",
  "installedAtUtc": $TimestampToken,
  "installedRelativePaths": $InstalledPathsToken,
  "managedFiles": {},
  "managedBlocks": {
    ".gitattributes": {"sha256": "$Hash", "createdFile": false, "insertedSeparatorLfCount": $SeparatorToken},
    ".gitignore": {"sha256": "$Hash", "createdFile": false, "insertedSeparatorLfCount": $SeparatorToken},
    "AGENTS.md": {"sha256": "$Hash", "createdFile": false, "insertedSeparatorLfCount": $SeparatorToken}
  },
  "stateFile": ".qbit/toolkit/installed/codex-ai-tooling.json"
}
"@
  [IO.File]::WriteAllText($Path, $Json, [Text.UTF8Encoding]::new($false))
  return $Path
}
function Invoke-WithPersianCulture([scriptblock]$Body) {
  $Thread = [Threading.Thread]::CurrentThread
  $PreviousCulture = $Thread.CurrentCulture
  $PreviousUiCulture = $Thread.CurrentUICulture
  $Culture = [Globalization.CultureInfo]::GetCultureInfo('fa-IR').Clone()
  $Culture.DateTimeFormat.Calendar = [Globalization.PersianCalendar]::new()
  try {
    $Thread.CurrentCulture = $Culture
    $Thread.CurrentUICulture = $Culture
    & $Body
  } finally {
    $Thread.CurrentCulture = $PreviousCulture
    $Thread.CurrentUICulture = $PreviousUiCulture
  }
}

$TempRoots = New-Object System.Collections.Generic.List[string]
try {
  Scenario 'slug normalizes case spaces underscores symbols' {
    AssertEqual 'my-project-name' (Get-ProjectSlug ' My_Project Name!! ' 'fallback') 'Slug normalization failed.'
  }
  Scenario 'slug uses fallback name' {
    AssertEqual 'fallback-name' (Get-ProjectSlug '' 'Fallback Name') 'Slug fallback failed.'
  }
  Scenario 'slug rejects empty normalized value' {
    AssertThrows { Get-ProjectSlug '___!!!' 'unused' } 'Empty slug was not rejected.'
  }
  Scenario 'slug trims to fifty characters' {
    $Slug = Get-ProjectSlug ('a' * 60) 'unused'
    AssertEqual 50 $Slug.Length 'Slug max length failed.'
  }
  Scenario 'auto profile detects tsconfig' {
    $Root = New-TempDir 'tsconfig'; $TempRoots.Add($Root)
    Set-Content -LiteralPath (Join-Path $Root 'tsconfig.json') -Value '{}' -NoNewline
    AssertEqual 'typescript' (Resolve-Profile 'auto' $Root) 'tsconfig auto-detection failed.'
  }
  Scenario 'auto profile detects package dependencies' {
    $Root = New-TempDir 'deps'; $TempRoots.Add($Root)
    Set-Content -LiteralPath (Join-Path $Root 'package.json') -Value '{"dependencies":{"typescript":"5.9.3"}}' -NoNewline
    AssertEqual 'typescript' (Resolve-Profile 'auto' $Root) 'dependencies auto-detection failed.'
  }
  Scenario 'auto profile detects package devDependencies' {
    $Root = New-TempDir 'devdeps'; $TempRoots.Add($Root)
    Set-Content -LiteralPath (Join-Path $Root 'package.json') -Value '{"devDependencies":{"typescript":"5.9.3"}}' -NoNewline
    AssertEqual 'typescript' (Resolve-Profile 'auto' $Root) 'devDependencies auto-detection failed.'
  }
  Scenario 'auto profile falls back to generic' {
    $Root = New-TempDir 'generic'; $TempRoots.Add($Root)
    AssertEqual 'generic' (Resolve-Profile 'auto' $Root) 'generic fallback failed.'
  }
  Scenario 'auto profile detects root Cargo toml as rust' {
    $Root = New-TempDir 'rust'; $TempRoots.Add($Root)
    Set-Content -LiteralPath (Join-Path $Root 'Cargo.toml') -Value '[package]' -NoNewline
    AssertEqual 'rust' (Resolve-Profile 'auto' $Root) 'Cargo.toml auto-detection failed.'
  }
  Scenario 'explicit rust profile is preserved' {
    $Root = New-TempDir 'explicit-rust'; $TempRoots.Add($Root)
    AssertEqual 'rust' (Resolve-Profile 'rust' $Root) 'explicit rust profile changed.'
  }
  Scenario 'typescript takes precedence over rust in auto' {
    $Root = New-TempDir 'ts-rust'; $TempRoots.Add($Root)
    Set-Content -LiteralPath (Join-Path $Root 'Cargo.toml') -Value '[package]' -NoNewline
    Set-Content -LiteralPath (Join-Path $Root 'tsconfig.json') -Value '{}' -NoNewline
    AssertEqual 'typescript' (Resolve-Profile 'auto' $Root) 'TypeScript did not take precedence over Rust.'
  }
  Scenario 'nested cargo toml does not activate rust profile' {
    $Root = New-TempDir 'nested-rust'; $TempRoots.Add($Root)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'crates/app') | Out-Null
    Set-Content -LiteralPath (Join-Path $Root 'crates/app/Cargo.toml') -Value '[package]' -NoNewline
    AssertEqual 'generic' (Resolve-Profile 'auto' $Root) 'Nested Cargo.toml activated Rust profile.'
  }
  Scenario 'explicit profile is preserved' {
    $Root = New-TempDir 'explicit'; $TempRoots.Add($Root)
    AssertEqual 'generic' (Resolve-Profile 'generic' $Root) 'explicit profile changed.'
  }
  Scenario 'allowed origin accepts http and normalizes slash' {
    AssertEqual 'http://localhost:3000' (Test-AllowedOrigin 'http://localhost:3000/' $true) 'Allowed origin normalization failed.'
  }
  Scenario 'allowed origin accepts https' {
    AssertEqual 'https://127.0.0.1:3443' (Test-AllowedOrigin 'https://127.0.0.1:3443/path' $true) 'Allowed https origin failed.'
  }
  Scenario 'allowed origin accepts and normalizes IPv6 authority' {
    AssertEqual 'http://[::1]:3000' (Test-AllowedOrigin 'http://[::1]:3000/path' $true) 'IPv6 origin changed.'
  }
  Scenario 'allowed origin rejects non-http scheme' {
    AssertThrows { Test-AllowedOrigin 'ftp://localhost:21' $true } 'Non-http scheme accepted.'
  }
  Scenario 'allowed origin rejects relative input' {
    AssertThrows { Test-AllowedOrigin '/relative' $true } 'Relative origin accepted.'
  }
  Scenario 'allowed origin rejects credentials' {
    AssertThrows { Test-AllowedOrigin 'http://user:pass@localhost:3000' $true } 'Credential origin accepted.'
  }
  Scenario 'allowed origin rejects fragment' {
    AssertThrows { Test-AllowedOrigin 'http://localhost:3000/#frag' $true } 'Fragment origin accepted.'
  }
  Scenario 'allowed origin rejects wildcard host' {
    AssertThrows { Test-AllowedOrigin 'http://*.example.test' $true } 'Wildcard host accepted.'
  }
  Scenario 'managed block inserts while preserving content' {
    $Result = Merge-ManagedBlock "alpha`n" "beta`n"
    Assert ($Result -match 'alpha' -and $Result -match [regex]::Escape($BeginMarker) -and $Result -match 'beta') 'Managed block insertion failed.'
  }
  Scenario 'managed block helper rejects unowned existing block' {
    $Existing = "before`n$BeginMarker`nold`n$EndMarker`nafter`n"
    AssertThrows { Merge-ManagedBlock $Existing "new`n" } 'Unowned managed block was replaced.'
  }
  Scenario 'managed block rejects duplicate markers' {
    $Existing = "$BeginMarker`na`n$EndMarker`n$BeginMarker`nb`n$EndMarker`n"
    AssertThrows { Merge-ManagedBlock $Existing 'body' } 'Duplicate managed markers accepted.'
  }
  Scenario 'managed block recognizes exact marker lines only' {
    AssertThrows { Merge-ManagedBlock "prefix $BeginMarker suffix`n" 'body' } 'Embedded begin marker text was accepted.'
    AssertThrows { Merge-ManagedBlock "prefix $EndMarker suffix`n" 'body' } 'Embedded end marker text was accepted.'
  }
  Scenario 'managed block rejects reversed markers' {
    AssertThrows { Merge-ManagedBlock "$EndMarker`nbody`n$BeginMarker`n" 'new' } 'Reversed marker order was accepted.'
  }
  Scenario 'managed block rejects duplicate begin marker' {
    AssertThrows { Merge-ManagedBlock "$BeginMarker`none`n$BeginMarker`ntwo`n$EndMarker`n" 'new' } 'Duplicate begin marker was accepted.'
  }
  Scenario 'managed block rejects duplicate end marker' {
    AssertThrows { Merge-ManagedBlock "$BeginMarker`none`n$EndMarker`n$EndMarker`n" 'new' } 'Duplicate end marker was accepted.'
  }
  Scenario 'managed block rejects missing begin marker' {
    AssertThrows { Merge-ManagedBlock "body`n$EndMarker`n" 'new' } 'Missing begin marker was accepted.'
  }
  Scenario 'managed block rejects missing end marker' {
    AssertThrows { Merge-ManagedBlock "$BeginMarker`nbody`n" 'new' } 'Missing end marker was accepted.'
  }
  Scenario 'managed block extracts valid block exactly' {
    $Existing = "prefix`n$BeginMarker`nbody`n$EndMarker`nsuffix`n"
    $Analysis = Get-ManagedBlockAnalysis $Existing $BeginMarker $EndMarker 'test'
    AssertEqual 'valid' $Analysis.Status 'Block status was not valid.'
    AssertEqual "$BeginMarker`nbody`n$EndMarker`n" $Analysis.Block 'Extracted block changed.'
    AssertEqual "prefix`n" $Analysis.Prefix 'Prefix extraction changed.'
    AssertEqual "suffix`n" $Analysis.Suffix 'Suffix extraction changed.'
  }
  Scenario 'managed block hash is stable' {
    $Block = Get-ManagedBlockText "body`n" $BeginMarker $EndMarker
    AssertEqual (Get-TextSha256 $Block) (Get-TextSha256 $Block) 'Managed block hash was unstable.'
  }
  Scenario 'managed block insertion records separator metadata' {
    $NoLf = Resolve-ManagedBlockUpdate 'prefix' $true "body`n" $BeginMarker $EndMarker $null 'file'
    $OneLf = Resolve-ManagedBlockUpdate "prefix`n" $true "body`n" $BeginMarker $EndMarker $null 'file'
    $EmptyExisting = Resolve-ManagedBlockUpdate '' $true "body`n" $BeginMarker $EndMarker $null 'file'
    AssertEqual 2 $NoLf.Record.insertedSeparatorLfCount 'No-final-LF separator count changed.'
    AssertEqual 1 $OneLf.Record.insertedSeparatorLfCount 'Final-LF separator count changed.'
    AssertEqual 0 $EmptyExisting.Record.insertedSeparatorLfCount 'Empty existing file separator count changed.'
    Assert (-not $EmptyExisting.Record.createdFile) 'Existing empty file was marked created.'
  }
  Scenario 'managed block replacement preserves exact prefix suffix' {
    $Existing = "prefix trailing  `n$BeginMarker`nold`n$EndMarker`n`n`nsuffix trailing  `n`n"
    $Previous = New-ManagedBlockRecord (Get-ManagedBlockText "old`n" $BeginMarker $EndMarker) $false 0
    $Result = Resolve-ManagedBlockUpdate $Existing $true "new`n" $BeginMarker $EndMarker ([pscustomobject]$Previous) 'file' 'replace'
    $Expected = "prefix trailing  `n$BeginMarker`nnew`n$EndMarker`n`n`nsuffix trailing  `n`n"
    AssertEqual $Expected $Result.Content 'Replacement did not preserve exact prefix/suffix.'
  }
  Scenario 'managed block replacement preserves suffix without final LF' {
    $Existing = "prefix`n$BeginMarker`nold`n$EndMarker`nsuffix trailing  "
    $Previous = New-ManagedBlockRecord (Get-ManagedBlockText "old`n" $BeginMarker $EndMarker) $false 0
    $Result = Resolve-ManagedBlockUpdate $Existing $true "new`n" $BeginMarker $EndMarker ([pscustomobject]$Previous) 'file' 'replace'
    $Expected = "prefix`n$BeginMarker`nnew`n$EndMarker`nsuffix trailing  "
    AssertEqual $Expected $Result.Content 'Replacement changed the complete no-final-LF suffix output.'
    Assert (-not $Result.Content.EndsWith("`n")) 'Replacement appended a terminal LF.'
  }
  Scenario 'effective exact content normalizes line endings without terminal LF' {
    $Item = [ordered]@{ Content = "alpha`r`nsuffix trailing  "; WriteMode = $WriteModeCanonicalExact }
    AssertEqual "alpha`nsuffix trailing  " (Get-EffectivePlanItemContent $Item 'exact.txt') 'Effective exact content changed.'
  }
  Scenario 'exact write mode does not append terminal LF' {
    $Root = New-TempDir 'exact-write'; $TempRoots.Add($Root)
    $Path = Join-Path $Root 'exact.txt'
    $Item = [ordered]@{ Content = "alpha`r`nsuffix trailing  "; WriteMode = $WriteModeCanonicalExact }
    Write-PlanItemText $Path $Item 'exact.txt'
    AssertEqual "alpha`nsuffix trailing  " ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)) 'Exact write mode changed complete content.'
  }
  Scenario 'effective terminal LF content appends once and preserves existing LF' {
    $WithoutLf = [ordered]@{ Content = 'generated trailing  '; WriteMode = $WriteModeCanonicalWithTerminalLf }
    $WithLf = [ordered]@{ Content = "generated trailing  `n"; WriteMode = $WriteModeCanonicalWithTerminalLf }
    AssertEqual "generated trailing  `n" (Get-EffectivePlanItemContent $WithoutLf 'without.txt') 'Effective terminal-LF content did not append LF.'
    AssertEqual "generated trailing  `n" (Get-EffectivePlanItemContent $WithLf 'with.txt') 'Effective terminal-LF content appended an extra LF.'
  }
  Scenario 'terminal LF write mode appends terminal LF' {
    $Root = New-TempDir 'terminal-write'; $TempRoots.Add($Root)
    $Path = Join-Path $Root 'generated.txt'
    $Item = [ordered]@{ Content = 'generated trailing  '; WriteMode = $WriteModeCanonicalWithTerminalLf }
    Write-PlanItemText $Path $Item 'generated.txt'
    AssertEqual "generated trailing  `n" ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)) 'Generated terminal-LF policy changed.'
  }
  Scenario 'template plan carries terminal LF write mode' {
    $Plan = Get-TemplatePlan $InstallerRoot 'generic' @{}
    Assert ($Plan.Count -gt 0) 'Template plan was empty.'
    foreach ($Item in $Plan.Values) {
      AssertEqual $WriteModeCanonicalWithTerminalLf $Item.WriteMode "Template plan write mode changed for $($Item.RelativePath)."
    }
  }
  Scenario 'transaction uses plan item write modes' {
    $Root = New-TempDir 'transaction-write-modes'; $TempRoots.Add($Root)
    $Plan = @{
      'exact.txt' = [ordered]@{ RelativePath = 'exact.txt'; Content = 'exact trailing  '; Kind = 'merge'; WriteMode = $WriteModeCanonicalExact }
      'generated.txt' = [ordered]@{ RelativePath = 'generated.txt'; Content = 'generated'; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf }
    }
    Invoke-TransactionalWrite $Root $Plan
    AssertEqual 'exact trailing  ' ([IO.File]::ReadAllText((Join-Path $Root 'exact.txt'), [Text.Encoding]::UTF8)) 'Transaction did not carry exact write metadata.'
    AssertEqual "generated`n" ([IO.File]::ReadAllText((Join-Path $Root 'generated.txt'), [Text.Encoding]::UTF8)) 'Transaction did not carry terminal-LF write metadata.'
    $Journal = @(Get-ChildItem -LiteralPath (Join-Path $Root '.qbit-toolkit/codex-ai-tooling/transactions') -File -Recurse -Filter journal.json)
    AssertEqual 1 $Journal.Count 'Committed transaction journal count changed.'
    AssertEqual 'committed' ((Read-TextFile $Journal[0].FullName | ConvertFrom-Json).status) 'Successful transaction journal remained active.'
  }
  Scenario 'state hash equals actual effective written file hash' {
    $Root = New-TempDir 'effective-state-hash'; $TempRoots.Add($Root)
    $Raw = 'generated-without-final-lf'
    $Plan = @{ 'generated.txt' = [ordered]@{ RelativePath = 'generated.txt'; Content = $Raw; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf } }
    Invoke-TransactionalWrite $Root $Plan
    $State = New-StateContent $Plan @{} $null 'generic' 'demo' 'Demo' @('http://localhost:3000') 'demo-image' | ConvertFrom-Json
    $ActualHash = Get-FileSha256 (Join-Path $Root 'generated.txt')
    AssertEqual $ActualHash $State.managedFiles.'generated.txt' 'State hash did not match actual written bytes.'
    Assert ($ActualHash -ne (Get-TextSha256 $Raw)) 'State hash incorrectly matched untransformed raw content.'
  }
  Scenario 'effective content comparison treats terminal LF output as current' {
    $Root = New-TempDir 'effective-comparison'; $TempRoots.Add($Root)
    $Path = Join-Path $Root 'generated.txt'
    [IO.File]::WriteAllText($Path, "generated`n", [Text.UTF8Encoding]::new($false))
    $Item = [ordered]@{ Content = 'generated'; WriteMode = $WriteModeCanonicalWithTerminalLf }
    Assert (Test-PlanItemContentMatchesFile $Path $Item 'generated.txt') 'Comparison treated effective terminal-LF content as an update.'
  }
  Scenario 'whole-file byte comparison rejects canonical-equivalent CRLF and BOM' {
    $Root = New-TempDir 'byte-comparison'; $TempRoots.Add($Root)
    $Item = [ordered]@{ Content = "alpha`nbeta`n"; WriteMode = $WriteModeCanonicalWithTerminalLf }
    foreach ($Case in @(
      @{ Name='crlf'; Text="alpha`r`nbeta`r`n"; Bom=$false },
      @{ Name='bom'; Text="alpha`nbeta`n"; Bom=$true },
      @{ Name='bom-crlf'; Text="alpha`r`nbeta`r`n"; Bom=$true }
    )) {
      $Path=Join-Path $Root ($Case.Name+'.txt'); [IO.File]::WriteAllText($Path,$Case.Text,[Text.UTF8Encoding]::new($Case.Bom))
      Assert (-not (Test-PlanItemContentMatchesFile $Path $Item $Case.Name)) "Byte comparison accepted $($Case.Name)."
      Assert (Test-PlanItemLogicalTextMatchesFile $Path $Item $Case.Name) "Logical comparison rejected $($Case.Name)."
    }
  }
  Scenario 'effective plan item hash equals exact UTF8 no BOM bytes' {
    $Item=[ordered]@{ Content="alpha`r`n"; WriteMode=$WriteModeCanonicalWithTerminalLf }
    AssertEqual (Get-TextSha256 "alpha`n") (Get-EffectivePlanItemSha256 $Item 'alpha.txt') 'Effective byte hash changed.'
  }
  Scenario 'JSON string content escaping handles quotes and backslashes' {
    AssertEqual 'Qbit \"CLI\" \\ Tooling' (ConvertTo-JsonStringContent 'Qbit "CLI" \ Tooling') 'JSON string-content escaping changed.'
  }
  Scenario 'project display name rejects control characters' {
    AssertThrows { Test-ProjectDisplayName "bad`tname" } 'Control-character display name was accepted.'
  }
  Scenario 'expected profile manifest is exact and deterministic' {
    $TypeScript=@(Get-ExpectedManagedPaths $InstallerRoot 'typescript'); $Again=@(Get-ExpectedManagedPaths $InstallerRoot 'typescript'); $Rust=@(Get-ExpectedManagedPaths $InstallerRoot 'rust')
    AssertEqual ($TypeScript -join "`n") ($Again -join "`n") 'Expected manifest was not deterministic.'
    Assert ($TypeScript -contains '.ai/tooling/language-servers/package.json') 'TypeScript expected manifest omitted language server.'
    Assert ($Rust -contains '.ai/tooling/language-servers/package.json') 'Rust profile omitted the shared Bash/Python language-server payload.'
    Assert ($TypeScript.Count -eq @($TypeScript | Select-Object -Unique).Count) 'Expected manifest contains duplicates.'
  }
  Scenario 'manifest comparison is ordinal and case-sensitive' {
    AssertThrows { Assert-ExactStringSet @('Path/File.txt') @('path/File.txt') 'fixture' } 'Wrong-cased manifest path was accepted.'
    Assert-ExactStringSet @('Path/File.txt') @('Path/File.txt') 'fixture'
  }
  Scenario 'template profile exact override is accepted once' {
    $Root=New-TempDir 'template-override'; $TempRoots.Add($Root)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'templates/common'),(Join-Path $Root 'templates/profiles/generic') | Out-Null
    Set-Content -LiteralPath (Join-Path $Root 'templates/common/shared.txt') -Value common -NoNewline
    $ProfileSource=Join-Path $Root 'templates/profiles/generic/shared.txt'; Set-Content -LiteralPath $ProfileSource -Value profile -NoNewline
    $Map=Get-TemplateSourceMap $Root generic
    AssertEqual 1 $Map.Count 'Exact common/profile override duplicated manifest destination.'
    AssertEqual $ProfileSource $Map['shared.txt'] 'Profile did not override common source.'
  }
  Scenario 'template duplicate destination in one root is rejected' {
    $Root=New-TempDir 'template-duplicate'; $TempRoots.Add($Root)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'templates/common'),(Join-Path $Root 'templates/profiles/generic') | Out-Null
    Set-Content -LiteralPath (Join-Path $Root 'templates/common/item') -Value one -NoNewline
    Set-Content -LiteralPath (Join-Path $Root 'templates/common/item.tpl') -Value two -NoNewline
    AssertThrows { Get-TemplateSourceMap $Root generic } 'Duplicate destination in one template root was accepted.'
  }
  Scenario 'template case-fold collision is rejected' {
    $Root=New-TempDir 'template-case-fold'; $TempRoots.Add($Root)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'templates/common'),(Join-Path $Root 'templates/profiles/generic') | Out-Null
    Set-Content -LiteralPath (Join-Path $Root 'templates/common/Case.txt') -Value one -NoNewline
    Set-Content -LiteralPath (Join-Path $Root 'templates/profiles/generic/case.txt') -Value two -NoNewline
    AssertThrows { Get-TemplateSourceMap $Root generic } 'Case-fold template collision was accepted.'
  }
  Scenario 'portable managed path grammar rejects non-ASCII template destination' {
    Assert (Test-SafeStateRelativePath 'ascii/Nested_file-1.txt') 'Valid portable managed path was rejected.'
    Assert (-not (Test-SafeStateRelativePath 'ascii/café.txt')) 'Non-ASCII managed path was accepted.'
    $Root=New-TempDir 'template-non-ascii'; $TempRoots.Add($Root)
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'templates/common'),(Join-Path $Root 'templates/profiles/generic') | Out-Null
    Set-Content -LiteralPath (Join-Path $Root 'templates/common/café.txt') -Value invalid -NoNewline
    AssertThrows { Get-TemplateSourceMap $Root generic } 'Non-ASCII template destination was accepted.'
  }
  Scenario 'transaction rejects unknown write mode before mutation' {
    $Root = New-TempDir 'transaction-invalid-write-mode'; $TempRoots.Add($Root)
    $Plan = @{
      'a-valid.txt' = [ordered]@{ RelativePath = 'a-valid.txt'; Content = 'valid'; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf }
      'z-invalid.txt' = [ordered]@{ RelativePath = 'z-invalid.txt'; Content = 'invalid'; Kind = 'file'; WriteMode = 'unknown' }
    }
    AssertThrows { Invoke-TransactionalWrite $Root $Plan } 'Unknown write mode was accepted.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $Root 'a-valid.txt'))) 'Transaction mutated the target before rejecting an unknown write mode.'
  }
  Scenario 'managed block removal preserves exact prefix suffix' {
    $Block = Get-ManagedBlockText "body`n" $BeginMarker $EndMarker
    $Existing = "prefix trailing  `n`n$Block`nsuffix trailing  `n`n`n"
    $Record = New-ManagedBlockRecord $Block $false 0
    $Removed = Remove-ManagedBlockFromText $Existing ([pscustomobject]$Record) $BeginMarker $EndMarker 'file'
    AssertEqual "prefix trailing  `n`n`nsuffix trailing  `n`n`n" $Removed 'Removal did not preserve exact prefix/suffix.'
  }
  Scenario 'managed block removal removes recorded inserted separator' {
    $Update = Resolve-ManagedBlockUpdate 'prefix' $true "body`n" $BeginMarker $EndMarker $null 'file'
    $Removed = Remove-ManagedBlockFromText $Update.Content ([pscustomobject]$Update.Record) $BeginMarker $EndMarker 'file'
    AssertEqual 'prefix' $Removed 'Recorded separator was not removed exactly.'
  }
  Scenario 'agents managed block inserts and preserves prefix suffix' {
    $Existing = "# Repo`n`nBuild with project commands.`n"
    $Result = Merge-ManagedBlock $Existing 'AI tooling only.' $AgentsBeginMarker $AgentsEndMarker
    Assert ($Result -match '# Repo' -and $Result -match 'Build with project commands' -and $Result -match [regex]::Escape($AgentsBeginMarker) -and $Result -match 'AI tooling only') 'AGENTS managed block insertion failed.'
  }
  Scenario 'agents managed block rejects unowned existing markers' {
    $Existing = "# Repo`n$AgentsBeginMarker`nold`n$AgentsEndMarker`nKeep this.`n"
    AssertThrows { Merge-ManagedBlock $Existing 'new' $AgentsBeginMarker $AgentsEndMarker } 'Unowned AGENTS block was replaced.'
  }
  Scenario 'owned modified block requires replace policy' {
    $Existing = "prefix`n$BeginMarker`nmodified`n$EndMarker`nsuffix`n"
    $Previous = New-ManagedBlockRecord (Get-ManagedBlockText "original`n" $BeginMarker $EndMarker) $false 0
    AssertThrows { Resolve-ManagedBlockUpdate $Existing $true "desired`n" $BeginMarker $EndMarker ([pscustomobject]$Previous) 'file' 'fail' } 'Default policy accepted a modified owned block.'
    $Result = Resolve-ManagedBlockUpdate $Existing $true "desired`n" $BeginMarker $EndMarker ([pscustomobject]$Previous) 'file' 'replace'
    AssertEqual "prefix`n$BeginMarker`ndesired`n$EndMarker`nsuffix`n" $Result.Content 'Replace policy changed content outside the owned block.'
  }
  Scenario 'agents managed block rejects duplicate markers' {
    $Existing = "$AgentsBeginMarker`na`n$AgentsEndMarker`n$AgentsBeginMarker`nb`n$AgentsEndMarker`n"
    AssertThrows { Merge-ManagedBlock $Existing 'body' $AgentsBeginMarker $AgentsEndMarker } 'Duplicate AGENTS markers accepted.'
  }
  Scenario 'agents managed block rejects unbalanced markers' {
    $Existing = "$AgentsBeginMarker`na`n"
    AssertThrows { Merge-ManagedBlock $Existing 'body' $AgentsBeginMarker $AgentsEndMarker } 'Unbalanced AGENTS markers accepted.'
  }
  Scenario 'template rendering replaces known placeholders only' {
    $NamePlaceholder = '{{' + 'NAME' + '}}'
    $OtherPlaceholder = '{{' + 'OTHER' + '}}'
    $Rendered = Render-Template "Hello $NamePlaceholder $OtherPlaceholder" @{ NAME = 'Qbit' }
    AssertEqual "Hello Qbit $OtherPlaceholder" $Rendered 'Template rendering failed.'
  }
  Scenario 'relative path helper rejects traversal' {
    $Root = New-TempDir 'path'; $TempRoots.Add($Root)
    AssertThrows { Join-UnderRoot $Root '../escape.txt' } 'Traversal path accepted.'
  }
  Scenario 'relative path helper rejects absolute path' {
    $Root = New-TempDir 'absolute'; $TempRoots.Add($Root)
    AssertThrows { Join-UnderRoot $Root ([System.IO.Path]::GetFullPath($Root)) } 'Absolute path accepted.'
  }
  Scenario 'relative path helper accepts safe nested path' {
    $Root = New-TempDir 'safe'; $TempRoots.Add($Root)
    $Full = Join-UnderRoot $Root 'a/b.txt'
    Assert ($Full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) 'Safe path did not stay under root.'
  }
  Scenario 'text SHA-256 is deterministic' {
    AssertEqual (Get-TextSha256 'abc') (Get-TextSha256 'abc') 'Text hash was not deterministic.'
    Assert ((Get-TextSha256 'abc') -ne (Get-TextSha256 'abcd')) 'Different text produced same hash.'
  }
  Scenario 'empty portable manifest collections serialize as JSON arrays' {
    $Json = New-PortableOwnershipManifest ([ordered]@{}) ([ordered]@{}) 'generic' 'portable-empty'
    $Manifest = $Json | ConvertFrom-Json
    foreach ($Property in @('installed_entries','managed_blocks','original_state_records')) {
      Assert ($Manifest.PSObject.Properties.Name -ccontains $Property) "Portable manifest lacks $Property."
      Assert ($Json -match ('"' + $Property + '"\s*:\s*\[')) "Portable manifest $Property was not serialized as a JSON array."
      AssertEqual 0 (@($Manifest.$Property).Count) "Portable manifest $Property was not empty."
    }
    AssertEqual "backups`nlock.json`nrecovery`ntransactions" (@($Manifest.generated_state_entries) -join "`n") 'Generated state entries changed.'
    AssertEqual 'generic' $Manifest.profile 'Portable manifest profile changed.'
    AssertEqual 'portable-empty' $Manifest.target_identity 'Portable manifest target identity changed.'
    Assert ([string]$Manifest.payload_manifest_sha256 -cmatch '^[0-9a-f]{64}$') 'Portable manifest payload digest is not lowercase SHA-256.'
  }
  Scenario 'populated portable manifest collections preserve shape and classification' {
    $Plan = [ordered]@{
      'docs/owned.txt' = [ordered]@{ RelativePath = 'docs/owned.txt'; Content = 'owned content'; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf }
      'docs/observed.txt' = [ordered]@{ RelativePath = 'docs/observed.txt'; Content = 'observed content'; Kind = 'observed'; WriteMode = $WriteModeCanonicalWithTerminalLf }
    }
    $BlockRecord = New-ManagedBlockRecord (Get-ManagedBlockText "portable block`n" $AgentsBeginMarker $AgentsEndMarker) $false 1
    $BlockRecords = [ordered]@{ 'AGENTS.md' = $BlockRecord }
    $Json = New-PortableOwnershipManifest $Plan $BlockRecords 'generic' 'portable-populated'
    $Manifest = $Json | ConvertFrom-Json
    foreach ($Property in @('installed_entries','managed_blocks','original_state_records')) {
      Assert ($Json -match ('"' + $Property + '"\s*:\s*\[')) "Portable manifest $Property was serialized as a scalar object."
    }
    AssertEqual 1 (@($Manifest.installed_entries).Count) 'Installer-owned entry count changed.'
    AssertEqual 'docs/owned.txt' $Manifest.installed_entries[0].relative_path 'Installer-owned path was misclassified.'
    AssertEqual 1 (@($Manifest.original_state_records).Count) 'Observed original-record count changed.'
    AssertEqual 'docs/observed.txt' $Manifest.original_state_records[0].relative_path 'Observed path was misclassified.'
    AssertEqual 'observed-identical-unowned' $Manifest.original_state_records[0].ownership_type 'Observed ownership classification changed.'
    AssertEqual 1 (@($Manifest.managed_blocks).Count) 'Managed-block count changed.'
    AssertEqual 'AGENTS.md' $Manifest.managed_blocks[0].relative_path 'Managed block path changed.'
    AssertEqual ([string]$BlockRecord.sha256) $Manifest.managed_blocks[0].sha256 'Managed block hash changed.'
    Assert (@($Manifest.installed_entries | Where-Object relative_path -CEQ 'docs/observed.txt').Count -eq 0) 'Observed path appeared in installed entries.'
    Assert (@($Manifest.original_state_records | Where-Object relative_path -CEQ 'docs/owned.txt').Count -eq 0) 'Installer-owned path appeared in original state records.'
    $DigestLines = [Text.StringBuilder]::new()
    foreach ($RelativePath in (Sort-QbitPaths @($Plan.Keys))) {
      $null = $DigestLines.Append($RelativePath).Append("`t").Append((Get-EffectivePlanItemSha256 $Plan[$RelativePath] $RelativePath)).Append("`n")
    }
    foreach ($RelativePath in (Sort-QbitPaths @($BlockRecords.Keys))) {
      $null = $DigestLines.Append($RelativePath).Append("`t").Append([string]$BlockRecords[$RelativePath].sha256).Append("`n")
    }
    AssertEqual (Get-TextSha256 $DigestLines.ToString()) $Manifest.payload_manifest_sha256 'Portable manifest payload digest changed.'
  }
  Scenario 'valid UTC state timestamp remains an exact string' {
    $Path = New-StateTimestampFixture 'state-valid-timestamp' '"2026-07-25T12:34:56Z"'
    $State = Read-ValidatedInstallerState $Path
    Assert ($State.installedAtUtc.GetType() -eq [string]) 'Valid installedAtUtc was converted to a non-string runtime type.'
    AssertEqual '2026-07-25T12:34:56Z' $State.installedAtUtc 'Valid installedAtUtc text changed.'
    $Required = @('schemaVersion','installerId','installerVersion','toolkitSchemaVersion','profile','projectSlug','projectDisplayName','allowedOrigins','dockerImageName','installedAtUtc','installedRelativePaths','managedFiles','managedBlocks','stateFile')
    AssertEqual ($Required -join "`n") (@($State.PSObject.Properties.Name) -join "`n") 'Validated state properties changed.'
  }
  Scenario 'one-element allowedOrigins JSON array is preserved and accepted' {
    $Path = New-StateTimestampFixture 'state-one-origin' '"2026-07-25T12:34:56Z"' '1' '["http://localhost:3000"]'
    $State = Read-ValidatedInstallerState $Path
    Assert ($State.allowedOrigins -is [System.Array]) 'One-element allowedOrigins lost array identity.'
    AssertEqual 1 $State.allowedOrigins.Count 'One-element allowedOrigins count changed.'
    AssertEqual 'http://localhost:3000' $State.allowedOrigins[0] 'One-element allowedOrigins value changed.'
  }
  Scenario 'multi-element allowedOrigins JSON array remains accepted' {
    $Path = New-StateTimestampFixture 'state-multiple-origins' '"2026-07-25T12:34:56Z"'
    $State = Read-ValidatedInstallerState $Path
    Assert ($State.allowedOrigins -is [System.Array]) 'Multi-element allowedOrigins lost array identity.'
    AssertEqual 2 $State.allowedOrigins.Count 'Multi-element allowedOrigins count changed.'
  }
  Scenario 'scalar empty and null allowedOrigins remain rejected' {
    foreach ($Case in @(
      @{ Name='scalar'; Token='"http://localhost:3000"' },
      @{ Name='empty'; Token='[]' },
      @{ Name='null'; Token='null' }
    )) {
      $Path = New-StateTimestampFixture "state-origins-$($Case.Name)" '"2026-07-25T12:34:56Z"' '1' $Case.Token
      AssertThrows { Read-ValidatedInstallerState $Path } "Invalid allowedOrigins was accepted: $($Case.Name)."
    }
  }
  Scenario 'valid installedRelativePaths JSON array preserves array identity' {
    $Path = New-StateTimestampFixture 'state-installed-paths-array' '"2026-07-25T12:34:56Z"'
    $State = Read-ValidatedInstallerState $Path
    Assert ($State.installedRelativePaths -is [System.Array]) 'installedRelativePaths lost array identity.'
    AssertEqual 4 $State.installedRelativePaths.Count 'Valid installedRelativePaths count changed.'
  }
  Scenario 'one-element installedRelativePaths preserves array identity before exact-set rejection' {
    $Path = New-StateTimestampFixture 'state-one-installed-path' '"2026-07-25T12:34:56Z"' '1' '["http://localhost:3000"]' '[".qbit/toolkit/installed/codex-ai-tooling.json"]'
    $Message = $null
    try { Read-ValidatedInstallerState $Path | Out-Null } catch { $Message = $_.Exception.Message }
    Assert ($null -ne $Message) 'Structurally incomplete one-element installedRelativePaths state was accepted.'
    Assert (-not $Message.Contains('installedRelativePaths must be an array.')) 'One-element installedRelativePaths lost array identity.'
    Assert ($Message.Contains('installedRelativePaths does not match the expected profile manifest.')) 'One-element installedRelativePaths did not reach exact ownership-set validation.'
  }
  Scenario 'non-string state timestamp tokens remain rejected' {
    foreach ($Case in @(
      @{ Name = 'number'; Token = '123' },
      @{ Name = 'boolean'; Token = 'true' },
      @{ Name = 'null'; Token = 'null' }
    )) {
      $Path = New-StateTimestampFixture "state-timestamp-$($Case.Name)" $Case.Token
      AssertThrows { Read-ValidatedInstallerState $Path } "Non-string installedAtUtc token was accepted: $($Case.Name)."
    }
  }
  Scenario 'invalid string state timestamps remain rejected' {
    foreach ($Timestamp in @(
      '2026-02-30T00:00:00Z',
      '2026-07-25T12:34:56.789Z',
      '2026-07-25T16:04:56+03:30'
    )) {
      $Token = $Timestamp | ConvertTo-Json -Compress
      $Path = New-StateTimestampFixture ('state-invalid-timestamp-' + [guid]::NewGuid().ToString('n')) $Token
      AssertThrows { Read-ValidatedInstallerState $Path } "Invalid installedAtUtc string was accepted: $Timestamp."
    }
  }
  Scenario 'runtime-native Int32 or Int64 separator values 0 1 2 are accepted by the validator' {
    foreach ($Expected in @(0,1,2)) {
      $Path = New-StateTimestampFixture "state-valid-separator-$Expected" '"2026-07-25T12:34:56Z"' ([string]$Expected)
      $State = Read-ValidatedInstallerState $Path
      foreach ($Property in $State.managedBlocks.PSObject.Properties) {
        Assert (($Property.Value.insertedSeparatorLfCount -is [System.Int32]) -or ($Property.Value.insertedSeparatorLfCount -is [System.Int64])) "Separator count $Expected was not Int32 or Int64."
        AssertEqual $Expected $Property.Value.insertedSeparatorLfCount "Separator count $Expected changed."
      }
    }
  }
  Scenario 'invalid separator token types and values remain rejected' {
    foreach ($Case in @(
      @{ Name='string'; Token='"1"' },
      @{ Name='boolean'; Token='true' },
      @{ Name='null'; Token='null' },
      @{ Name='decimal-or-double-integral'; Token='1.0' },
      @{ Name='decimal-or-double-fractional'; Token='1.5' },
      @{ Name='negative'; Token='-1' },
      @{ Name='too-large'; Token='3' },
      @{ Name='outside-int32'; Token='2147483648' },
      @{ Name='other-large-numeric-type'; Token='79228162514264337593543950335' }
    )) {
      $Path = New-StateTimestampFixture "state-invalid-separator-$($Case.Name)" '"2026-07-25T12:34:56Z"' $Case.Token
      AssertThrows { Read-ValidatedInstallerState $Path } "Invalid separator token was accepted: $($Case.Name)."
    }
  }
  Scenario 'state and canonical timestamps are culture invariant' {
    Invoke-WithPersianCulture {
      $Before = [datetime]::UtcNow.AddSeconds(-2)
      $Json = New-StateContent ([ordered]@{}) ([ordered]@{}) $null 'generic' 'culture-test' 'Culture Test' @('http://localhost:3000') 'culture-test-image'
      $After = [datetime]::UtcNow.AddSeconds(2)
      Assert ($Json -match '"installedAtUtc"\s*:\s*"([^"]+)"') 'State timestamp was not a JSON string.'
      $InstalledAt = $Matches[1]
      Assert ($InstalledAt -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') 'State timestamp format changed.'
      $Parsed = [datetime]::MinValue
      Assert ([datetime]::TryParseExact($InstalledAt,'yyyy-MM-ddTHH:mm:ssZ',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$Parsed)) 'State timestamp is not invariant-parseable.'
      $ParsedUtc = $Parsed.ToUniversalTime()
      Assert ($ParsedUtc -ge $Before -and $ParsedUtc -le $After) 'State timestamp is outside the current UTC interval.'
      AssertEqual ([datetime]::UtcNow.Year.ToString([Globalization.CultureInfo]::InvariantCulture)) $InstalledAt.Substring(0,4) 'State timestamp used a non-Gregorian year.'
      $Value = [datetime]::new(2026,7,25,12,34,56,[DateTimeKind]::Utc)
      AssertEqual '"2026-07-25T12:34:56Z"' (ConvertTo-QbitCanonicalJson $Value) 'Canonical DateTime serialization used the current calendar.'
    }
  }
  Scenario 'state and manifest JSON use canonical two-space indentation' {
    $StateJson = New-StateContent ([ordered]@{}) ([ordered]@{}) $null 'generic' 'indent-test' 'Indent Test' @('http://localhost:3000') 'indent-test-image'
    $ManifestJson = New-PortableOwnershipManifest ([ordered]@{}) ([ordered]@{}) 'generic' 'indent-test'
    foreach ($Json in @($StateJson,$ManifestJson)) {
      Assert (-not $Json.Contains("`r")) 'Canonical JSON contains CR line endings.'
      Assert ($Json -cmatch '^\{\n  "') 'Canonical JSON does not use two-space top-level indentation.'
      Assert ($Json.EndsWith("`n", [StringComparison]::Ordinal)) 'Canonical JSON lacks one terminal LF.'
    }
  }
  Scenario 'transaction and recovery identifiers are culture invariant' {
    $Root = New-TempDir 'culture-transaction'; $TempRoots.Add($Root)
    $OriginalFailAfter = $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES
    $OriginalFailRollback = $env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK
    try {
      Invoke-WithPersianCulture {
        Write-ExactTextFile (Join-Path $Root 'owned.txt') 'before'
        $Plan = [ordered]@{ 'owned.txt' = [ordered]@{ RelativePath='owned.txt'; Content='after'; Kind='file'; WriteMode=$WriteModeCanonicalExact } }
        $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES = '1'
        $env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK = '1'
        AssertThrows { Invoke-TransactionalWrite $Root $Plan } 'Injected transaction failure did not retain recovery evidence.'
        $RuntimeRoot = Join-Path $Root '.qbit-toolkit/codex-ai-tooling'
        $Transaction = @(Get-ChildItem -LiteralPath (Join-Path $RuntimeRoot 'transactions') -Directory)
        AssertEqual 1 $Transaction.Count 'Transaction evidence count changed.'
        $GregorianYear = [datetime]::UtcNow.Year.ToString('0000',[Globalization.CultureInfo]::InvariantCulture)
        Assert ($Transaction[0].Name -cmatch "^${GregorianYear}\d{4}T\d{9}Z-$PID$") 'Transaction identifier is not invariant Gregorian format.'
        $Backup = @(Get-ChildItem -LiteralPath (Join-Path $RuntimeRoot 'backups') -Directory)
        AssertEqual $Transaction[0].Name $Backup[0].Name 'Backup identifier differs from transaction identifier.'
        $LockPath = Join-Path $RuntimeRoot 'lock.json'
        $LockRaw = Read-TextFile $LockPath
        Assert ($LockRaw -match '"start_time"\s*:\s*"([^\"]+)"') 'Lock start_time is not a JSON string.'
        Assert ($Matches[1] -cmatch "^${GregorianYear}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$") 'Lock start_time is not invariant Gregorian format.'
        $Lock = $LockRaw | ConvertFrom-Json
        $Lock.process_id = [int]::MaxValue
        Write-ExactTextFile $LockPath (($Lock | ConvertTo-Json) + "`n")
        Remove-Item Env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES -ErrorAction SilentlyContinue
        Remove-Item Env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK -ErrorAction SilentlyContinue
        Invoke-PendingTransactionRecovery $Root
        $RecoveredLock = @(Get-ChildItem -LiteralPath (Join-Path $RuntimeRoot 'recovery') -File -Filter 'stale-lock-*.json')
        AssertEqual 1 $RecoveredLock.Count 'Stale lock recovery evidence count changed.'
        Assert ($RecoveredLock[0].Name -cmatch "^stale-lock-${GregorianYear}\d{4}T\d{9}Z-$PID\.json$") 'Stale lock identifier is not invariant Gregorian format.'
      }
    } finally {
      if ($null -eq $OriginalFailAfter) { Remove-Item Env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES -ErrorAction SilentlyContinue } else { $env:QBIT_TOOLKIT_TEST_FAIL_AFTER_WRITES = $OriginalFailAfter }
      if ($null -eq $OriginalFailRollback) { Remove-Item Env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK -ErrorAction SilentlyContinue } else { $env:QBIT_TOOLKIT_TEST_FAIL_ROLLBACK = $OriginalFailRollback }
    }
  }
  Scenario 'state semantic comparison ignores JSON whitespace' {
    $PrettyJson = @'
{
  "a": 1,
  "b": [2]
}
'@
    Assert (Test-StateContentEquivalent '{"a":1,"b":[2]}' $PrettyJson) 'Equivalent JSON states did not match.'
  }
  Scenario 'state semantic comparison detects changed content' {
    Assert (-not (Test-StateContentEquivalent '{"a":1}' '{"a":2}')) 'Different JSON states matched.'
  }
  Scenario 'state semantic comparison rejects invalid JSON' {
    Assert (-not (Test-StateContentEquivalent 'not-json' '{"a":1}')) 'Invalid JSON state matched.'
  }
  Scenario 'state separates managed files and managed blocks' {
    $Plan = @{
      'AGENTS.md' = [ordered]@{ RelativePath = 'AGENTS.md'; Content = 'merged'; Kind = 'merge'; WriteMode = $WriteModeCanonicalExact }
      'docs/file.md' = [ordered]@{ RelativePath = 'docs/file.md'; Content = 'owned'; Kind = 'file'; WriteMode = $WriteModeCanonicalWithTerminalLf }
    }
    $BlockRecord = New-ManagedBlockRecord (Get-ManagedBlockText "body`n" $AgentsBeginMarker $AgentsEndMarker) $false 1
    $State = New-StateContent $Plan @{ 'AGENTS.md' = $BlockRecord } $null 'rust' 'demo' 'Demo' @('http://localhost:3000') 'demo-ai-tooling:serena-1.5.3-graphify-0.9.12' | ConvertFrom-Json
    Assert (-not ($State.managedFiles.PSObject.Properties.Name -contains 'AGENTS.md')) 'AGENTS.md was recorded as whole-file managed.'
    Assert ($State.managedBlocks.PSObject.Properties.Name -contains 'AGENTS.md') 'AGENTS.md was not recorded as managed block.'
    Assert ($State.managedBlocks.'AGENTS.md'.PSObject.Properties.Name -contains 'insertedSeparatorLfCount') 'Managed block metadata was not structured.'
  }
} finally {
  foreach ($Root in $TempRoots) { Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "RESULT passed=$Script:Passed failed=$Script:Failed skipped=$Script:Skipped"
if ($Script:Failed -gt 0) { exit 1 }
