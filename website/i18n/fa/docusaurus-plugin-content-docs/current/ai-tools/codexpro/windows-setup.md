---
id: windows-setup
title: راه‌اندازی CodexPro روی Windows
sidebar_label: راه‌اندازی Windows
---

# راه‌اندازی CodexPro روی Windows

این راهنما یک **setup عمومی و قابل استفاده مجدد** را مستند می‌کند، نه snapshot یک سیستم شخصی، پروژه خاص، hostname واقعی، tunnel واقعی، account خاص یا layout وابسته به یک package manager مشخص.

در مثال‌ها از placeholderهایی مثل `<PUBLIC_HOSTNAME>` و `<WORKSPACE_PATH>` استفاده شده است. این مقادیر را با configuration محیط خودتان جایگزین کنید. username، tunnel ID، connector name، package path یا credential یک deployment دیگر را کپی نکنید.

## معماری هدف

یک مسیر معمول remote-to-local به این شکل است:

```text
ChatGPT
  |
  | MCP connector
  v
https://<PUBLIC_HOSTNAME>/mcp
  |
  | secure named tunnel
  v
http://127.0.0.1:8787/mcp
  |
  v
CodexPro
  |
  +-- repository/workspace tools
  +-- bash -> Codex workspace sandbox -> Git Bash
  +-- optional host execution extension
```

مرزهای اعتماد مهم:

- MCP listener فقط روی loopback باشد؛
- public endpoint از یک secure tunnel ارائه شود؛
- MCP authentication فعال باشد؛
- Bash داخل workspace انتخاب‌شده محدود بماند؛
- اجرای مستقیم روی Windows host، اگر فعال شود، یک capability جدا و privileged است.

## سیاست نسخه

setup تاریخی Qbit برای customizationهای version-specific روی **CodexPro `0.29.0`** validate شده بود. هر source patch یا extension محلی باید وابسته به همان build دقیقی در نظر گرفته شود که برای آن نوشته شده است.

برای stock installation، version موردنیاز محیط خودتان را نصب کنید و CLI flagهای همان build را verify کنید. patch مربوط به `0.29.0` را برای version دیگر معتبر فرض نکنید.

Versionهای واقعی deployment را ثبت کنید:

```powershell
pwsh --version
git --version
codex --version
codexpro --version
cloudflared --version
```

## مقادیر deployment

به‌جای hardcode کردن مقادیر شخصی از configuration استفاده کنید:

| Item | فرم پیشنهادی |
|---|---|
| Windows home | `$HOME` |
| Workspace root | `<WORKSPACE_PATH>` |
| CodexPro state | `$HOME\.codexpro` |
| CodexPro package directory | `<CODEXPRO_PACKAGE_DIR>` |
| Git Bash | discovery با `Get-Command` یا configuration صریح |
| Local MCP | `http://127.0.0.1:8787/mcp` |
| Public hostname | `<PUBLIC_HOSTNAME>` |
| Tunnel name | `<TUNNEL_NAME>` |
| ChatGPT connector name | `<CONNECTOR_NAME>` |
| Host execution mode | `off`، `on-request` یا `full-access` |

Launcher قابل استفاده مجدد باید این موارد را از parameter/configuration بگیرد و هیچ username، machine name، project name، DNS واقعی، tunnel ID یا global package path شخصی را داخل source نگذارد.

## مرز امنیتی

### Bash sandboxed

```text
ChatGPT -> CodexPro bash -> Codex workspace sandbox -> Git Bash
```

حتی policy permissive برای Bash نباید به معنی دسترسی خارج از workspace باشد. containment را با سناریوهایی مثل `cwd=..` صریحاً تست کنید.

برای Windows sandbox، environment inheritance را محدود نگه دارید. برای حل یک متغیر missing کل host environment را inherit نکنید.

### اجرای مستقیم روی host

```text
ChatGPT -> CodexPro host execution -> direct Windows process
```

اگر build یا extension محلی شما capabilityهایی مثل `host_exec` یا `open_app` ارائه می‌دهد، آن‌ها را privileged در نظر بگیرید:

- executable باید absolute باشد؛
- argv مستقیم پاس داده شود و shell command string ساخته نشود؛
- `shell: false` حفظ شود؛
- environment variableهای secret-like filter شوند؛
- default پیشنهادی `on-request` است مگر unattended direct execution یک requirement صریح باشد؛
- `full-access` محدودیت UAC یا Administrator را دور نمی‌زند.

MCP URL حاوی token، مخصوصاً در حالت direct host execution، secret محسوب می‌شود.

## پیش‌نیازها

نصب و verify کنید:

1. PowerShell 7؛
2. یک package manager که بتواند package npm با نام `codexpro` را نصب کند؛
3. Git for Windows همراه Git Bash؛
4. Codex CLI با authentication معتبر؛
5. `cloudflared` در صورت استفاده از Cloudflare named tunnel؛
6. کنترل public hostname مورد استفاده connector.

