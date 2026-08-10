[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:Passed = 0
$Script:Failed = 0
$Script:Skipped = 0
$InstallerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Install = Join-Path $InstallerRoot 'install.ps1'
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('qbit-docker-e2e-' + [System.Guid]::NewGuid().ToString('n'))

function Finish {
  Write-Host "RESULT passed=$Script:Passed failed=$Script:Failed skipped=$Script:Skipped"
  if ($Script:Failed -gt 0) { exit 1 }
}
function Assert([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}
function Get-FileSha256OrMissing([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return '<missing>' }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function New-Repo([string]$Name) {
  $Path = Join-Path $TempRoot $Name
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  git -C $Path init -q
  return $Path
}
function Invoke-ComposeRun([string]$Repo, [string[]]$Arguments) {
  & docker compose --env-file (Join-Path $Repo '.ai/tooling/versions.env') -f (Join-Path $Repo '.ai/tooling/compose.yaml') run --rm --no-deps ai-tooling @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Docker Compose command failed: $($Arguments -join ' ')" }
}
function Remove-DockerArtifacts([object]$State) {
  if (-not $State) { return }
  if ($State.dockerImageName) {
    docker image rm $State.dockerImageName 2>$null | Out-Null
  }
  $VolumePrefix = "$($State.projectSlug)-ai-tooling"
  docker volume ls --format '{{.Name}}' |
    Where-Object { $_ -like "$VolumePrefix*" } |
    ForEach-Object { docker volume rm $_ 2>$null | Out-Null }
}
function Scenario([string]$Name, [scriptblock]$Body) {
  $Script:ScenarioState = $null
  try {
    & $Body
    $Script:Passed++
    Write-Host "PASS $Name"
  } catch {
    $Script:Failed++
    Write-Host "FAIL $Name :: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    Remove-DockerArtifacts $Script:ScenarioState
  }
}
function Install-Profile([string]$Repo, [string]$Profile, [string]$Slug) {
  & $Install -Target $Repo -Profile $Profile -ProjectSlug $Slug -SkipBootstrap -SkipDoctor | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Installer failed for $Profile profile." }
  return (Get-Content (Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json') -Raw | ConvertFrom-Json)
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host 'SKIP Docker TypeScript runtime: docker command unavailable'
  Write-Host 'SKIP Docker Rust runtime: docker command unavailable'
  $Script:Skipped += 2
  Finish
}
& docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'SKIP Docker TypeScript runtime: Docker Compose unavailable'
  Write-Host 'SKIP Docker Rust runtime: Docker Compose unavailable'
  $Script:Skipped += 2
  Finish
}

New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
try {
  Scenario 'Docker TypeScript bootstrap and doctor' {
    $Repo = New-Repo 'typescript-runtime'
    Set-Content -LiteralPath (Join-Path $Repo 'tsconfig.json') -Value '{}' -NoNewline
    $State = Install-Profile $Repo 'typescript' 'qbit-docker-ts-e2e'
    $Script:ScenarioState = $State
    & (Join-Path $Repo '.ai/scripts/bootstrap.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'TypeScript bootstrap failed.' }
    & (Join-Path $Repo '.ai/scripts/doctor.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'TypeScript doctor failed.' }
    & docker image inspect $State.dockerImageName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Expected TypeScript Docker image was not built.' }
    Invoke-ComposeRun $Repo @('python', '-c', 'import importlib.metadata as m; assert m.version("serena-agent") == "1.5.3"; assert m.version("graphifyy") == "0.9.12"')
    Invoke-ComposeRun $Repo @('node', '--version')
  }

  Scenario 'Docker Rust bootstrap and doctor' {
    $Repo = New-Repo 'rust-runtime'
    Set-Content -LiteralPath (Join-Path $Repo 'Cargo.toml') -Value "[package]`nname = `"demo`"`nedition = `"2024`"`nrust-version = `"1.85`"`n" -NoNewline
    Set-Content -LiteralPath (Join-Path $Repo 'rust-toolchain.toml') -Value "[toolchain]`nchannel = `"1.85.0`"`n" -NoNewline
    $CargoHash = Get-FileSha256OrMissing (Join-Path $Repo 'Cargo.toml')
    $CargoLockHash = Get-FileSha256OrMissing (Join-Path $Repo 'Cargo.lock')
    $ToolchainHash = Get-FileSha256OrMissing (Join-Path $Repo 'rust-toolchain.toml')
    $State = Install-Profile $Repo 'rust' 'qbit-docker-rust-e2e'
    $Script:ScenarioState = $State
    & (Join-Path $Repo '.ai/scripts/bootstrap.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Rust bootstrap failed.' }
    & (Join-Path $Repo '.ai/scripts/doctor.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Rust doctor failed.' }
    & docker image inspect $State.dockerImageName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Expected Rust Docker image was not built.' }
    Invoke-ComposeRun $Repo @('python', '-c', 'import importlib.metadata as m; assert m.version("serena-agent") == "1.5.3"; assert m.version("graphifyy") == "0.9.12"')
    $RustVersion = (& docker compose --env-file (Join-Path $Repo '.ai/tooling/versions.env') -f (Join-Path $Repo '.ai/tooling/compose.yaml') run --rm --no-deps ai-tooling rustc --version)
    if ($LASTEXITCODE -ne 0 -or ($RustVersion -join "`n") -notmatch 'rustc 1\.85\.0') { throw 'Rust toolchain 1.85.0 was not available.' }
    Invoke-ComposeRun $Repo @('rust-analyzer', '--version')
    Assert ((Get-FileSha256OrMissing (Join-Path $Repo 'Cargo.toml')) -eq $CargoHash) 'Cargo.toml was modified.'
    Assert ((Get-FileSha256OrMissing (Join-Path $Repo 'Cargo.lock')) -eq $CargoLockHash) 'Cargo.lock was modified.'
    Assert ((Get-FileSha256OrMissing (Join-Path $Repo 'rust-toolchain.toml')) -eq $ToolchainHash) 'rust-toolchain.toml was modified.'
  }
} finally {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Finish
