[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Python = Get-Command py -ErrorAction SilentlyContinue
if ($Python) { & py (Join-Path $Root 'tools/validate.py') } else { & python (Join-Path $Root 'tools/validate.py') }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$Failures = 0
Get-ChildItem -Path $Root -Recurse -Filter *.ps1 -File | Where-Object { $_.FullName -notmatch '\\.git\\' } | ForEach-Object {
  $Errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$Errors) | Out-Null
  if ($Errors.Count -gt 0) {
    $Failures++
    Write-Error "PowerShell parse failed: $($_.FullName): $($Errors[0].Message)"
  }
}
$Sh = Get-Command sh -ErrorAction SilentlyContinue
$ShellPath = if ($Sh) { $Sh.Source } else { $null }
if (-not $ShellPath) {
  $GitSh = Join-Path ${env:ProgramFiles} 'Git\bin\sh.exe'
  if (Test-Path -LiteralPath $GitSh) { $ShellPath = $GitSh }
}
if (-not $ShellPath -and ${env:ProgramFiles(x86)}) {
  $GitShX86 = Join-Path ${env:ProgramFiles(x86)} 'Git\bin\sh.exe'
  if (Test-Path -LiteralPath $GitShX86) { $ShellPath = $GitShX86 }
}
if ($ShellPath) {
  Get-ChildItem -Path $Root -Recurse -Filter *.sh -File | Where-Object { $_.FullName -notmatch '\\.git\\' } | ForEach-Object {
    & $ShellPath -n $_.FullName
    if ($LASTEXITCODE -ne 0) { $Failures++ }
  }
} else {
  Write-Warning 'No usable POSIX shell found; POSIX shell syntax validation skipped.'
}
if ($Failures -gt 0) { exit 1 }
Write-Host 'PowerShell validation passed.'