### انتخاب package manager

**Bun اجباری نیست.** CodexPro می‌تواند با package manager انتخابی محیط نصب شود. contract مهم این است که version موردنظر نصب شود و executable `codexpro` روی `PATH` در دسترس باشد.

مثال برای CodexPro `0.29.0`:

```powershell
# npm
npm install -g codexpro@0.29.0

# pnpm
pnpm add -g codexpro@0.29.0

# Bun
bun add -g codexpro@0.29.0

# Yarn Classic
# yarn global add codexpro@0.29.0
```

Syntax نصب global در نسل‌های مختلف Yarn متفاوت است؛ از روش پشتیبانی‌شده توسط version Yarn محیط خود استفاده کنید.

نتیجه را مستقل از package manager verify کنید:

```powershell
codexpro --version
Get-Command codexpro
```

## فقط در صورت نیاز package directory را resolve کنید

برای استفاده عادی از CLI، `codexpro` روی `PATH` کافی است. package directory فقط برای inspection یا patch workflow version-specific لازم می‌شود.

مسیر وابسته به Bun را universal فرض نکنید. مسیر را صریح resolve/configure کنید:

```powershell
$CodexProPackageDir = '<CODEXPRO_PACKAGE_DIR>'
$PackageJson = Join-Path $CodexProPackageDir 'package.json'

if (-not (Test-Path -LiteralPath $PackageJson -PathType Leaf)) {
    throw "CodexPro package.json not found: $PackageJson"
}

$Package = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
if ($Package.name -ne 'codexpro') {
    throw "Unexpected package at $CodexProPackageDir"
}
```

Helperهای رایج:

```powershell
# npm
$NpmRoot = npm root -g

# pnpm
$PnpmRoot = pnpm root -g
```

Package managerهای دیگر ممکن است global store یا shim layout متفاوت داشته باشند. Launcher عمومی باید resolved package directory را از config بگیرد، نه اینکه آن را از username یا package manager حدس بزند.

## ساخت state directory

از home user جاری استفاده کنید:

```powershell
$CodexProDir = Join-Path $HOME '.codexpro'
New-Item -ItemType Directory -Path $CodexProDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'backups') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'bin') -Force | Out-Null
```

ساختار پیشنهادی:

```text
~\.codexpro\
├── backups\
├── bin\
├── http-token
└── Start-CodexPro.ps1
```

این directory را commit نکنید و به‌عنوان deployment template بین userها کپی نکنید.

## ساخت HTTP MCP token

برای هر deployment یک token جدید تولید کنید:

```powershell
$TokenFile = Join-Path $HOME '.codexpro\http-token'

$Rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$Bytes = New-Object byte[] 32
$Rng.GetBytes($Bytes)
$Rng.Dispose()

$Token = ($Bytes | ForEach-Object { $_.ToString('x2') }) -join ''
[IO.File]::WriteAllText($TokenFile, $Token)

if ($Token.Length -ne 64 -or $Token -notmatch '^[0-9a-f]{64}$') {
    throw 'Generated MCP token is invalid.'
}
```

Token را در logهای عادی چاپ نکنید و داخل repository قرار ندهید.

## راه‌اندازی Cloudflare named tunnel

در این مثال Cloudflare استفاده می‌شود. همه مقادیر deployment-specific را خودتان تعیین کنید:

```powershell
$TunnelName = '<TUNNEL_NAME>'
$Hostname = '<PUBLIC_HOSTNAME>'

cloudflared tunnel login
cloudflared tunnel create $TunnelName
cloudflared tunnel route dns $TunnelName $Hostname
cloudflared tunnel list
```

Tunnel ID را Cloudflare تولید می‌کند. ID متعلق به deployment دیگر را داخل launcher عمومی hardcode نکنید.

## تنظیم Git Bash

به‌جای مسیر user-specific، discovery انجام دهید:

```powershell
$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)

$GitBash = $GitBashCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $GitBash) {
    throw 'Git Bash was not found. Configure its path explicitly.'
}
```

اگر Git در مسیر دیگری نصب شده، همان location را configure کنید.

## customizationهای version-specific روی Windows

بعضی deploymentها برای یک build مشخص CodexPro، Windows Bash sandbox path را تغییر می‌دهند یا capabilityهایی مثل `host_exec` و `open_app` اضافه می‌کنند.

این customizationها **deployment value عمومی نیستند**. آن‌ها را به‌عنوان patch asset versioned مدیریت کنید:

