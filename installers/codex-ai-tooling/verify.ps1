[CmdletBinding()]
param([Parameter(Mandatory = $true)] [string]$Target)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/installer.ps1')

$SerenaAllowlist = @('get_symbols_overview','find_symbol','find_referencing_symbols','find_implementations','find_declaration','get_diagnostics_for_file','get_diagnostics_for_symbol','replace_symbol_body','insert_after_symbol','insert_before_symbol','rename_symbol','safe_delete_symbol')
$Context7Allowlist = @('resolve-library-id','query-docs')
$SentryAllowlist = @('find_organizations','find_projects','get_sentry_resource','search_events','search_issues')
$Failures = 0
function Fail([string]$Message) { Write-Error $Message; $script:Failures++ }
function ExtractArray([string]$Text,[string]$Server){ $m=[regex]::Match($Text,"(?ms)\[mcp_servers\."+$Server+"\].*?enabled_tools\s*=\s*\[(.*?)\]"); if(-not $m.Success){return @()}; return @([regex]::Matches($m.Groups[1].Value,'"([^"]+)"') | ForEach-Object {$_.Groups[1].Value}) }
function SameSet([string[]]$A,[string[]]$B){ try { Assert-ExactStringSet $A $B 'tool allowlist'; return $true } catch { return $false } }
function Get-BlockMarkersForPath([string]$Rel){ if($Rel -ceq 'AGENTS.md'){ return @($AgentsBeginMarker,$AgentsEndMarker) }; return @($BeginMarker,$EndMarker) }

$Root = ConvertTo-CanonicalPath $Target
if(-not (Test-Path -LiteralPath $Root -PathType Container)){ throw "Target does not exist: $Target" }
$StateFile = Join-UnderRoot $Root $StatePath
if(-not (Test-Path -LiteralPath $StateFile -PathType Leaf)){ throw "Missing state file: $StatePath" }
try { $State = Read-ValidatedInstallerState $StateFile } catch { throw $_.Exception.Message }
Assert-PortableOwnershipState $Root $State
if($State.installerId -cne $InstallerId){ Fail 'State file installerId is invalid.' }
if($State.installerVersion -cne $InstallerVersion){ Fail 'State file installerVersion is invalid.' }
if(-not ($State.PSObject.Properties.Name -ccontains 'managedFiles')){ Fail 'State file missing managedFiles.' }
if(-not ($State.PSObject.Properties.Name -ccontains 'managedBlocks')){ Fail 'State file missing managedBlocks.' }

if($State.managedFiles -and $State.managedFiles.PSObject.Properties.Name -ccontains 'AGENTS.md'){ Fail 'AGENTS.md must be declared as managed-block ownership, not managed-file ownership.' }
foreach($Property in $State.managedFiles.PSObject.Properties){
  $Rel=$Property.Name
  try { Assert-SafeDestinationPath $Root $Rel; $Path=Join-UnderRoot $Root $Rel } catch { Fail $_.Exception.Message; continue }
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Fail "Missing managed file: $Rel"; continue }
  $Hash=Get-FileSha256 $Path
  if($Hash -ne [string]$Property.Value){ Fail "User-modified managed file: $Rel" }
}

if(-not ($State.managedBlocks.PSObject.Properties.Name -ccontains 'AGENTS.md')){ Fail 'AGENTS.md must be managed-block owned.' }
foreach($Property in $State.managedBlocks.PSObject.Properties){
  $Rel=$Property.Name
  try { Assert-SafeDestinationPath $Root $Rel; $Path=Join-UnderRoot $Root $Rel } catch { Fail $_.Exception.Message; continue }
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Fail "Missing managed-block file: $Rel"; continue }
  $Markers = Get-BlockMarkersForPath $Rel
  try {
    $Record = ConvertTo-ManagedBlockRecord $Property.Value $Rel
    $Analysis = Get-ManagedBlockAnalysis (Read-TextFile $Path) $Markers[0] $Markers[1] $Rel
    if($Analysis.Status -ne 'valid'){ Fail "Managed block must exist exactly once in $Rel"; continue }
    if((Get-TextSha256 $Analysis.Block) -ne $Record.sha256){ Fail "Managed block content mismatch in $Rel" }
  } catch {
    Fail $_.Exception.Message
  }
}

