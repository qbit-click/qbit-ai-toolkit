---
id: linux-setup
title: راه‌اندازی CodexPro روی Linux
sidebar_label: راه‌اندازی Linux
---

# راه‌اندازی CodexPro روی Linux

این راهنما CodexPro را روی یک workstation یا development host لینوکسی راه‌اندازی می‌کند، بدون اینکه distribution، username، repository، DNS hostname، tunnel provider یا JavaScript package manager خاصی را فرض کند.

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

1. Linux با runtime پشتیبانی‌شده Node.js؛
2. **Node.js 20 یا جدیدتر**؛
3. یک package manager سازگار برای نصب package `codexpro`؛
4. Git؛
5. Codex CLI در workflowهایی که از Bash/sandbox مبتنی بر Codex استفاده می‌کنند؛
6. ChatGPT account با امکان ساخت custom MCP integration؛
7. یک HTTPS route وقتی ChatGPT web باید به machine محلی دسترسی داشته باشد.

```bash
node --version
git --version
codex --version 2>/dev/null || true
```

Node.js می‌تواند از package manager توزیع، version manager، development container یا هر روش کنترل‌شده دیگری نصب شود. Contract مهم version پشتیبانی‌شده Node است، نه installer خاص.

## نصب CodexPro

Command مرجع upstream از npm استفاده می‌کند:

```bash
npm install -g codexpro
```

اما setup نباید به storage layout npm وابسته باشد. هر package manager سازگاری که package موردنظر را نصب و executable `codexpro` را روی `PATH` قرار دهد قابل استفاده است.

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

نتیجه را مستقل از package manager بررسی کنید:

```bash
codexpro --version
command -v codexpro
```

Global package path مربوط به یک package manager خاص را داخل reusable script hardcode نکنید، مگر اینکه یک patch workflow version-specific واقعاً به package fileها نیاز داشته باشد.

## Initialize کردن repository

وارد repositoryای شوید که ChatGPT باید اجازه کار روی آن را داشته باشد:

```bash
cd /path/to/your/repository
```

سپس:

```bash
codexpro setup
```

Configuration پروژه را تا حد ممکن در scope خود repository یا CodexPro state نگه دارید و از وابسته کردن setup به shell profile عمومی user خودداری کنید.

## اجرای CodexPro

برای استفاده روزمره از همان repository:

```bash
codexpro start
```

برای تعیین صریح root:

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

کم‌اختیارترین modeای را انتخاب کنید که workflow را کامل می‌کند.

## حالت local-only

اگر server فقط روی همان machine باید قابل دسترسی باشد:

```bash
codexpro start --tunnel none
```

این حالت برای local testing، reverse proxy مدیریت‌شده توسط خودتان یا محیطی که tunnel خارجی لازم ندارد مناسب است.

Raw MCP listener را بدون authentication و transport control مناسب مستقیماً روی Internet منتشر نکنید.

## گزینه‌های Public HTTPS

ChatGPT web برای دسترسی به MCP به یک HTTPS URL نیاز دارد.

### Cloudflare tunnel موقت

```bash
codexpro start --tunnel cloudflare
```

برای evaluation مناسب است، اما URL عمومی ممکن است بین sessionها تغییر کند.

### Cloudflare hostname پایدار

ابتدا token پایدار بسازید:

```bash
mkdir -p ~/.codexpro
openssl rand -hex 32 > ~/.codexpro/http-token
chmod 600 ~/.codexpro/http-token
```

سپس با مقادیر deployment خودتان اجرا کنید:

```bash
codexpro stable \
  --hostname codexpro.example.com \
  --tunnel-name codexpro
```

Hostname و tunnel name را با مقادیر واقعی environment خودتان جایگزین کنید. Token یا URL حاوی token را در documentation یا repository عمومی قرار ندهید.

### ngrok

```bash
codexpro ngrok --hostname your.ngrok-free.dev
```

### Tailscale

```bash
codexpro tailscale --hostname your-device.your-tailnet.ts.net
```

فقط hostname و account متعلق به deployment خودتان را استفاده کنید.

## اتصال ChatGPT

بعد از start شدن CodexPro، Server URL دقیق تولیدشده توسط runtime را کپی کنید.

در ChatGPT custom MCP integration/plugin را با مقادیر deployment خودتان بسازید:

| Field | مقدار |
|---|---|
| Name | یک نام واضح و deployment-specific |
| Server URL | URL دقیق تولیدشده توسط CodexPro |
| Authentication | mode موردنیاز endpoint |
| Permissions | فقط actionهای لازم workflow |

اگر URL شامل CodexPro token است، **کل URL secret است**.

آن را در این موارد ذخیره نکنید:

- Git؛
- issue tracker؛
- screenshot عمومی؛
- CI log؛
- terminal transcript قابل انتشار.

## Verification

Diagnostic داخلی را اجرا کنید:

```bash
codexpro doctor
```

اگر ChatGPT به connector وصل نمی‌شود:

```bash
codexpro connection-test
```

در صورت نیاز configuration effective را بررسی کنید:

```bash
codexpro settings
codexpro inspect
codexpro review
```

Acceptance test حداقلی باید ثابت کند:

