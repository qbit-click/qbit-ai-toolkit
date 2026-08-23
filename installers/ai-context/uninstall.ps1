[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Target,
  [ValidateSet('fail','replace')][string]$OwnedModified='fail',
  [ValidateSet('text','json')][string]$Format='text'
)
& (Join-Path $PSScriptRoot 'install.ps1') -Operation uninstall -Target $Target -OwnedModified $OwnedModified -Format $Format
exit $LASTEXITCODE
