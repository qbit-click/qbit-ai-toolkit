Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$InstallerRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Install=Join-Path $InstallerRoot 'install.ps1'
$Verify=Join-Path $InstallerRoot 'verify.ps1'
$Uninstall=Join-Path $InstallerRoot 'uninstall.ps1'
$TempRoot=Join-Path ([IO.Path]::GetTempPath()) ('ai-context-installer-it-' + [Guid]::NewGuid().ToString('N'))
$Passed=0;$Failed=0
New-Item -ItemType Directory -Force -Path $TempRoot|Out-Null

function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function WriteUtf8([string]$Path,[string]$Text){$Parent=Split-Path -Parent $Path;if(-not(Test-Path $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function ReadUtf8([string]$Path){return [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n").Replace("`r","`n")}
function Sha([string]$Path){$S=[Security.Cryptography.SHA256]::Create();$F=[IO.File]::OpenRead($Path);try{return -join($S.ComputeHash($F)|%{$_.ToString('x2')})}finally{$F.Dispose();$S.Dispose()}}
function NewRepo([string]$Name){$Path=Join-Path $TempRoot $Name;New-Item -ItemType Directory -Force -Path $Path|Out-Null;& git -C $Path init -q -b main;if($LASTEXITCODE){throw 'git init failed'};WriteUtf8 (Join-Path $Path 'README.md') "# $Name`n";& git -C $Path add README.md;& git -C $Path -c user.name=Test -c user.email=test@example.invalid commit -q -m init;return $Path}
function Run([string[]]$Arguments){$Out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Install @Arguments 2>&1);return [pscustomobject]@{Code=$LASTEXITCODE;Text=($Out-join "`n")}}
function RunJson([string[]]$Arguments){$R=Run ($Arguments+@('-Format','json'));$J=$null;if($R.Text){try{$J=$R.Text|ConvertFrom-Json}catch{}};return [pscustomobject]@{Code=$R.Code;Text=$R.Text;Json=$J}}
function Test([string]$Name,[scriptblock]$Body){try{&$Body;$script:Passed++;Write-Host "PASS $Name"}catch{$script:Failed++;Write-Host "FAIL ${Name}: $($_.Exception.Message)"}}

try{
  Test 'member plan is write-free' {
    $Repo=NewRepo 'plan-member';$Before=@(& git -C $Repo status --porcelain)
    $R=RunJson @('-Operation','plan','-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git')
    Assert ($R.Code -eq 0 -and $R.Json.success) 'plan failed'
    Assert (-not(Test-Path (Join-Path $Repo '.qbit/toolkit/installed/ai-context.json'))) 'plan wrote state'
    Assert (-not(Test-Path (Join-Path $Repo '.ai/context/context.ps1'))) 'plan wrote launcher'
    Assert ((@(& git -C $Repo status --porcelain)-join "`n") -eq ($Before-join "`n")) 'plan changed git worktree'
  }

  Test 'member install verify and repeated install are idempotent' {
    $Repo=NewRepo 'member-idempotent'
    $Args=@('-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git')
    $R=RunJson (@('-Operation','install')+$Args);Assert ($R.Code -eq 0 -and $R.Json.success) 'install failed'
    $State=Join-Path $Repo '.qbit/toolkit/installed/ai-context.json';Assert (Test-Path $State) 'state missing'
    Assert (Test-Path (Join-Path $Repo '.ai/context/context.ps1')) 'launcher missing'
    $VerifyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Verify -Target $Repo -Format json 2>&1);Assert ($LASTEXITCODE -eq 0) "verify failed: $($VerifyOut-join ' ')"
    $Before=Sha $State;$R2=RunJson @('-Operation','install','-Target',$Repo);Assert ($R2.Code -eq 0 -and $R2.Json.actions.Count -eq 0) 'repeated install was not idempotent';Assert ((Sha $State) -eq $Before) 'idempotent install rewrote state'
  }

  Test 'managed file line-ending normalization does not trigger ownership conflict' {
    $Repo=NewRepo 'member-crlf';$Base=@('-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git');$InstallResult=RunJson (@('-Operation','install')+$Base);Assert ($InstallResult.Code -eq 0) 'install failed'
    $Launcher=Join-Path $Repo '.ai/context/context.ps1';$Text=ReadUtf8 $Launcher;[IO.File]::WriteAllText($Launcher,$Text.Replace("`n","`r`n"),[Text.UTF8Encoding]::new($false))
    $VerifyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Verify -Target $Repo -Format json 2>&1);Assert ($LASTEXITCODE -eq 0) "verify rejected CRLF-only drift: $($VerifyOut-join ' ')"
    $Update=RunJson @('-Operation','update','-Target',$Repo);Assert ($Update.Code -eq 0) 'update rejected CRLF-only drift'
  }

  Test 'unowned file conflicts fail closed' {
    $Repo=NewRepo 'unowned-conflict';New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.ai/context')|Out-Null;WriteUtf8 (Join-Path $Repo '.ai/context/context.ps1') "custom`n"
    $R=RunJson @('-Operation','plan','-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git')
    Assert ($R.Code -eq 4 -and -not $R.Json.success) 'unowned conflict was accepted'
    Assert (-not(Test-Path (Join-Path $Repo '.qbit/toolkit/installed/ai-context.json'))) 'conflict wrote state'
    Assert ((ReadUtf8 (Join-Path $Repo '.ai/context/context.ps1')) -eq "custom`n") 'conflict modified unowned file'
  }

  Test 'matching generated file requires explicit adoption' {
    $Repo=NewRepo 'adopt-matching';New-Item -ItemType Directory -Force -Path (Join-Path $Repo '.ai/context')|Out-Null;Copy-Item (Join-Path $InstallerRoot 'templates/common/member/context.ps1') (Join-Path $Repo '.ai/context/context.ps1')
    $Base=@('-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git')
    $R=RunJson (@('-Operation','plan')+$Base);Assert ($R.Code -eq 4) 'matching unowned file was silently adopted'
    $R2=RunJson (@('-Operation','install','-AdoptMatching')+$Base);Assert ($R2.Code -eq 0 -and $R2.Json.success) 'explicit adoption failed'
  }

  Test 'modified owned file fails then replace backs up and repairs' {
    $Repo=NewRepo 'owned-replace';$Base=@('-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git');$null=RunJson (@('-Operation','install')+$Base)
    $Launcher=Join-Path $Repo '.ai/context/context.ps1';WriteUtf8 $Launcher "modified`n"
    $Fail=RunJson @('-Operation','update','-Target',$Repo);Assert ($Fail.Code -eq 4) 'modified owned file was replaced without policy'
    $Ok=RunJson @('-Operation','update','-Target',$Repo,'-OwnedModified','replace');Assert ($Ok.Code -eq 0) 'replace policy failed'
    Assert ((ReadUtf8 $Launcher) -like 'param(*') 'launcher was not repaired'
    $Backups=Join-Path $Repo '.qbit-toolkit/ai-context/backups';Assert (Test-Path $Backups) 'replace did not write backup'
  }

  Test 'uninstall preserves outside content and seeded bridge README' {
    $Repo=NewRepo 'uninstall-preserve';WriteUtf8 (Join-Path $Repo 'AGENTS.md') "# User rules`n";$Base=@('-Mode','member','-Target',$Repo,'-ProjectId','demo','-RepositoryId','demo-api','-ContextRemote','https://github.com/example/demo-ai-context.git');$null=RunJson (@('-Operation','install')+$Base)
    $Bridge=Join-Path $Repo '.ai-bridge/README.md';Assert (Test-Path $Bridge) 'bridge seed missing';WriteUtf8 $Bridge "# User-owned bridge docs`n"
    $Out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Uninstall -Target $Repo -Format json 2>&1);Assert ($LASTEXITCODE -eq 0) "uninstall failed: $($Out-join ' ')"
    Assert ((ReadUtf8 (Join-Path $Repo 'AGENTS.md')) -like '# User rules*') 'outside AGENTS content was removed'
    Assert ((ReadUtf8 $Bridge) -eq "# User-owned bridge docs`n") 'seeded project-owned bridge README was removed or changed'
    Assert (-not(Test-Path (Join-Path $Repo '.ai/context/context.ps1'))) 'managed launcher remained after uninstall'
  }

  Test 'central update preserves project-owned continuity seeds' {
    $Repo=NewRepo 'central-seeds';$Base=@('-Mode','central','-Target',$Repo,'-ProjectId','demo','-ProjectDisplayName','Demo','-RepositoryId','demo-ai-context','-ContextRemote','https://github.com/example/demo-ai-context.git');$R=RunJson (@('-Operation','install')+$Base);Assert ($R.Code -eq 0) 'central install failed'
    $Current=Join-Path $Repo 'state/current.md';WriteUtf8 $Current "# Current Project AI State`n`nCUSTOM PROJECT CONTENT`n";$Before=Sha $Current
    $Update=RunJson @('-Operation','update','-Target',$Repo);Assert ($Update.Code -eq 0) 'central update failed';Assert ((Sha $Current) -eq $Before) 'central update overwrote project-owned continuity'
    $VerifyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Verify -Target $Repo -Format json 2>&1);Assert ($LASTEXITCODE -eq 0) 'central verify failed after project-owned seed changed'
  }

  Test 'central uninstall preserves project-owned continuity seeds' {
    $Repo=NewRepo 'central-uninstall';$Base=@('-Mode','central','-Target',$Repo,'-ProjectId','demo','-ProjectDisplayName','Demo','-RepositoryId','demo-ai-context','-ContextRemote','https://github.com/example/demo-ai-context.git');$null=RunJson (@('-Operation','install')+$Base)
    $Current=Join-Path $Repo 'state/current.md';WriteUtf8 $Current "# Keep me`n"
    $Out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Uninstall -Target $Repo -Format json 2>&1);Assert ($LASTEXITCODE -eq 0) 'central uninstall failed'
    Assert ((ReadUtf8 $Current) -eq "# Keep me`n") 'central uninstall removed project-owned continuity'
    Assert (-not(Test-Path (Join-Path $Repo 'tooling/context-lifecycle.ps1'))) 'central managed tooling remained'
  }
} finally {
  Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if($Failed -gt 0){throw "$Failed integration test(s) failed; $Passed passed."}
Write-Host "PASS all $Passed AI Context installer integration tests"
