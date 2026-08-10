[CmdletBinding()]
param(
  [ValidateSet('unit', 'integration', 'e2e', 'docker', 'all')] [string]$Layer = 'all'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Failures = 0
function Invoke-Checked([string]$Name, [scriptblock]$Command) {
  Write-Host "== $Name =="
  try {
    $global:LASTEXITCODE = 0
    & $Command
    if ((-not $?) -or $global:LASTEXITCODE -ne 0) { $script:Failures++ }
  } catch {
    $script:Failures++
    Write-Host "FAIL ${Name}: $($_.Exception.Message)" -ForegroundColor Red
  }
}
function Get-PythonCommand {
  $Py = Get-Command py -ErrorAction SilentlyContinue
  if ($Py) { return 'py' }
  $Python = Get-Command python -ErrorAction SilentlyContinue
  if ($Python) { return 'python' }
  throw 'Python is required for validator unit tests.'
}
function Get-PosixShell {
  $Sh = Get-Command sh -ErrorAction SilentlyContinue
  if ($Sh) { return $Sh.Source }
  $GitSh = Join-Path ${env:ProgramFiles} 'Git\bin\sh.exe'
  if (Test-Path -LiteralPath $GitSh) { return $GitSh }
  $GitShX86 = Join-Path ${env:ProgramFiles(x86)} 'Git\bin\sh.exe'
  if (Test-Path -LiteralPath $GitShX86) { return $GitShX86 }
  return $null
}
function Invoke-PythonUnit {
  $Python = Get-PythonCommand
  $PreviousNoByteCode = $env:PYTHONDONTWRITEBYTECODE
  $env:PYTHONDONTWRITEBYTECODE = '1'
  try {
    & $Python -B -m unittest tests.unit.test_validate -v
  } finally {
    $env:PYTHONDONTWRITEBYTECODE = $PreviousNoByteCode
  }
}
function Invoke-PosixIfAvailable([string]$Name, [string]$ScriptPath) {
  $Shell = Get-PosixShell
  if (-not $Shell) { Write-Host "SKIP ${Name}: no usable POSIX shell found (checked sh and Git for Windows sh)."; return }
  & $Shell $ScriptPath
  if ($LASTEXITCODE -ne 0) { $script:Failures++ }
}
if ($Layer -in @('unit', 'all')) {
  Invoke-Checked 'PowerShell unit' { & (Join-Path $Root 'installers/codex-ai-tooling/tests/unit/test-unit.ps1') }
  Invoke-Checked 'Python validator unit' { Invoke-PythonUnit }
  Write-Host '== POSIX unit =='
  Invoke-PosixIfAvailable 'POSIX unit' (Join-Path $Root 'installers/codex-ai-tooling/tests/unit/test-unit.sh')
}
if ($Layer -in @('integration', 'all')) {
  Invoke-Checked 'PowerShell integration' { & (Join-Path $Root 'installers/codex-ai-tooling/tests/integration/test-installer.ps1') }
  Write-Host '== POSIX integration =='
  Invoke-PosixIfAvailable 'POSIX integration' (Join-Path $Root 'installers/codex-ai-tooling/tests/integration/test-installer.sh')
}
if ($Layer -in @('e2e', 'all')) {
  Invoke-Checked 'PowerShell E2E' { & (Join-Path $Root 'installers/codex-ai-tooling/tests/e2e/test-e2e.ps1') }
  Write-Host '== POSIX E2E =='
  Invoke-PosixIfAvailable 'POSIX E2E' (Join-Path $Root 'installers/codex-ai-tooling/tests/e2e/test-e2e.sh')
}
if ($Layer -in @('docker', 'all')) {
  Invoke-Checked 'Docker-dependent E2E' { & (Join-Path $Root 'installers/codex-ai-tooling/tests/e2e/test-docker.ps1') }
}
if ($Failures -gt 0) { Write-Error "Test runner failed with $Failures failing layer command(s)."; exit 1 }
Write-Host 'All requested test layers completed.'
