Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$templateLauncher = Join-Path $repoRoot 'templates/member/context.ps1'
$centralTool = Join-Path $repoRoot 'tooling/context-lifecycle.ps1'

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $Root @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($code -ne 0) {
        throw "git failed in ${Root}: git $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return ($output -join "`n").Trim()
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Assert-Fails {
    param([scriptblock]$Script, [string]$Contains)
    $message = $null
    try {
        & $Script
    } catch {
        $message = $_.Exception.Message
    }
    if ($null -eq $message) { throw 'ASSERTION FAILED: expected command to fail.' }
    if (-not [string]::IsNullOrWhiteSpace($Contains) -and $message -notlike "*$Contains*") {
        throw "ASSERTION FAILED: failure did not contain expected text '$Contains'. Actual: $message"
    }
    return $message
}

function Initialize-GitIdentity {
    param([string]$Root)
    Invoke-Git -Root $Root -Arguments @('config', 'user.name', 'AI Context Test') | Out-Null
    Invoke-Git -Root $Root -Arguments @('config', 'user.email', 'ai-context-test@example.invalid') | Out-Null
}

function New-TestEnvironment {
    param([string]$Name)

    $base = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-context-test-$Name-" + [guid]::NewGuid().ToString('N'))
    $contextBare = Join-Path $base 'context.git'
    $contextSeed = Join-Path $base 'context-seed'
    $memberBare = Join-Path $base 'member.git'
    $memberSeed = Join-Path $base 'member-seed'
    $memberClone = Join-Path $base 'member-clone'

    New-Item -ItemType Directory -Path $base -Force | Out-Null
    & git init --bare --initial-branch=main $contextBare | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize context bare repo.' }

    & git init --initial-branch=main $contextSeed | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize context seed repo.' }
    Initialize-GitIdentity -Root $contextSeed

    $requiredFiles = @{
        'AI_CONTEXT.md' = "# Test Central Context`n"
        'project/authority.md' = "# Authority`nSource outranks context.`n"
        'state/current.md' = "# Current`nTest state.`n"
        'state/next-action.md' = "# Next`nContinue.`n"
        'state/open-questions.md' = "# Open Questions`nNone.`n"
        'state/pending-decisions.md' = "# Pending Decisions`nNone.`n"
        'repositories/repositories.yaml' = "project: test-project`n"
    }
    foreach ($entry in $requiredFiles.GetEnumerator()) {
        $target = Join-Path $contextSeed $entry.Key
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Set-Content -LiteralPath $target -Value $entry.Value -Encoding UTF8
    }
    New-Item -ItemType Directory -Path (Join-Path $contextSeed 'tooling') -Force | Out-Null
    Copy-Item -LiteralPath $centralTool -Destination (Join-Path $contextSeed 'tooling/context-lifecycle.ps1')
    Invoke-Git -Root $contextSeed -Arguments @('add', '--all') | Out-Null
    Invoke-Git -Root $contextSeed -Arguments @('commit', '-m', 'seed context') | Out-Null
    Invoke-Git -Root $contextSeed -Arguments @('remote', 'add', 'origin', $contextBare) | Out-Null
    Invoke-Git -Root $contextSeed -Arguments @('push', '-u', 'origin', 'main') | Out-Null

    & git init --bare --initial-branch=main $memberBare | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize member bare repo.' }
    & git init --initial-branch=main $memberSeed | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize member seed repo.' }
    Initialize-GitIdentity -Root $memberSeed

    $contextDir = Join-Path $memberSeed '.ai/context'
    New-Item -ItemType Directory -Path $contextDir -Force | Out-Null
    Copy-Item -LiteralPath $templateLauncher -Destination (Join-Path $contextDir 'context.ps1')
    @{
        schemaVersion = 1
        project = 'test-project'
        repository = 'test-member'
        context = @{
            remote = $contextBare
            branch = 'main'
            cachePath = '.ai/context/cache/project-context'
        }
        behavior = @{
            ensureOnStart = $true
            refreshOnStart = $true
            loadOnStart = $true
            checkpointAfterValidation = $true
            checkpointBeforeHandoff = $true
            commitContext = $true
            pushContext = $true
        }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $contextDir 'config.json') -Encoding UTF8
    "cache/`nruntime/`n" | Set-Content -LiteralPath (Join-Path $contextDir '.gitignore') -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $memberSeed '.ai-bridge') -Force | Out-Null
    "*`n!.gitignore`n!README.md`n" | Set-Content -LiteralPath (Join-Path $memberSeed '.ai-bridge/.gitignore') -Encoding UTF8
    "# AI Bridge`n" | Set-Content -LiteralPath (Join-Path $memberSeed '.ai-bridge/README.md') -Encoding UTF8
    "# Member`n" | Set-Content -LiteralPath (Join-Path $memberSeed 'README.md') -Encoding UTF8
    Invoke-Git -Root $memberSeed -Arguments @('add', '--all') | Out-Null
    Invoke-Git -Root $memberSeed -Arguments @('commit', '-m', 'seed member automation') | Out-Null
    Invoke-Git -Root $memberSeed -Arguments @('remote', 'add', 'origin', $memberBare) | Out-Null
    Invoke-Git -Root $memberSeed -Arguments @('push', '-u', 'origin', 'main') | Out-Null

    & git clone $memberBare $memberClone | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone member test repo.' }
    Initialize-GitIdentity -Root $memberClone

    return [pscustomobject]@{
        Base = $base
        ContextBare = $contextBare
        ContextSeed = $contextSeed
        MemberBare = $memberBare
        MemberSeed = $memberSeed
        MemberClone = $memberClone
        Launcher = (Join-Path $memberClone '.ai/context/context.ps1')
        Cache = (Join-Path $memberClone '.ai/context/cache/project-context')
        Checkpoint = (Join-Path $memberClone '.ai-bridge/context-checkpoint.json')
    }
}

