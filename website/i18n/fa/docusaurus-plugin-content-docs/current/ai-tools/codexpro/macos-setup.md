---
id: macos-setup
title: راه‌اندازی CodexPro روی macOS
sidebar_label: راه‌اندازی macOS
---

# راه‌اندازی CodexPro روی macOS

این راهنما CodexPro را روی macOS راه‌اندازی می‌کند، بدون اینکه مدل Mac، username، repository path، DNS hostname، tunnel provider، shell customization یا JavaScript package manager خاصی را فرض کند.

Flow معمول:

```text
نصب CodexPro
      ↓
ورود به repository هدف
      ↓
codexpro setup
      ↓
codexpro start
      ↓
کپی MCP Server URL تولیدشده
      ↓
اتصال ChatGPT
      ↓
doctor / connection-test / verification
```

## پیش‌نیازها

قبل از شروع موارد زیر را verify کنید:

1. یک macOS پشتیبانی‌شده؛
2. **Node.js 20 یا جدیدتر**؛
3. یک package manager سازگار برای نصب package `codexpro`؛
4. Git؛
5. Codex CLI در workflowهایی که از Bash/sandbox مبتنی بر Codex استفاده می‌کنند؛
6. ChatGPT account با امکان ساخت custom MCP integration؛
7. HTTPS route وقتی ChatGPT web باید از راه دور به Mac برسد.

```bash
node --version
git --version
codex --version 2>/dev/null || true
```

Node.js می‌تواند با version manager، Homebrew، MacPorts، سیستم توزیع نرم‌افزار سازمانی یا روش کنترل‌شده دیگری نصب شود. CodexPro به installer خاص Node وابسته نیست.

## نصب CodexPro

Command مرجع upstream از npm استفاده می‌کند:

```bash
npm install -g codexpro
```

Package manager دیگر نیز قابل استفاده است اگر version موردنظر را نصب کند و executable `codexpro` را روی `PATH` قرار دهد.

```bash
# npm
npm install -g codexpro

# pnpm
pnpm add -g codexpro

# Bun
bun add -g codexpro

# Yarn Classic
# yarn global add codexpro
```

نتیجه را مستقل از storage layout package manager verify کنید:

```bash
codexpro --version
command -v codexpro
```

Global package path مربوط به Mac توسعه‌دهنده دیگری را در مستند یا reusable script hardcode نکنید.

## Initialize کردن repository

وارد repository موردنظر شوید:

```bash
cd /path/to/your/repository
```

سپس:

```bash
codexpro setup
```

Allowed workspace را تا حد ممکن محدود نگه دارید. Project root را به کل home directory ترجیح دهید.

## اجرای CodexPro

برای استفاده روزمره:

```bash
codexpro start
```

برای تعیین صریح repository:

```bash
codexpro start --root /path/to/your/repository
```

Modeهای مفید:

```bash
codexpro start --no-bash
codexpro start --tool-mode minimal
codexpro start --tool-mode full
codexpro start --mode handoff
codexpro start --mode pro
codexpro start --headless
```

کم‌اختیارترین mode لازم برای task را انتخاب کنید.

## حالت local-only

```bash
codexpro start --tunnel none
```

این حالت برای local validation یا محیطی مناسب است که HTTPS/reverse proxy را جداگانه مدیریت می‌کند.

Raw local MCP listener را بدون transport و authentication control مناسب مستقیماً public نکنید.

## گزینه‌های Public HTTPS

ChatGPT web برای دسترسی به MCP به HTTPS route نیاز دارد.

### Cloudflare tunnel موقت

```bash
codexpro start --tunnel cloudflare
```

برای test یا evaluation کوتاه‌مدت مناسب است که تغییر URL عمومی قابل قبول باشد.

### Cloudflare hostname پایدار

ابتدا token state پایدار بسازید:

```bash
mkdir -p ~/.codexpro
openssl rand -hex 32 > ~/.codexpro/http-token
chmod 600 ~/.codexpro/http-token
```

