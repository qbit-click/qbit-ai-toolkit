[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Target,[ValidateSet('text','json')][string]$Format='text')
& (Join-Path $PSScriptRoot 'install.ps1') -Operation verify -Target $Target -Format $Format
exit $LASTEXITCODE