1. build دقیق CodexPro را pin کنید؛
2. `<CODEXPRO_PACKAGE_DIR>` را صریح پاس دهید؛
3. username، home path، project path، hostname، tunnel ID و connector name را داخل patch source قرار ندهید؛
4. anchorهای ساختاری exact باشند و در صورت missing/duplicate بودن fail شود؛
5. قبل از mutation backup بگیرید؛
6. فایل‌های نهایی را قبل از startup validate کنید؛
7. hash را از همان patch versionی که deploy می‌کنید تولید کنید، نه از یک ماشین دیگر؛
8. بعد از هر update، patch را دوباره review و test کنید.

اگر stock CodexPro capability لازم را ارائه می‌کند، stock implementation را به local patch ترجیح دهید.

## Launcher قابل استفاده مجدد

Launcher باید مقادیر deployment را parameter بگیرد. مثال زیر هیچ path یا hostname شخصی ندارد:

```powershell
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path,

    [Parameter(Mandatory)]
    [string]$Hostname,

    [Parameter(Mandatory)]
    [string]$TunnelName,

    [ValidateSet('off', 'on-request', 'full-access')]
    [string]$HostExecMode = 'on-request'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Workspace does not exist: $Root"
}

$TokenFile = Join-Path $HOME '.codexpro\http-token'
if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "CodexPro token file not found: $TokenFile"
}

$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)
$GitBash = $GitBashCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $GitBash) {
    throw 'Git Bash was not found.'
}

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$McpToken = [IO.File]::ReadAllText($TokenFile).Trim()
if ([string]::IsNullOrWhiteSpace($McpToken) -or $McpToken -match '\s') {
    throw 'CodexPro token is empty or invalid.'
}

$PreviousBashSandbox = $env:CODEXPRO_BASH_SANDBOX
$PreviousBashExecutable = $env:CODEXPRO_BASH_EXECUTABLE
$PreviousHostExecMode = $env:CODEXPRO_HOST_EXEC_MODE

$env:CODEXPRO_BASH_SANDBOX = 'workspace'
$env:CODEXPRO_BASH_EXECUTABLE = $GitBash
$env:CODEXPRO_HOST_EXEC_MODE = $HostExecMode

$CodexProArgs = @(
    'stable',
    '--root', $ResolvedRoot,
    '--hostname', $Hostname,
    '--tunnel-name', $TunnelName,
    '--token', $McpToken,
    '--agent',
    '--tool-mode', 'full',
    '--write', 'workspace',
    '--bash', 'full'
)

try {
    & codexpro @CodexProArgs
}
finally {
    $env:CODEXPRO_BASH_SANDBOX = $PreviousBashSandbox
    $env:CODEXPRO_BASH_EXECUTABLE = $PreviousBashExecutable
    $env:CODEXPRO_HOST_EXEC_MODE = $PreviousHostExecMode
}
```

آن را مثلاً در مسیر زیر ذخیره کنید:

```text
~\.codexpro\Start-CodexPro.ps1
```

چون workspace، hostname، tunnel name و host mode در runtime داده می‌شوند، launcher به یک machine خاص وابسته نمی‌شود.

## Helper اختیاری `cpx`

می‌توانید PowerShell helper زیر را به profile خود اضافه کنید:

```powershell
function cpx {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Root = (Get-Location).Path,

        [Parameter(Mandatory)]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [string]$TunnelName
    )

    $Launcher = Join-Path $HOME '.codexpro\Start-CodexPro.ps1'
    & $Launcher -Root $Root -Hostname $Hostname -TunnelName $TunnelName
}
```

مثال عمومی:

```powershell
cpx -Root 'D:\Projects\ExampleProject' -Hostname 'codexpro.example.com' -TunnelName 'codexpro-local'
```

برای کار روزمره، narrowest practical repository root را انتخاب کنید و کل user profile را expose نکنید.

## اتصال ChatGPT

بعد از healthy شدن server و tunnel، MCP connector را با مقادیر deployment خودتان بسازید:

| Field | مقدار |
|---|---|
| Name | `<CONNECTOR_NAME>` |
| Server URL | exact URL تولیدشده توسط CodexPro runtime |
| Authentication | mode موردنیاز endpoint |
| Permissions | فقط actionهای لازم workflow |

Connector name یک deployment choice است و نباید اسم شخص یا یک سیستم خصوصی به‌عنوان مقدار canonical در مستندات عمومی ثبت شود.

اگر URL شامل authentication material است، کل URL را secret در نظر بگیرید.

## Verification

### 1. Local health

قبل از public tunnel، endpoint محلی را تست کنید:

```text
http://127.0.0.1:8787/healthz
```

### 2. Configuration

با diagnostic/config resource خود CodexPro مقادیر effective زیر را بررسی کنید:

- host و port؛
- authentication؛
- workspace root؛
- Bash mode؛
- write mode؛
- tool mode؛
- environment inheritance؛
- host-execution mode در صورت نصب extension.