سپس:

```bash
codexpro stable \
  --hostname codexpro.example.com \
  --tunnel-name codexpro
```

Hostname و tunnel name را با مقادیر deployment خودتان جایگزین کنید.

### ngrok

```bash
codexpro ngrok --hostname your.ngrok-free.dev
```

### Tailscale

```bash
codexpro tailscale --hostname your-device.your-tailnet.ts.net
```

فقط account و hostname متعلق به deployment خودتان را استفاده کنید.

## اتصال ChatGPT

بعد از startup، Server URL دقیق emitشده توسط CodexPro را کپی کنید.

Custom MCP integration را با مقادیر deployment خودتان بسازید:

| Field | مقدار |
|---|---|
| Name | یک نام واضح و deployment-specific |
| Server URL | URL دقیق تولیدشده توسط CodexPro |
| Authentication | mode موردنیاز endpoint |
| Permissions | فقط actionهای لازم workflow |

اگر Server URL حاوی CodexPro token است، کل URL secret است.

آن را در screenshot عمومی، Git history، issue، documentation example یا terminal transcript قابل انتشار قرار ندهید.

## Verification

```bash
codexpro doctor
```

اگر connection کار نمی‌کند:

```bash
codexpro connection-test
```

در صورت نیاز setup فعلی را inspect کنید:

```bash
codexpro settings
codexpro inspect
codexpro review
```

Acceptance test حداقلی باید ثابت کند:

- repository درست باز می‌شود؛
- file read/search داخل allowed rootها می‌ماند؛
- write toolها فقط طبق write policy ظاهر می‌شوند؛
- Bash مطابق mode انتخاب‌شده است؛
- pathهای حساس block هستند؛
- HTTPS route به همین CodexPro process وصل است؛
- ChatGPT روی disposable repository یک loop کامل read → controlled edit → verification انجام می‌دهد.

## چند repository

```bash
codexpro settings set \
  --project ~/code/web \
  --project ~/code/api

codexpro settings show
codexpro start
```

در ChatGPT فقط repository موردنیاز task را انتخاب کنید.

برای account یا security domain جدا، process و Server URL جدا بهتر از یک process با دسترسی خیلی broad است.

## راهنمای filesystem در macOS

Rootهای محدود مثل این‌ها مناسب‌ترند:

```text
~/Developer/my-project
~/Projects/my-project
/Users/<user>/code/my-project
```

به‌جای rootهای broad مثل:

```text
/
/Users
~
```

فقط برای دور زدن انتخاب root صحیح، Full Disk Access ندهید. Permission گسترده‌تر باید یک تصمیم امنیتی آگاهانه باشد نه workaround troubleshooting.

macOS privacy control ممکن است بسته به terminal/runtime، دسترسی به Desktop، Documents، Downloads، removable volume یا locationهای protected را محدود کند. در صورت access denied ابتدا location repository و privacy permission process اجراکننده را بررسی کنید، بعد سراغ گسترده کردن authority بروید.

## Shell و PATH

در macOS مدرن معمولاً shell تعاملی `zsh` است، اما processهای GUI یا supervised ممکن است `PATH` متفاوتی دریافت کنند.

```bash
command -v codexpro
which codexpro
printf '%s\n' "$PATH"
```

اگر CodexPro در Terminal کار می‌کند ولی در service یا shell دیگر نه، environment همان process را صریح configure کنید. برای گرفتن binary path کل interactive profile حاوی credentialهای نامرتبط را source نکنید.

## Apple Silicon و Intel

CodexPro یک Node.js package است؛ مهم این است که Node.js runtime و هر native tool خارجی با architecture Mac سازگار باشند.

```bash
uname -m
```

خروجی‌های معمول:

```text
arm64
x86_64
```

اگر tunnel binary یا native dependency اجرا نمی‌شود، architecture همان binary را بررسی کنید نه اینکه repository permission CodexPro را تغییر دهید.