- repository انتخاب‌شده باز می‌شود؛
- read/search داخل allowed rootها باقی می‌ماند؛
- write toolها فقط در write mode مجاز advertise می‌شوند؛
- Bash مطابق policy انتخاب‌شده کار می‌کند؛
- pathهای حساس مثل secretها و Git internals محافظت می‌شوند؛
- HTTPS endpoint به process درست route می‌شود؛
- ChatGPT روی یک disposable test repository یک loop کامل read → controlled edit → verification انجام می‌دهد.

## چند repository

یک CodexPro process می‌تواند چند project صریح را allow کند:

```bash
codexpro settings set \
  --project ~/code/web \
  --project ~/code/api

codexpro settings show
codexpro start
```

در ChatGPT فقط repository موردنیاز task فعلی را باز کنید. Home directory کامل را به‌عنوان workspace عمومی expose نکنید.

برای isolation قوی‌تر بین accountها یا trust zoneهای مختلف، process و Server URL جدا استفاده کنید.

## راهنمای filesystem و permission در Linux

Rootهای محدود مثل این‌ها مناسب‌ترند:

```text
~/code/my-project
/opt/workspaces/my-project
/srv/dev/my-project
```

و از rootهای بسیار broad مثل این‌ها پرهیز کنید:

```text
/
/home
/home/<user>
```

CodexPro باید با همان developer/service accountی اجرا شود که واقعاً اجازه دسترسی به repository را دارد. فقط برای دور زدن permission problem آن را با `root` اجرا نکنید.

اگر repository به write دسترسی درست ندارد، ownership/ACL را اصلاح کنید نه اینکه privilege CodexPro را گسترده‌تر کنید.

## Shell و PATH

محل shim مربوط به `codexpro` به package manager و روش نصب Node وابسته است.

```bash
command -v codexpro
readlink -f "$(command -v codexpro)" 2>/dev/null || true
```

در serviceها و non-interactive shellها ممکن است `PATH` با terminal متفاوت باشد. Environment لازم را صریح configure کنید و برای گرفتن یک binary path کل shell profile حاوی credentialهای نامرتبط را source نکنید.

## اجرای headless

```bash
codexpro start --headless
```

این mode را فقط بعد از interactive validation فعال کنید. اگر بعداً CodexPro را داخل systemd، container یا supervisor دیگری قرار دادید:

- در صورت امکان با non-root account اجرا کنید؛
- working directory صریح تعیین کنید؛
- فقط environment variableهای لازم را پاس دهید؛
- credentialها را خارج از repository/unit file نگه دارید؛
- restart policy را طوری تنظیم کنید که config خراب loop سریع failure ایجاد نکند؛
- token را در log چاپ نکنید.

Supervisor config دقیق environment-specific است و نباید از server دیگری کورکورانه کپی شود.

## Update

در npm، شکل upstream برای update:

```bash
npm install -g codexpro@latest
codexpro --version
```

در package manager دیگر، معادل global update/install همان ابزار را استفاده کنید.

بعد از update:

1. version جدید را ثبت کنید؛
2. process را restart کنید؛
3. `codexpro doctor` را اجرا کنید؛
4. اگر route یا connector مشکل دارد `codexpro connection-test` را اجرا کنید؛
5. workspace/write/Bash boundaryها را دوباره تست کنید؛
6. patchهای version-specific را قبل از reapply دوباره review کنید.

## Troubleshooting

### `codexpro: command not found`

```bash
command -v codexpro
printf '%s\n' "$PATH"
```

Global binary directory package manager فعلی را بررسی کنید. Path user دیگری را hardcode نکنید.

### ChatGPT وصل نمی‌شود

```bash
codexpro connection-test
```

سپس بررسی کنید:

- process هنوز در حال اجراست؛
- HTTPS route فعال است؛
- DNS به tunnel درست اشاره می‌کند؛
- firewall/network policy مانع tunnel نیست؛
- Server URL در ChatGPT همان URL فعلی است؛
- token rotate نشده یا connector با token قدیمی باقی نمانده است.

### Repository access بیش از حد broad است

```bash
codexpro start --root /path/to/specific/repository
```

### Bash لازم نیست

```bash
codexpro start --no-bash
```

### Write toolها نباید advertise شوند

از mode مناسب non-writing/handoff استفاده کنید و advertised tool list را بعد از تغییر mode verify کنید. Prompt instruction به‌تنهایی boundary امنیتی نیست.

## Acceptance checklist

- [ ] Node.js 20+ نصب است.
- [ ] `codexpro` مستقل از storage layout package manager روی `PATH` resolve می‌شود.
- [ ] repository هدف یک allowed workspace صریح است.
- [ ] `codexpro setup` برای repository کامل می‌شود.
- [ ] `codexpro doctor` pass می‌شود یا فقط warningهای environment-specific شناخته‌شده دارد.
- [ ] local-only یا public HTTPS مطابق deployment انتخاب شده است.
- [ ] Public connection از token مناسب استفاده می‌کند.
- [ ] token و URL حاوی token commit یا publish نشده‌اند.
- [ ] ChatGPT به Server URL صحیح متصل می‌شود.
- [ ] read/write داخل allowed rootها باقی می‌مانند.
- [ ] Bash/write capability مطابق policy انتخاب‌شده است.
- [ ] E2E روی disposable repository پاس می‌شود.

## قانون عملیاتی پیشنهادی

CodexPro را یک **repository-scoped local development service** در نظر بگیرید، نه remote shell عمومی برای Linux host. Workspace را محدود، credentialها را private، privilegeها را حداقل و tunnel را فقط به process موردنظر متصل نگه دارید.