$Installed = @($State.installedRelativePaths)
foreach($Rel in $Installed){
  try { $Path=Join-UnderRoot $Root $Rel } catch { Fail $_.Exception.Message; continue }
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ continue }
  $Text=Read-TextFile $Path
  $ReferenceNamePattern = '(?i)' + 'hen' + 'kel'
  if($Text -match $ReferenceNamePattern){ Fail "Hardcoded reference-project value found in $Rel" }
  if($Text -match '\{\{[A-Z0-9_]+\}\}'){ Fail "Unresolved placeholder found in $Rel" }
  $AbsolutePathPattern = 'D:\\Projects\\' + 'Hen' + 'kel|D:\\Projects\\' + 'Q' + 'bit|C:\\' + 'Users' + '\\[^\\]+\\|/' + 'Users' + '/[^/]+/|/' + 'home' + '/[^/]+/'
  if($Text -match $AbsolutePathPattern){ Fail "Machine-specific absolute path found in $Rel" }
  if($Text -match '(sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]+)'){ Fail "Real-looking secret found in $Rel" }
}
$ConfigPath = Join-UnderRoot $Root '.codex/config.toml'
$Config = Read-TextFile $ConfigPath
$PortableManifestPath = Join-UnderRoot $Root '.qbit-toolkit/codex-ai-tooling/manifest.json'
if(-not(Test-Path -LiteralPath $PortableManifestPath -PathType Leaf)){
  Fail 'Portable ownership manifest is missing.'
} else {
  try {
    $PortableManifest = Read-TextFile $PortableManifestPath | ConvertFrom-Json
    foreach($Field in @('schema_version','installer_version','profile','target_identity','payload_manifest_sha256','installed_entries','managed_blocks','generated_state_entries','original_state_records','last_successful_operation')){
      if($PortableManifest.PSObject.Properties.Name -cnotcontains $Field){ Fail "Ownership manifest field is missing: $Field" }
    }
    if([string]$PortableManifest.payload_manifest_sha256 -notmatch '^[0-9a-f]{64}$'){ Fail 'Ownership payload manifest hash is invalid.' }
  } catch { Fail "Portable ownership manifest is invalid: $($_.Exception.Message)" }
}
if(-not (SameSet (ExtractArray $Config 'serena') $SerenaAllowlist)){ Fail 'Serena tool allowlist is incorrect.' }
if(-not (SameSet (ExtractArray $Config 'context7') $Context7Allowlist)){ Fail 'Context7 tool allowlist is incorrect.' }
if(-not (SameSet (ExtractArray $Config 'sentry') $SentryAllowlist)){ Fail 'Sentry read-only tool allowlist is incorrect.' }
if($Config -match 'mcp_servers\.(graphify|playwright)'){ Fail 'Graphify and Playwright must not be configured as MCP servers.' }
$Versions = Read-TextFile (Join-UnderRoot $Root '.ai/tooling/versions.env')
if($Versions -notmatch [regex]::Escape('PYTHON_IMAGE=python:3.13.14-slim-trixie@sha256:afe189875f1d2f9b45e287834fb9f2c273a5d59d354ae4050ab9affbf0a6ba06')){ Fail 'Pinned Python image differs.' }
if($Versions -notmatch [regex]::Escape('NODE_IMAGE=node:24.18.0-trixie-slim@sha256:5301bbf5e8046148348b1dea15436326f43c579031f8d76654a631225bdfe467')){ Fail 'Pinned Node image differs.' }
if($Versions -notmatch [regex]::Escape('TYPESCRIPT_VERSION=5.9.3')){ Fail 'Pinned TypeScript version differs.' }
if($Versions -notmatch [regex]::Escape('TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.1.3')){ Fail 'Pinned TypeScript Language Server version differs.' }
if($Versions -notmatch [regex]::Escape('RUST_TOOLCHAIN_VERSION=1.85.0')){ Fail 'Pinned Rust toolchain differs.' }
if($Versions -notmatch [regex]::Escape('RUST_BASE_IMAGE=rust:1.85.0-slim-bookworm@sha256:c842cc0357b91bb15ad2bb89934513d0d226f711fac7f7fedb176d3311714d47')){ Fail 'Pinned Rust base image differs.' }
if((Get-FileSha256 (Join-UnderRoot $Root '.ai/tooling/python/requirements.in')) -cne '9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0'){ Fail 'requirements.in hash mismatch.' }
if((Get-FileSha256 (Join-UnderRoot $Root '.ai/tooling/python/requirements.lock')) -cne 'df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1'){ Fail 'requirements.lock hash mismatch.' }
$Compose = Read-TextFile (Join-UnderRoot $Root '.ai/tooling/compose.yaml')
foreach($Required in @('network_mode: none','cap_drop:','      - ALL','read_only: true','target: /workspace')){
  if(-not $Compose.Contains($Required)){ Fail "Compose isolation contract missing: $Required" }
}
if(Test-Path -LiteralPath (Join-Path $Root 'node_modules')){ Fail 'Repository-local node_modules is forbidden.' }
if(Test-Path -LiteralPath (Join-Path $Root 'graphify-out')){ Fail 'Repository-local graphify-out is forbidden.' }
if($Failures -gt 0){ throw "codex-ai-tooling verification failed with $Failures failure(s)." }
Write-Host 'codex-ai-tooling verification passed.'
