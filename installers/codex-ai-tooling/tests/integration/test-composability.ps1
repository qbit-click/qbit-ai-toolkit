[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ToolkitRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$Tooling=Join-Path $ToolkitRoot 'installers/codex-ai-tooling/install.ps1'
$ToolingVerify=Join-Path $ToolkitRoot 'installers/codex-ai-tooling/verify.ps1'
$ToolingUninstall=Join-Path $ToolkitRoot 'installers/codex-ai-tooling/uninstall.ps1'
$Context=Join-Path $ToolkitRoot 'installers/ai-context/install.ps1'
$TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('qbit-installer-composition-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $TempRoot|Out-Null
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function WriteUtf8([string]$Path,[string]$Text){$p=Split-Path -Parent $Path;if(-not(Test-Path $p)){New-Item -ItemType Directory -Force -Path $p|Out-Null};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function InitRepo([string]$Name){$p=Join-Path $TempRoot $Name;New-Item -ItemType Directory -Force -Path $p|Out-Null;&git -C $p init -q -b main;if($LASTEXITCODE){throw 'git init failed'};WriteUtf8 (Join-Path $p 'PROJECT.txt') 'project content';$p}
function CountMarker([string]$Path,[string]$Marker){return [int]((Select-String -LiteralPath $Path -SimpleMatch $Marker|Measure-Object).Count)}
function Install-ContextMember([string]$Repo,[string]$Id,[string]$Bare){& powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation install -Mode member -Target $Repo -ProjectId composition -RepositoryId $Id -ContextRemote $Bare -ContextBranch main|Out-Null;Assert ($LASTEXITCODE -eq 0) "AI Context install failed for $Id"}
function Install-Tooling([string]$Repo){& powershell -NoProfile -ExecutionPolicy Bypass -File $Tooling -Operation install -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor|Out-Null;Assert ($LASTEXITCODE -eq 0) 'Codex AI Tooling install failed'}
try {
  $Bare=Join-Path $TempRoot 'central.git';&git init --bare -q --initial-branch=main $Bare;if($LASTEXITCODE){throw 'bare init failed'}
  $Central=InitRepo 'central';&git -C $Central remote add origin $Bare
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation install -Mode central -Target $Central -ProjectId composition -ProjectDisplayName Composition -RepositoryId composition-ai-context -ContextRemote $Bare -ContextBranch main|Out-Null
  Assert ($LASTEXITCODE -eq 0) 'Central AI Context install failed';&git -C $Central add --all;&git -C $Central -c user.name=Test -c user.email=test@example.invalid commit -q -m central;&git -C $Central push -q -u origin main

  foreach($Order in @('tooling-context','context-tooling')) {
    $Repo=InitRepo $Order;WriteUtf8 (Join-Path $Repo 'AGENTS.md') "# Prefix`n# Suffix`n";WriteUtf8 (Join-Path $Repo '.gitignore') "project.log`n"
    if($Order -eq 'tooling-context'){Install-Tooling $Repo;Install-ContextMember $Repo $Order $Bare}else{Install-ContextMember $Repo $Order $Bare;Install-Tooling $Repo}
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ToolingVerify -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0) "Tooling verify failed for $Order"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation verify -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0) "Context verify failed for $Order"
    $Agents=Join-Path $Repo 'AGENTS.md';$Ignore=Join-Path $Repo '.gitignore';Assert ((CountMarker $Agents 'qbit-toolkit:codex-ai-tooling:start') -eq 1) "Tooling AGENTS block duplicated for $Order";Assert ((CountMarker $Agents 'qbit-toolkit:ai-context:start') -eq 1) "Context AGENTS block duplicated for $Order";Assert ((CountMarker $Ignore 'qbit-toolkit:codex-ai-tooling:start') -eq 1) "Tooling gitignore block duplicated for $Order";Assert ((CountMarker $Ignore 'qbit-toolkit:ai-context:start') -eq 1) "Context gitignore block duplicated for $Order";Assert ((Get-Content -Raw $Agents).Contains('# Prefix') -and (Get-Content -Raw $Agents).Contains('# Suffix')) "Project AGENTS content was not preserved for $Order"
    $ContextState=Join-Path $Repo '.qbit/toolkit/installed/ai-context.json';$ToolingState=Join-Path $Repo '.qbit/toolkit/installed/codex-ai-tooling.json';$BeforeContext=(Get-FileHash $ContextState -Algorithm SHA256).Hash
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Tooling -Operation update -Target $Repo -Profile generic -SkipBootstrap -SkipDoctor|Out-Null;Assert ($LASTEXITCODE -eq 0) "Tooling update failed for $Order";Assert (((Get-FileHash $ContextState -Algorithm SHA256).Hash) -eq $BeforeContext) "Tooling update changed Context state for $Order"
    $BeforeTooling=(Get-FileHash $ToolingState -Algorithm SHA256).Hash;& powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation update -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0) "Context update failed for $Order";Assert (((Get-FileHash $ToolingState -Algorithm SHA256).Hash) -eq $BeforeTooling) "Context update changed Tooling state for $Order"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ToolingUninstall -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0 -and (Test-Path $ContextState)) "Tooling uninstall did not preserve Context for $Order"; & powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation verify -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0) "Context invalid after Tooling uninstall for $Order"
    Install-Tooling $Repo;& powershell -NoProfile -ExecutionPolicy Bypass -File $Context -Operation uninstall -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0 -and (Test-Path $ToolingState)) "Context uninstall did not preserve Tooling for $Order";& powershell -NoProfile -ExecutionPolicy Bypass -File $ToolingVerify -Target $Repo|Out-Null;Assert ($LASTEXITCODE -eq 0) "Tooling invalid after Context uninstall for $Order"
  }
  Write-Host 'PASS cross-installer composability (both orders, updates, uninstalls, shared blocks, idempotency)'
} finally {Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue}
