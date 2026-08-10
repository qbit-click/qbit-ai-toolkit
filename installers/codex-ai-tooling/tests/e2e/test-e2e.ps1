[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:Passed = 0
$Script:Failed = 0
$Script:Skipped = 0
$InstallerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Install = Join-Path $InstallerRoot 'install.ps1'
$Verify = Join-Path $InstallerRoot 'verify.ps1'
$Uninstall = Join-Path $InstallerRoot 'uninstall.ps1'
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qbit-e2e-' + [System.Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
function New-Repo([string]$Name) { $Path = Join-Path $TempRoot $Name; New-Item -ItemType Directory -Force -Path $Path | Out-Null; git -C $Path init -q; return $Path }
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function ReadText([string]$Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8).Replace("`r`n", "`n") }
function WriteText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false)) }
function Snapshot([string]$Path) { (Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' } | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($Path.Length).Replace('\','/') + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "`n" }
function RunInstall([string]$Repo, [switch]$Replace) { $Policy = if ($Replace) { 'replace' } else { 'fail' }; & $Install -Target $Repo -Profile auto -SkipBootstrap -SkipDoctor -OwnedModified $Policy; if ($LASTEXITCODE -ne 0) { throw 'Installer failed.' } }
function ExpectFailure([scriptblock]$Block, [string]$Message) { $Thrown = $false; try { & $Block } catch { $Thrown = $true }; if (-not $Thrown) { throw $Message } }
function Scenario([string]$Name, [scriptblock]$Body) { try { & $Body; $Script:Passed++; Write-Host "PASS $Name" } catch { $Script:Failed++; Write-Host "FAIL $Name :: $($_.Exception.Message)" -ForegroundColor Red } }
$ProjectAgents = @'
# Repository Guidelines

## Architecture

Project-owned Rust architecture guidance.

## Build Commands

- Build: `cargo build`

## Testing Rules

- Run unit and integration tests.

Trailing spaces stay here.  


'@
try {
  Scenario 'TypeScript lifecycle' {
    $Repo = New-Repo 'typescript-lifecycle'
    Set-Content -LiteralPath (Join-Path $Repo 'tsconfig.json') -Value '{}' -NoNewline
    Set-Content -LiteralPath (Join-Path $Repo 'UNRELATED.txt') -Value 'keep' -NoNewline
    RunInstall $Repo
    $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
    Assert ($State.profile -eq 'typescript') 'TypeScript profile was not selected.'
    & $Verify -Target $Repo
    $Before = Snapshot $Repo
    RunInstall $Repo
    Assert ($Before -eq (Snapshot $Repo)) 'Repeated install was not idempotent.'
    & $Uninstall -Target $Repo
    Assert (-not (Test-Path (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json'))) 'State file remained after uninstall.'
    Assert (Test-Path (Join-Path $Repo 'UNRELATED.txt')) 'Unrelated content was removed.'
  }
  Scenario 'Generic lifecycle' {
    $Repo = New-Repo 'generic-lifecycle'
    Set-Content -LiteralPath (Join-Path $Repo 'UNRELATED.txt') -Value 'keep' -NoNewline
    RunInstall $Repo
    $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
    Assert ($State.profile -eq 'generic') 'Generic profile was not selected.'
    & $Verify -Target $Repo
    Assert ((ReadText (Join-Path $Repo '.codex/config.toml')) -match 'enabled = false') 'Serena should be disabled for generic profile.'
    & $Uninstall -Target $Repo
    Assert (Test-Path (Join-Path $Repo 'UNRELATED.txt')) 'Unrelated content was removed.'
  }
  Scenario 'Rust lifecycle with existing AGENTS' {
    $Repo = New-Repo 'rust-lifecycle'
    WriteText (Join-Path $Repo 'Cargo.toml') "[package]`nname = `"demo`"`nedition = `"2024`"`nrust-version = `"1.85`"`n"
    WriteText (Join-Path $Repo 'rust-toolchain.toml') "[toolchain]`nchannel = `"1.85.0`"`n"
    WriteText (Join-Path $Repo 'AGENTS.md') $ProjectAgents
    New-Item -ItemType Directory -Force -Path (Join-Path $Repo 'src') | Out-Null
    WriteText (Join-Path $Repo 'src/main.rs') 'fn main() {}'
    New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.ai'), (Join-Path $Repo '.codex') | Out-Null
    WriteText (Join-Path $Repo '.ai/custom-project-file.txt') 'keep-ai'
    WriteText (Join-Path $Repo '.codex/custom-project-file.toml') 'keep-codex'
    RunInstall $Repo
    $State = Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json
    Assert ($State.profile -eq 'rust') 'Rust profile was not selected.'
    $Agents = ReadText (Join-Path $Repo 'AGENTS.md')
    Assert ($Agents.Contains($ProjectAgents.Replace("`r`n","`n"))) 'Original AGENTS content was not preserved.'
    Assert ((($Agents | Select-String '<!-- qbit-toolkit:codex-ai-tooling:start -->' -AllMatches).Matches.Count) -eq 1) 'AGENTS block count is not one.'
    & $Verify -Target $Repo
    $Before = Snapshot $Repo
    Start-Sleep -Seconds 1
    RunInstall $Repo
    Assert ($Before -eq (Snapshot $Repo)) 'Rust repeat install was not idempotent.'
    $EditedAgents = "## Local Notes`nProject-owned update.  `n`n" + (ReadText (Join-Path $Repo 'AGENTS.md'))
    WriteText (Join-Path $Repo 'AGENTS.md') $EditedAgents
    & $Verify -Target $Repo
    & $Uninstall -Target $Repo
    $RemainingAgents = ReadText (Join-Path $Repo 'AGENTS.md')
    Assert ($RemainingAgents -notmatch 'qbit-toolkit:codex-ai-tooling') 'AGENTS managed block remained after uninstall.'
    Assert ($RemainingAgents -eq ("## Local Notes`nProject-owned update.  `n`n" + $ProjectAgents)) 'Target-owned AGENTS content was not preserved exactly.'
    Assert (Test-Path (Join-Path $Repo 'src/main.rs')) 'Unrelated source file was removed.'
    Assert (Test-Path (Join-Path $Repo '.ai/custom-project-file.txt')) 'Project-owned .ai file was removed.'
    Assert (Test-Path (Join-Path $Repo '.codex/custom-project-file.toml')) 'Project-owned .codex file was removed.'
  }
  Scenario 'Replace policy preserves unowned conflict' {
    $Repo = New-Repo 'replace-unowned'
    Set-Content -LiteralPath (Join-Path $Repo 'UNRELATED.txt') -Value 'keep' -NoNewline
    New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.codex') | Out-Null
    Set-Content -LiteralPath (Join-Path $Repo '.codex/config.toml') -Value 'user-owned' -NoNewline
    ExpectFailure { RunInstall $Repo } 'Normal install did not fail on unmanaged conflict.'
    ExpectFailure { RunInstall $Repo -Replace } 'Replace policy overwrote an unmanaged conflict.'
    Assert ((Get-Content -LiteralPath (Join-Path $Repo '.codex/config.toml') -Raw).Trim() -eq 'user-owned') 'Unmanaged conflict was modified.'
    Assert (Test-Path (Join-Path $Repo 'UNRELATED.txt')) 'Unrelated content was removed.'
  }
} finally {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "RESULT passed=$Script:Passed failed=$Script:Failed skipped=$Script:Skipped"
if ($Script:Failed -gt 0) { exit 1 }