## اجرای headless

```bash
codexpro start --headless
```

Headless mode را بعد از setup و validation تعاملی فعال کنید.

اگر بعداً از `launchd` یا supervisor دیگر استفاده می‌کنید:

- working directory صریح تعیین کنید؛
- environment و `PATH` حداقلی و مشخص بدهید؛
- token را تا حد ممکن خارج از plist/repository نگه دارید؛
- با user موردنظر اجرا کنید نه root؛
- secret را در stdout/stderr چاپ نکنید؛
- قبل از auto-restart tunnel و repository access را verify کنید.

`launchd` plist دقیق deployment-specific است و نباید username، project path، token یا hostname شخصی را در مستند reusable hardcode کند.

## Update

فرم upstream با npm:

```bash
npm install -g codexpro@latest
codexpro --version
```

با pnpm، Bun، Yarn یا package manager سازگار دیگر از command معادل همان ابزار استفاده کنید.

بعد از update:

1. version جدید را ثبت کنید؛
2. CodexPro را restart کنید؛
3. `codexpro doctor` را اجرا کنید؛
4. اگر remote route درگیر است `codexpro connection-test` را اجرا کنید؛
5. workspace/write/Bash boundaryها را دوباره verify کنید؛
6. هر source patch version-specific را قبل از apply روی build جدید دوباره review کنید.

## Troubleshooting

### `codexpro: command not found`

```bash
command -v codexpro
printf '%s\n' "$PATH"
```

Global executable directory package manager خودتان را بررسی کنید. Path Mac دیگری را کپی نکنید.

### در یک Terminal کار می‌کند و در دیگری نه

```bash
which node
which codexpro
printf '%s\n' "$PATH"
```

Version manager و GUI-launched shellها ممکن است environment متفاوتی initialize کنند. Runtime selection را explicit کنید.

### ChatGPT وصل نمی‌شود

```bash
codexpro connection-test
```

سپس بررسی کنید:

- process هنوز running است؛
- tunnel healthy است؛
- hostname به route صحیح اشاره می‌کند؛
- Server URL در ChatGPT current است؛
- token state عوض نشده؛
- firewall، VPN یا network policy مانع tunnel نیست.

### Repository access بیش از حد broad است

```bash
codexpro start --root /path/to/specific/repository
```

### macOS به folder دسترسی نمی‌دهد

فوراً Full Disk Access گسترده فعال نکنید. Location repository و privacy permission terminal/runtime اجراکننده CodexPro را بررسی کنید.

### Bash لازم نیست

```bash
codexpro start --no-bash
```

## Acceptance checklist

- [ ] Node.js 20+ نصب است.
- [ ] `codexpro` بدون وابستگی به storage layout user دیگر روی `PATH` resolve می‌شود.
- [ ] repository انتخاب‌شده allowed workspace صریح است.
- [ ] `codexpro setup` کامل می‌شود.
- [ ] `codexpro doctor` پاس می‌شود یا فقط warningهای environment-specific شناخته‌شده دارد.
- [ ] local-only یا public HTTPS مطابق deployment است.
- [ ] Public access از authentication/token model درست استفاده می‌کند.
- [ ] Token و URL حاوی token commit یا publish نشده‌اند.
- [ ] macOS filesystem/privacy permission از مقدار لازم گسترده‌تر نیست.
- [ ] ChatGPT به process صحیح متصل می‌شود.
- [ ] read/write داخل allowed rootها باقی می‌مانند.
- [ ] Bash/write tools مطابق policy انتخاب‌شده‌اند.
- [ ] E2E روی disposable repository پاس می‌شود.

## قانون عملیاتی پیشنهادی

CodexPro را یک **repository-scoped development bridge** بدانید، نه مکانیزم remote-control عمومی برای Mac. Workspace را محدود، OS permissionها را حداقل، credentialها را private و public route را فقط به process و repository موردنظر متصل نگه دارید.
