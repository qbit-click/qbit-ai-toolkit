param([switch]$Clean)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$compose = Join-Path $root '.ai/tooling/compose.yaml'
$expectedIn = '9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0'
$expectedLock = 'df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1'

function Get-GitIndexSnapshot {
    $snapshot = ((git -C $root ls-files --stage) -join "`n")
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect the Git index.'
    }
    return $snapshot
}

function Get-FileSha256([string]$Path) {
    $stream = [System.IO.File]::Open($Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose(); $stream.Dispose() }
}

if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) { throw 'Repository root is not a Git worktree.' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker CLI is unavailable.' }
docker info --format '{{.OSType}}/{{.Architecture}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker daemon is unavailable.' }
$engine = (docker info --format '{{.OSType}}/{{.Architecture}}').Trim()
if ($engine -notmatch '^linux/(amd64|x86_64)$') { throw "Docker engine does not provide native linux/amd64: $engine" }
$composeVersion = (docker compose version --short).Trim()
$composeVersionText = $composeVersion.Trim().TrimStart('v')
$parsedComposeVersion = $null

if (
    $LASTEXITCODE -ne 0 -or
    -not [version]::TryParse(
        $composeVersionText,
        [ref]$parsedComposeVersion
    ) -or
    $parsedComposeVersion.Major -lt 2
) {
    throw "Docker Compose 2 or later is required; detected: $composeVersionText"
}
$required = @(
    '.ai/tooling/Dockerfile', '.ai/tooling/compose.yaml', '.ai/tooling/runtime-entrypoint.py',
    '.ai/tooling/build-download.py', '.ai/tooling/graphify-runtime.py',
    '.ai/tooling/doctor.py', '.ai/tooling/serena_config.yml',
    '.ai/tooling/versions.env', '.ai/tooling/debian-trixie-amd64.lock', '.ai/tooling/serena-artifacts.lock',
    '.ai/tooling/python/requirements.in', '.ai/tooling/python/requirements.lock',
    '.ai/tooling/language-servers/package.json', '.ai/tooling/language-servers/package-lock.json',
    '.serena/project.yml', '.serena/codex-single-project.yml'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) { throw "Missing build input: $relative" }
}
if ((Get-FileSha256 (Join-Path $root '.ai/tooling/python/requirements.in')) -ne $expectedIn) { throw 'requirements.in hash mismatch.' }
if ((Get-FileSha256 (Join-Path $root '.ai/tooling/python/requirements.lock')) -ne $expectedLock) { throw 'requirements.lock hash mismatch.' }
$packageLockPath = Join-Path $root '.ai/tooling/language-servers/package-lock.json'
$packageLockJson = [IO.File]::ReadAllText(
    $packageLockPath,
    [Text.UTF8Encoding]::new($false, $true)
)

# Windows PowerShell 5.1 rejects the legitimate empty property name used by
# npm lockfileVersion 3 at packages[""]. Rename only that one key in memory.
$rootPackageSentinel = '__qbit_root_package__'

if ($packageLockJson.Contains('"' + $rootPackageSentinel + '"')) {
    throw "package-lock.json contains the reserved validation sentinel."
}

$rootPackagePattern = '(?ms)("packages"\s*:\s*\{\s*)""(\s*:)'
$rootPackageMatches = [regex]::Matches(
    $packageLockJson,
    $rootPackagePattern
)

if ($rootPackageMatches.Count -ne 1) {
    throw "package-lock.json must contain exactly one packages[`"`"] root entry."
}

$normalizedPackageLockJson = [regex]::Replace(
    $packageLockJson,
    $rootPackagePattern,
    ('$1"' + $rootPackageSentinel + '"$2'),
    1
)

try {
    $packageLock = $normalizedPackageLockJson |
        ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "Invalid package-lock.json: $($_.Exception.Message)"
}

if ([int]$packageLock.lockfileVersion -ne 3) {
    throw "package-lock.json must use lockfileVersion 3."
}

$packagesProperty = $packageLock.PSObject.Properties['packages']

if ($null -eq $packagesProperty) {
    throw 'package-lock.json is missing the packages object.'
}

$packages = $packagesProperty.Value
$rootPackageProperty = $packages.PSObject.Properties[$rootPackageSentinel]

if ($null -eq $rootPackageProperty) {
    throw 'package-lock.json is missing packages[""].'
}

$dependenciesProperty =
    $rootPackageProperty.Value.PSObject.Properties['dependencies']

if ($null -eq $dependenciesProperty) {
    throw 'package-lock.json root package is missing dependencies.'
}

$actualDependencies = @{}

foreach ($property in $dependenciesProperty.Value.PSObject.Properties) {
    $actualDependencies[$property.Name] = [string]$property.Value
}

$expectedDependencies = @{
    'bash-language-server' = '5.6.0'
    'pyright' = '1.1.403'
    'typescript' = '5.9.3'
    'typescript-language-server' = '5.1.3'
}

if ($actualDependencies.Count -ne $expectedDependencies.Count) {
    throw "Unexpected number of direct npm dependencies: $($actualDependencies.Count)"
}

foreach ($name in $expectedDependencies.Keys) {
    if (
        -not $actualDependencies.ContainsKey($name) -or
        $actualDependencies[$name] -ne $expectedDependencies[$name]
    ) {
        throw (
            "npm direct dependency contract mismatch for ${name}: " +
            "expected $($expectedDependencies[$name]), " +
            "detected $($actualDependencies[$name])"
        )
    }
}

foreach ($property in $packages.PSObject.Properties) {
    if ($property.Name -eq $rootPackageSentinel) {
        continue
    }

    $integrityProperty = $property.Value.PSObject.Properties['integrity']

    if (
        $null -eq $integrityProperty -or
        [string]::IsNullOrWhiteSpace([string]$integrityProperty.Value)
    ) {
        throw "package-lock entry is missing integrity: $($property.Name)"
    }
}

Write-Host 'package-lock contract: PASS'
if ((Test-Path (Join-Path $root 'node_modules')) -or (Test-Path (Join-Path $root '.ai/tooling/language-servers/node_modules'))) { throw 'Repository node_modules is forbidden.' }
docker compose --project-directory $root -f $compose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Compose configuration is invalid.' }

$beforeIndex = Get-GitIndexSnapshot
$arguments = @('compose', '--project-directory', $root, '-f', $compose, 'build')
if ($Clean) { $arguments += @('--pull', '--no-cache') }
& docker @arguments
if ($LASTEXITCODE -ne 0) { throw 'Docker image build failed.' }
& docker compose --project-directory $root -f $compose run --rm -T --no-deps serena true
if ($LASTEXITCODE -ne 0) { throw 'Serena state/resource preparation failed.' }
$afterIndex = Get-GitIndexSnapshot
if ($afterIndex -cne $beforeIndex) { throw 'Git index changed during the AI tooling bootstrap.' }
Write-Host 'Project-local AI image and Serena state/resources prepared without starting MCP services or mutating the Git index.'
