---
id: windows-setup
title: راه‌اندازی Canonical CodexPro روی Windows
sidebar_label: راه‌اندازی Windows
---

# راه‌اندازی Canonical CodexPro روی Windows

> **وضعیت مرجع:** این راهنما بر اساس configuration ثبت‌شده در `2026-08-10` است و patchهای آن مشخصاً برای **CodexPro `0.29.0`** نوشته شده‌اند. برای patch blockهای exact و فایل‌هایی که SHA-256 مرجع دارند، از [نسخه canonical انگلیسی](https://ai-toolkit.qbit.click/ai-tools/codexpro/windows-setup) استفاده کنید و متن کد را ترجمه یا بازنویسی نکنید.

این setup باید معماری مرجع AminPC را بازسازی کند:

```text
ChatGPT
  |
  | MCP connector: AminPC
  v
https://<PUBLIC_HOSTNAME>/mcp
  |
  | Cloudflare named tunnel
  v
http://127.0.0.1:8787/mcp
  |
  v
CodexPro 0.29.0
  |
  +-- workspace tools
  +-- bash -> codex sandbox -P :workspace -> Git Bash
  +-- host_exec / open_app -> direct Windows-user execution
```

## رفتار مرجع

- MCP فقط روی `127.0.0.1:8787` گوش می‌دهد.
- دسترسی عمومی از Cloudflare named tunnel با hostname پایدار انجام می‌شود.
- HTTP MCP authentication فعال است.
- نام connector در ChatGPT برابر `AminPC` است.
- CodexPro در mode `Agent` با `tool-mode=full`، `write=workspace` و `bash=full` اجرا می‌شود.
- Bash با وجود policy کامل، داخل Codex workspace sandbox باقی می‌ماند.
- `cwd=..` نباید بتواند از workspace root خارج شود.
- `CODEXPRO_INHERIT_ENV` فعال نمی‌شود.
- محیط محدود Windows فقط `USERPROFILE` و `TEMP` را به مجموعه ضروری اضافه می‌کند.
- `host_exec` و `open_app` خارج از sandbox و با Windows user فعلی اجرا می‌شوند.
- launcher مرجع host execution را به‌صورت پیش‌فرض روی `full-access` قرار می‌دهد.
- `full-access` محدودیت UAC یا Administrator ویندوز را دور نمی‌زند.

## نسخه‌های مرجع

| Component | Version |
|---|---:|
| Windows | Windows 11 |
| PowerShell | 7.6.4 |
| Bun | 1.3.14 |
| CodexPro | **0.29.0** |
| Codex CLI | 0.146.1 |
| Git for Windows | 2.55.0.windows.3 |
| cloudflared | 2026.7.3 |

برای بازسازی byte-for-byte، CodexPro را روی `0.29.0` pin کنید. patch anchorهای این راهنما برای version دیگری معتبر فرض نمی‌شوند.

## مقادیر deployment مرجع

| Item | مقدار مرجع |
|---|---|
| Windows user | `aminn` |
| Workspace عمومی PC | `C:\Users\aminn` |
| CodexPro state | `C:\Users\aminn\.codexpro` |
| Package | `C:\Users\aminn\.bun\install\global\node_modules\codexpro` |
| Git Bash | `C:\Program Files\Git\bin` |
| Local MCP | `http://127.0.0.1:8787/mcp` |
| Public hostname | `codexpro.futech-co.ir` |
| Tunnel name | `codexpro-local` |
| Connector | `AminPC` |
| Host mode | `full-access` |

روی ماشین دیگر hostname، tunnel name، token و user-specific pathها را تغییر دهید. tunnel ID را Cloudflare تولید می‌کند و نباید داخل launcher hardcode شود.

## مرز امنیتی

### Bash

```text
ChatGPT -> CodexPro bash -> codex sandbox -P :workspace -> Git Bash
```

`bashMode=full` به معنی خروج از sandbox نیست.

### Host execution

```text
ChatGPT -> CodexPro host_exec/open_app -> direct Windows spawn
```

Host execution:

- executable absolute می‌خواهد؛
- argv مستقیم می‌گیرد و shell command string ندارد؛
- `shell: false` است؛
- environment variableهای secret-like را filter می‌کند؛
- سه mode `off`، `on-request` و `full-access` دارد.

در `full-access` داشتن connector/token معتبر می‌تواند به اجرای مستقیم process با Windows user فعلی منجر شود. token و URL حاوی token باید secret در نظر گرفته شوند.

## پیش‌نیازها

نصب و بررسی کنید:

1. PowerShell 7
2. Bun
3. Git for Windows همراه Git Bash
4. Codex CLI با authentication معتبر
5. Cloudflare account با کنترل hostname مقصد

```powershell
pwsh --version
bun --version
git --version
codex --version
```

## نصب CodexPro pin‌شده

```powershell
bun add -g codexpro@0.29.0
codexpro --version
```

خروجی مورد انتظار:

```text
0.29.0
```

## ساخت state directory

```powershell
$CodexProDir = Join-Path $HOME '.codexpro'
New-Item -ItemType Directory -Path $CodexProDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'backups') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'bin') -Force | Out-Null
```

ساختار اصلی:

```text
~\.codexpro\
├── backups\
├── bin\
│   └── cloudflared.exe
├── http-token
├── Install-CodexProWorkspaceSandbox.ps1
└── Start-CodexPro.ps1
```

## ساخت HTTP MCP token

Token باید برای هر installation جدید دوباره تولید شود و هرگز commit نشود.

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

Token را در log چاپ نکنید.

## نصب و راه‌اندازی Cloudflare tunnel

Binary مرجع:

```text
$HOME\.codexpro\bin\cloudflared.exe
```

راه‌اندازی یک‌باره:

```powershell
$Cloudflared = "$HOME\.codexpro\bin\cloudflared.exe"
$TunnelName = 'codexpro-local'
$Hostname   = 'codexpro.futech-co.ir'

& $Cloudflared tunnel login
& $Cloudflared tunnel create $TunnelName
& $Cloudflared tunnel route dns $TunnelName $Hostname
& $Cloudflared tunnel list
```

Launcher از **tunnel name** استفاده می‌کند، نه tunnel ID.

## Patchهای Canonical

Stock package برای دو نیاز patch می‌شود:

1. **Windows Bash/Codex sandbox** — اجرای Git Bash از مسیر `codex sandbox -P :workspace` با environment محدود که `USERPROFILE` و `TEMP` را هم دارد.
2. **Host access** — اضافه شدن `host_exec` و `open_app` برای عملیات خارج از Codex sandbox.

سه artifact اصلی وجود دارند:

- `~\.codexpro\Install-CodexProWorkspaceSandbox.ps1`
- `dist\hostOps.js`
- `~\.codexpro\Start-CodexPro.ps1`

همچنین `dist\config.js` و `dist\server.js` با anchorهای مشخص patch می‌شوند.

**برای این قسمت از [نسخه canonical انگلیسی](https://ai-toolkit.qbit.click/ai-tools/codexpro/windows-setup#part-ii--canonical-custom-patches) استفاده کنید.** فایل‌های verbatim و hashها نباید در ترجمه دوباره تایپ شوند.

Hashهای مرجع:

| File | SHA-256 |
|---|---|
| `Install-CodexProWorkspaceSandbox.ps1` | `97C3BADBA08818BF9CA92BB56158542092F128710A5953664DB3334D13CBF38F` |
| `Start-CodexPro.ps1` | `34E495DCA2E3147633C191E95FD997EE8E211959D46EFA1DAB3A7DA2ED89A0DB` |
| `bashOps.js` | `3EB700D4C37A6B7470D29C9B2DC486D39DC69D7B9617154C244362381C2039AF` |
| `config.js` | `28A70D25251954159E6028090845ABA518C49515B0778894D63CBF68E74058BD` |
| `server.js` | `6549371A044C58C45EE02FE2508D0CBD4D6A80E8E2F95BD3AAFD060FAD1B67BD` |
| `hostOps.js` | `E95D7A02D55C2A0DD7CF9427B030C95D15B0E794A6F92E2A9B764C7C265E005F` |

## تابع `cpx`

در PowerShell 7 profile تابع `cpx` launcher را با workspace دلخواه اجرا می‌کند:

```powershell
function cpx {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Root = (Get-Location).Path
    )

    $Launcher = Join-Path (Join-Path $HOME '.codexpro') 'Start-CodexPro.ps1'
    & $Launcher -Root $Root
}
```

استفاده:

```powershell
cpx
cpx C:\Users\aminn
```

برای host mode متفاوت، launcher را مستقیم صدا بزنید:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -Root C:\Users\aminn -HostExecMode on-request
```

## شروع server و اتصال ChatGPT

برای workspace عمومی PC:

```powershell
cpx C:\Users\aminn
```

برای پروژه مشخص، root محدودتر بهتر است:

```powershell
cpx D:\Projects\ExampleProject
```

Local MCP باید گزارش کند:

```text
HTTP MCP listening on http://127.0.0.1:8787/mcp
```

Connector در ChatGPT:

| Field | مقدار |
|---|---|
| Name | `AminPC` |
| Server URL | URL exact که CodexPro در runtime تولید می‌کند |
| Authentication | `None` |
| Permissions | فقط actionهای لازم workflow |

URL تولیدشده token را داخل خود دارد و باید secret تلقی شود.

## Verification

### `server_config`

مقادیر مهم مرجع:

```text
host                 = 127.0.0.1
port                 = 8787
authEnabled          = true
bashMode             = full
bashTranscript       = compact
hostExecMode         = full-access
writeMode            = workspace
toolMode             = full
inheritEnv           = false
registeredToolCount  = 28
```

Toolهای custom مورد انتظار:

```text
host_exec
open_app
```

### Workspace containment

با root برابر:

```text
C:\Users\aminn
```

درخواست با:

```text
cwd = ..
```

باید با خطایی معادل زیر رد شود:

```text
Path escapes workspace root: ..
```

### Sandbox Bash

`pwd` در workspace مرجع باید به:

```text
/c/Users/aminn
```

resolve شود و Bash از `codex sandbox -P :workspace` عبور کند.

### Restricted environment

Sandbox باید `USERPROFILE` و `TEMP` داشته باشد و به `CODEXPRO_INHERIT_ENV=1` نیاز نداشته باشد.

### Full Access host execution

`host_exec` را با executable زیر تست کنید:

```text
C:\Windows\System32\whoami.exe
```

انتظار:

- execution موفق؛
- user واقعی Windows در خروجی؛
- `approval=full-access`؛
- بدون popup approval در mode پیش‌فرض.

سپس `open_app` را با یک GUI harmless تست کنید.

### Cloudflare tunnel

Endpoint محلی:

```text
http://127.0.0.1:8787/healthz
```

باید HTTP 200 بدهد. اگر QUIC در دسترس نیست، HTTP/2 tunnel معتبر است و failure صرف QUIC blocker نیست.

## Update policy

CodexPro را blind update نکنید. این setup فایل‌های package را زیر مسیر زیر تغییر می‌دهد:

```text
~\.bun\install\global\node_modules\codexpro\dist
```

قبل از update:

1. version فعلی را ثبت کنید؛
2. `~\.codexpro` را backup کنید؛
3. فایل‌های patched `dist` را backup کنید؛
4. version جدید را نصب کنید؛
5. implementation آن را با patch anchorهای runbook مقایسه کنید؛
6. patchها را برای build جدید دوباره validate کنید؛
7. کل acceptance testها را اجرا کنید؛
8. فقط بعد از موفقیت connector production را جابه‌جا کنید.

برای rebuild deterministic اضطراری:

```powershell
bun add -g codexpro@0.29.0
```

## Workspace policy

Connector عمومی مرجع root بزرگی مانند `C:\Users\aminn` دارد، اما برای project work بهتر است root محدودتر باز شود:

```powershell
cpx D:\Projects\MyProject
```

از recursive scan کل user profile تا حد امکان پرهیز کنید؛ folderهای phone/cloud-backed می‌توانند download جانبی trigger کنند.

## خلاصه مدل امنیتی

```text
Bash:
  full command policy
  + Codex workspace sandbox
  + restricted environment

Host execution:
  direct executable + argv
  shell: false
  filtered environment
  default full-access
  no UAC bypass

Remote exposure:
  localhost MCP
  + bearer token
  + Cloudflare named tunnel
```

حساس‌ترین artifact در mode `full-access` همان MCP token و connector URL حاوی token است.

## Acceptance checklist

- [ ] `codexpro --version` برابر `0.29.0` است.
- [ ] named tunnel hostname صحیح را resolve می‌کند.
- [ ] `/healthz` محلی HTTP 200 می‌دهد.
- [ ] MCP token وجود دارد و commit نشده است.
- [ ] sandbox installer idempotent است.
- [ ] فایل‌های verbatim با hashهای مرجع match هستند.
- [ ] `server_config` مقادیر `toolMode=full`، `writeMode=workspace`، `bashMode=full` و `hostExecMode=full-access` را گزارش می‌کند.
- [ ] `inheritEnv=false` است.
- [ ] 28 tool در full mode ثبت شده‌اند.
- [ ] `host_exec` و `open_app` وجود دارند.
- [ ] `cwd=..` توسط workspace boundary رد می‌شود.
- [ ] `pwd` به workspace انتخاب‌شده resolve می‌شود.
- [ ] sandbox بدون full host environment inheritance کار می‌کند.
- [ ] `USERPROFILE` و `TEMP` در sandbox Windows موجودند.
- [ ] `whoami.exe` از `host_exec` بدون approval popup در full-access موفق است.
- [ ] یک GUI harmless با `open_app` اجرا می‌شود.
- [ ] connector `AminPC` یک loop کامل read → edit/write → verification را انجام می‌دهد.
- [ ] هیچ token یا token-bearing URL در repository ذخیره نشده است.

## اجرای نهایی canonical

```powershell
cpx C:\Users\aminn
```

برای exact patch source، line-ending notes و forensic hash guidance به [نسخه canonical انگلیسی](https://ai-toolkit.qbit.click/ai-tools/codexpro/windows-setup) مراجعه کنید.