Tool count ثابت متعلق به deployment دیگری را acceptance criterion قرار ندهید؛ inventory ممکن است با version و capability set تغییر کند.

### 3. Workspace containment

یک test repository را به‌عنوان `<WORKSPACE_PATH>` باز کنید و مطمئن شوید `cwd=..` نمی‌تواند از root خارج شود.

### 4. Bash path

یک command harmless مثل `pwd` اجرا کنید و verify کنید به workspace انتخاب‌شده resolve می‌شود.

### 5. Host execution

فقط اگر extension مربوط به host execution را آگاهانه فعال کرده‌اید، با یک executable harmless و absolute تست کنید:

```text
C:\Windows\System32\whoami.exe
```

Approval behavior باید مطابق mode انتخاب‌شده باشد.

### 6. Public tunnel

بررسی کنید hostname عمومی به endpoint محلی route شود و request بدون authentication نتواند MCP access بگیرد.

### 7. End-to-end connector

روی یک disposable test repository یک loop حداقلی read → controlled edit/write → verification را انجام دهید. اولین E2E test را روی production repository اجرا نکنید.

## سیاست Update

Installation patch‌شده version-specific را blind update نکنید.

قبل از update:

1. version فعلی CodexPro را ثبت کنید؛
2. local state لازم برای recovery را backup کنید و secret را وارد source control نکنید؛
3. package fileهای تغییرکرده توسط extension را backup کنید؛
4. version جدید را با package manager انتخابی نصب کنید؛
5. اگر package layout تغییر کرده، package directory را دوباره resolve کنید؛
6. implementation جدید را با assumptionهای patch مقایسه کنید؛
7. patch را فقط بعد از review دوباره اعمال یا retire کنید؛
8. acceptance test کامل را اجرا کنید؛
9. production connector را فقط بعد از pass شدن validation منتقل کنید.

Package manager می‌تواند مستقل از CodexPro تغییر کند. Storage layout package manager نباید بخشی از معماری CodexPro فرض شود.

## Troubleshooting

### `codexpro` پیدا نمی‌شود

Global binary/shim directory package manager را بررسی کنید:

```powershell
Get-Command codexpro -ErrorAction SilentlyContinue
```

### Patch script مسیر `dist` را پیدا نمی‌کند

`<CODEXPRO_PACKAGE_DIR>` اشتباه است یا package layout تغییر کرده. مسیر واقعی package manager فعلی را resolve کنید و به hardcoded Bun path fallback نکنید.

### Bash اجرا نمی‌شود

Git Bash را مستقل verify کنید و سپس `CODEXPRO_BASH_EXECUTABLE` را بررسی کنید.

### Workspace escape موفق می‌شود

این یک security failure است. Remote connector را تا زمان اصلاح containment متوقف کنید.

### Tunnel محلی کار می‌کند ولی public endpoint نه

DNS، named tunnel، hostname ownership و authentication را جداگانه بررسی کنید. برای debug tunnel، MCP authentication را ضعیف نکنید.

### Host execution بیش از حد permissive است

Mode را به `on-request` یا `off` تغییر دهید و server را restart کنید.

## Acceptance checklist

- [ ] Version موردنظر CodexPro نصب و ثبت شده است.
- [ ] `codexpro` مستقل از package manager روی `PATH` resolve می‌شود.
- [ ] هیچ username، machine name، project name، hostname واقعی، tunnel ID یا package-manager-specific global path داخل reusable script وجود ندارد.
- [ ] MCP listener روی loopback bind شده است.
- [ ] Public tunnel hostname صحیح resolve می‌شود.
- [ ] MCP authentication فعال است و secret commit نشده است.
- [ ] Workspace root صریح است.
- [ ] `cwd=..` نمی‌تواند از workspace خارج شود.
- [ ] Git Bash داخل workspace sandbox اجرا می‌شود.
- [ ] broad host environment inheritance بدون review فعال نشده است.
- [ ] Optional host execution approval mode صحیح دارد.
- [ ] E2E روی disposable test repository پاس می‌شود.
- [ ] Patchهای version-specific، در صورت وجود، برای exact build فعلی تولید و validate شده‌اند.

## قانون عملیاتی پیشنهادی

مستند عمومی باید **contract و placeholder** را توصیف کند، نه machine یک توسعه‌دهنده را. این موارد نباید در canonical docs قرار بگیرند:

```text
Windows username واقعی
home-directory path واقعی
نام پروژه یا مشتری واقعی
connector name شخصی
public hostname خصوصی
Cloudflare tunnel ID واقعی
authentication token
مسیر global یک package manager خاص به‌عنوان مسیر universal
```

این تفکیک باعث می‌شود راهنمای CodexPro بین سیستم‌ها، تیم‌ها، package managerها و repositoryهای مختلف قابل استفاده مجدد باشد.