function Invoke-Launcher {
    param([object]$Env, [string]$Action)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Env.Launcher $Action 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($code -ne 0) { throw "Launcher action failed: $Action`n$($output -join "`n")" }
    if ($output.Count -gt 0) { $output | ForEach-Object { Write-Host ([string]$_) } }
}

function Invoke-LauncherAllowFailure {
    param([object]$Env, [string]$Action)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Env.Launcher $Action 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [pscustomobject]@{ ExitCode = $code; Output = ($output -join "`n") }
}

function Write-ValidCheckpoint {
    param([object]$Env, [string]$Status = 'VALIDATED', [string]$Objective = 'Validate context lifecycle')
    @{
        schemaVersion = 1
        repository = 'test-member'
        scope = 'context-lifecycle'
        status = $Status
        objective = $Objective
        confirmedFindings = @('Context was loaded automatically.')
        decisions = @('Keep central context non-authoritative.')
        rejectedApproaches = @()
        validation = @('Local integration test passed.')
        openQuestions = @()
        nextAction = 'Continue with the next task.'
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Env.Checkpoint -Encoding UTF8
}

$tests = @()
$tests += @{ Name = 'fresh clone start auto-clones context and generates runtime bundle'; Run = {
    $env = New-TestEnvironment -Name 'fresh-start'
    try {
        Assert-True -Condition (-not (Test-Path -LiteralPath $env.Cache)) -Message 'Context cache should not exist before start.'
        Invoke-Launcher -Env $env -Action 'start'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache '.git')) -Message 'Context cache should be cloned inside member repo.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.MemberClone '.ai-bridge/context-runtime.md')) -Message 'Runtime Markdown bundle should exist.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.MemberClone '.ai-bridge/context-runtime.json')) -Message 'Runtime JSON should exist.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'relative sibling context source resolves portably'; Run = {
    $env = New-TestEnvironment -Name 'relative-source'
    try {
        $configPath = Join-Path $env.MemberClone '.ai/context/config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $config.context.remote = '../context.git'
        $config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
        Invoke-Launcher -Env $env -Action 'start'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache '.git')) -Message 'Relative context source should clone into the member cache.'
        $actualRemote = Invoke-Git -Root $env.Cache -Arguments @('remote', 'get-url', 'origin')
        Assert-True -Condition ([System.IO.Path]::GetFullPath($actualRemote).TrimEnd([char[]]@('\','/')) -eq [System.IO.Path]::GetFullPath($env.ContextBare).TrimEnd([char[]]@('\','/'))) -Message 'Relative context source should resolve to the expected sibling repository.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'clean cache origin migrates to a newly configured remote'; Run = {
    $env = New-TestEnvironment -Name 'remote-migration'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        $replacementBare = Join-Path $env.Base 'replacement-context.git'
        & git clone --bare $env.ContextBare $replacementBare | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create replacement context remote.' }

        $configPath = Join-Path $env.MemberClone '.ai/context/config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $config.context.remote = $replacementBare
        $config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8

        Invoke-Launcher -Env $env -Action 'start'
        $actualRemote = Invoke-Git -Root $env.Cache -Arguments @('remote', 'get-url', 'origin')
        Assert-True -Condition ([System.IO.Path]::GetFullPath($actualRemote).TrimEnd([char[]]@(92,47)) -eq [System.IO.Path]::GetFullPath($replacementBare).TrimEnd([char[]]@(92,47))) -Message 'Clean context cache should migrate origin to the newly configured remote.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'dirty cache refuses automatic origin migration'; Run = {
    $env = New-TestEnvironment -Name 'dirty-remote-migration'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        $replacementBare = Join-Path $env.Base 'replacement-context.git'
        & git clone --bare $env.ContextBare $replacementBare | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to create replacement context remote.' }

        Set-Content -LiteralPath (Join-Path $env.Cache 'local-dirty-marker.txt') -Value 'preserve me' -Encoding UTF8
        $configPath = Join-Path $env.MemberClone '.ai/context/config.json'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $config.context.remote = $replacementBare
        $config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8

        $result = Invoke-LauncherAllowFailure -Env $env -Action 'start'
        Assert-True -Condition ($result.ExitCode -ne 0) -Message 'Dirty context cache must refuse automatic origin migration.'
        Assert-True -Condition ($result.Output -like '*automatic origin migration was refused*') -Message 'Dirty origin migration failure should be explicit.'
        $actualRemote = Invoke-Git -Root $env.Cache -Arguments @('remote', 'get-url', 'origin')
        Assert-True -Condition ([System.IO.Path]::GetFullPath($actualRemote).TrimEnd([char[]]@(92,47)) -eq [System.IO.Path]::GetFullPath($env.ContextBare).TrimEnd([char[]]@(92,47))) -Message 'Dirty migration refusal must preserve the previous origin.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'start fast-forwards a clean stale context cache'; Run = {
    $env = New-TestEnvironment -Name 'fast-forward'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        $before = Invoke-Git -Root $env.Cache -Arguments @('rev-parse', 'HEAD')
        Set-Content -LiteralPath (Join-Path $env.ContextSeed 'state/current.md') -Value "# Current`nUpdated remote state.`n" -Encoding UTF8
        Invoke-Git -Root $env.ContextSeed -Arguments @('add', 'state/current.md') | Out-Null
        Invoke-Git -Root $env.ContextSeed -Arguments @('commit', '-m', 'advance context') | Out-Null
        Invoke-Git -Root $env.ContextSeed -Arguments @('push', 'origin', 'main') | Out-Null
        Invoke-Launcher -Env $env -Action 'start'
        $after = Invoke-Git -Root $env.Cache -Arguments @('rev-parse', 'HEAD')
        Assert-True -Condition ($before -ne $after) -Message 'Clean cache should fast-forward to newer remote context.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'start does not overwrite dirty context cache'; Run = {
    $env = New-TestEnvironment -Name 'dirty-start'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        $marker = Join-Path $env.Cache 'local-dirty-marker.txt'
        Set-Content -LiteralPath $marker -Value 'preserve me' -Encoding UTF8
        Invoke-Launcher -Env $env -Action 'start'
        Assert-True -Condition (Test-Path -LiteralPath $marker) -Message 'Dirty context content must be preserved.'
        $runtime = Get-Content -LiteralPath (Join-Path $env.MemberClone '.ai-bridge/context-runtime.json') -Raw | ConvertFrom-Json
        Assert-True -Condition ($runtime.context.dirty -eq $true) -Message 'Runtime must report dirty central context cache.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'invalid checkpoint missing required fields is rejected'; Run = {
    $env = New-TestEnvironment -Name 'missing-field'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        '{"schemaVersion":1,"repository":"test-member"}' | Set-Content -LiteralPath $env.Checkpoint -Encoding UTF8
        $result = Invoke-LauncherAllowFailure -Env $env -Action 'checkpoint'
        Assert-True -Condition ($result.ExitCode -ne 0) -Message 'Missing required checkpoint fields must fail.'
        Assert-True -Condition ($result.Output -like '*missing required field*') -Message 'Missing-field failure should be explicit.'
        Assert-True -Condition (Test-Path -LiteralPath $env.Checkpoint) -Message 'Rejected checkpoint should remain for inspection/correction.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'disallowed checkpoint status is rejected'; Run = {
    $env = New-TestEnvironment -Name 'bad-status'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        Write-ValidCheckpoint -Env $env -Status 'DONE'
        $result = Invoke-LauncherAllowFailure -Env $env -Action 'checkpoint'
        Assert-True -Condition ($result.ExitCode -ne 0) -Message 'Disallowed status must fail.'
        Assert-True -Condition ($result.Output -like '*status is not allowed*') -Message 'Disallowed status failure should be explicit.'
        Assert-True -Condition (Test-Path -LiteralPath $env.Checkpoint) -Message 'Rejected checkpoint should remain.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'secret-like material is rejected without committing'; Run = {
    $env = New-TestEnvironment -Name 'secret'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        Write-ValidCheckpoint -Env $env -Objective 'Bearer abcdefghijklmnopqrstuvwxyz'
        $result = Invoke-LauncherAllowFailure -Env $env -Action 'checkpoint'
        Assert-True -Condition ($result.ExitCode -ne 0) -Message 'Secret-like content must fail.'
        Assert-True -Condition ($result.Output -like '*secret-like material*') -Message 'Secret failure should be explicit without echoing the secret.'
        Assert-True -Condition ($result.Output -notlike '*abcdefghijklmnopqrstuvwxyz*') -Message 'Secret failure must not echo the secret value.'
        Assert-True -Condition (Test-Path -LiteralPath $env.Checkpoint) -Message 'Rejected checkpoint should remain.'
        $count = [int](Invoke-Git -Root $env.Cache -Arguments @('rev-list', '--count', 'HEAD'))
        Assert-True -Condition ($count -eq 1) -Message 'Secret rejection must not create a context commit.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'checkpoint writes repository scoped artifacts commits and pushes'; Run = {
    $env = New-TestEnvironment -Name 'checkpoint'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        Write-ValidCheckpoint -Env $env
        Invoke-Launcher -Env $env -Action 'checkpoint'
        Assert-True -Condition (-not (Test-Path -LiteralPath $env.Checkpoint)) -Message 'Successful checkpoint must clear replay file.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache 'state/repositories/test-member.md')) -Message 'Repository state should be generated.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache 'handoffs/repositories/test-member.md')) -Message 'Repository handoff should be generated.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache 'manifests/repositories/test-member.json')) -Message 'Repository manifest should be generated.'
        $localHead = Invoke-Git -Root $env.Cache -Arguments @('rev-parse', 'HEAD')
        $remoteHead = (& git --git-dir $env.ContextBare rev-parse refs/heads/main).Trim()
        Assert-True -Condition ($localHead -eq $remoteHead) -Message 'Checkpoint commit must be pushed to context remote.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$tests += @{ Name = 'checkpoint refuses pre-existing dirty context work'; Run = {
    $env = New-TestEnvironment -Name 'dirty-checkpoint'
    try {
        Invoke-Launcher -Env $env -Action 'start'
        Set-Content -LiteralPath (Join-Path $env.Cache 'unexpected.txt') -Value 'dirty' -Encoding UTF8
        Write-ValidCheckpoint -Env $env
        $result = Invoke-LauncherAllowFailure -Env $env -Action 'checkpoint'
        Assert-True -Condition ($result.ExitCode -ne 0) -Message 'Dirty cache checkpoint must fail.'
        Assert-True -Condition ($result.Output -like '*pre-existing uncommitted changes*') -Message 'Dirty-cache failure should be explicit.'
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $env.Cache 'unexpected.txt')) -Message 'Dirty file must not be destroyed.'
    } finally { Remove-Item -LiteralPath $env.Base -Recurse -Force -ErrorAction SilentlyContinue }
} }

$failures = 0
foreach ($test in $tests) {
    try {
        & $test.Run
        Write-Host "PASS $($test.Name)"
    } catch {
        $failures++
        Write-Host "FAIL $($test.Name): $($_.Exception.Message)"
    }
}

if ($failures -gt 0) {
    throw "$failures context lifecycle test(s) failed."
}
Write-Host "PASS all $($tests.Count) context lifecycle tests"
