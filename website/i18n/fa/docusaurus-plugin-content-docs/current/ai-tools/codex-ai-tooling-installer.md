---
id: codex-ai-tooling-installer
title: استفاده از Installer ابزارهای Codex AI
sidebar_label: راهنمای Installer
---

# استفاده از Installer ابزارهای Codex AI

`installer.codex-ai-tooling` یک محیط توسعه AI نسخه‌دار و تحت مالکیت repository را داخل یک Git work tree موجود نصب می‌کند. این installer فقط configuration و runtime مربوط به tooling را مدیریت می‌کند و application dependency نصب نمی‌کند، user-level Codex config را تغییر نمی‌دهد و مالک فایل‌های نامرتبط پروژه نمی‌شود.

## چه چیزهایی نصب می‌شوند؟

Payload شامل این موارد است:

- Codex MCP configuration مختص repository؛
- Serena با tool allowlist محدود برای semantic code work؛
- wrapperهای Graphify با scope صریح برای architecture analysis؛
- Context7 اختیاری برای مستندات خارجی؛
- Sentry اختیاری و read-only برای incident واقعی؛
- Docker/Compose runtime؛
- bootstrap و Doctor؛
- routing policy و skillهای agent؛
- documentation محلی AI tooling؛
- ownership state برای update، repair، verify و uninstall امن.

Browser/Playwright نصب نمی‌شود.

## Profileهای پشتیبانی‌شده

| Profile | نحوه انتخاب | Runtime معنایی |
| --- | --- | --- |
| `auto` | تشخیص از metadata ریشه پروژه | یکی از profileهای زیر |
| `generic` | انتخاب صریح یا fallback | PowerShell، Bash و Python |
| `typescript` | `tsconfig.json` یا metadata TypeScript در ریشه | TypeScript 5.9.3 و TypeScript Language Server 5.1.3 به‌علاوه زبان‌های مشترک |
| `rust` | `Cargo.toml` در ریشه | Rust 1.85.0 و `rust-analyzer` به‌علاوه زبان‌های مشترک |

اگر metadata TypeScript و Rust هر دو وجود داشته باشند، `auto` ابتدا TypeScript را انتخاب می‌کند.

## پیش‌نیازها

Target باید یک Git work tree موجود باشد. برای bootstrap و Doctor کامل همچنین نیاز است:

- Docker با backend لینوکس `amd64`؛
- Docker Compose نسخه 2 یا بالاتر؛
- PowerShell روی Windows یا POSIX shell روی Linux/macOS؛
- Codex برای استفاده از MCP configuration نصب‌شده.

Installer برای نصب dependencyهای application به package manager پروژه نیاز ندارد.

## ابتدا Plan بگیرید

`plan` read-only است و بهتر است اولین operation باشد.

### PowerShell

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

### POSIX

```bash
./installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /projects/example/backend \
  --profile auto
```

برای automation از JSON استفاده کنید:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto `
  -Format json `
  -NonInteractive
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /projects/example/backend \
  --profile auto \
  --format json \
  --non-interactive
```

## Install

### PowerShell

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

### POSIX

```bash
./installers/codex-ai-tooling/install.sh \
  --operation install \
  --target /projects/example/backend \
  --profile auto
```

در حالت پیش‌فرض، installer payload را می‌نویسد، image مربوط به tooling را build می‌کند، volumeهای state/resource مربوط به Serena را بدون راه‌اندازی MCP service آماده می‌کند و سپس Doctor را اجرا می‌کند. برای CI یا deployment مرحله‌ای می‌توان bootstrap و Doctor را جدا کرد:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -Profile typescript `
  -SkipBootstrap `
  -SkipDoctor
```

بعداً entrypointهای نصب‌شده را اجرا کنید:

```powershell
& 'D:\Projects\Example\backend\.ai\scripts\bootstrap.ps1'
& 'D:\Projects\Example\backend\.ai\scripts\doctor.ps1'
```

```bash
/projects/example/backend/.ai/scripts/bootstrap.sh
/projects/example/backend/.ai/scripts/doctor.sh
```

## هویت پروژه و Allowed Origin

Project slug و display name به‌صورت پیش‌فرض استخراج می‌شوند، اما قابل تعیین هستند:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -ProjectSlug example-backend `
  -ProjectDisplayName 'Example Backend' `
  -AllowedOrigin 'http://localhost:3000','http://127.0.0.1:3000'
```

فقط origin صریح HTTP/HTTPS پذیرفته می‌شود. wildcard، credential، fragment و مقدار relative رد می‌شوند.

## Verify

`verify` static و ownership-driven است؛ state و managed fileها را بدون اجرای diagnostics کامل container بررسی می‌کند.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation verify -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation verify --target /projects/example/backend
```

## Doctor

`doctor` ابتدا ownership را verify می‌کند و سپس runtime ایزوله را بررسی می‌کند: identity، security boundary، versionهای exact، MCP initialize/tool allowlist، semantic smoke check، Graphify CLI و عدم تغییر persistent state.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation doctor -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation doctor --target /projects/example/backend
```

Authentication مربوط به Context7 یا Sentry اختیاری است و local Serena/Graphify health را block نمی‌کند.

## Update

بعد از جایگزینی installer با payload جدید سازگار، `update` را اجرا کنید. این operation به ownership state معتبر نیاز دارد.

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation update `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation update \
  --target /projects/example/backend \
  --profile auto
```

Profile migration transactional است؛ مثلاً migration از TypeScript به Rust فقط فایل‌های profile قبلی را که واقعاً installer-owned هستند حذف و فایل‌های profile جدید را اضافه می‌کند.

## Repair

`repair` فقط در صورت وجود ownership evidence معتبر payload فعلی را دوباره اعمال می‌کند و فایل نامرتبط را adopt نمی‌کند.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation repair -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation repair --target /projects/example/backend
```

## فایل Installer-owned که توسط کاربر تغییر کرده است

Policy پیش‌فرض fail-closed است. اگر یک فایل owned بعد از نصب تغییر کند، installer آن را خاموش overwrite نمی‌کند.

پس از review conflict می‌توان `replace` را انتخاب کرد تا فایل previously-owned ابتدا backup و سپس replace شود:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation repair `
  -Target 'D:\Projects\Example\backend' `
  -OwnedModified replace
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation repair \
  --target /projects/example/backend \
  --owned-modified replace
```

این policy اجازه overwrite کردن path بدون ownership قبلی را نمی‌دهد.

## Uninstall

Uninstall بر اساس state انجام می‌شود و فقط محتوای installer-owned را حذف می‌کند. متن project-owned خارج از managed block در `AGENTS.md`، `.gitignore` و `.gitattributes` باقی می‌ماند.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation uninstall -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation uninstall --target /projects/example/backend
```

برای preview از `-DryRun` یا `--dry-run` استفاده کنید.

## استفاده از Serena

Repository را در Codex trust کنید و یک session جدید از root همان repository باز کنید تا `.codex/config.toml` project-scoped load شود.

Serena برای taskهایی مانند declaration، symbol، reference، implementation، diagnostic و edit معنایی صریح استفاده می‌شود. خواندن فایل معمولی، Git، test و literal edit معلوم همچنان باید با ابزارهای عادی انجام شود.

Compose می‌تواند image pin‌شده را در اولین استفاده به‌صورت lazy build کند. Progress مربوط به Compose از stdout پروتکل MCP جدا نگه داشته می‌شود.

## استفاده از Graphify

Graphify MCP server نیست. فقط wrapperهای نصب‌شده را استفاده کنید و scope repository-relative صریح بدهید.

Build یا reuse یک scope:

```powershell
.\.ai\scripts\graphify-build.ps1 -Scope 'src/payments'
```

```bash
./.ai/scripts/graphify-build.sh src/payments
```

Query همان scope:

```powershell
.\.ai\scripts\graphify-query.ps1 `
  -Scope 'src/payments' `
  -Question 'Which modules depend on the retry policy?'
```

```bash
./.ai/scripts/graphify-query.sh src/payments 'Which modules depend on the retry policy?'
```

Rebuild اجباری:

```powershell
.\.ai\scripts\graphify-update.ps1 -Scope 'src/payments'
```

Graph یک derived evidence است؛ نتیجه material را با source و در صورت نیاز Serena validate کنید.

## Context7 و Sentry

Context7 فقط برای مستندات خارجی version-specific است. ابتدا version واقعی dependency را از manifest/lockfile پیدا کنید.

Sentry اختیاری و محدود به toolهای read-only configured است و فقط برای incident واقعی استفاده می‌شود. هیچ‌کدام شرط سلامت local tooling نیستند. Authentication خارج از repository committed مدیریت می‌شود.

## Installer چه کاری انجام نمی‌دهد؟

Installer این کارها را انجام نمی‌دهد:

- اجرای `npm install`، `pnpm install`، `yarn install` یا `bun install` مربوط به application؛
- اجرای `cargo build`، `cargo fetch` یا `cargo install` در target repository؛
- نصب global Serena، Graphify، TypeScript tooling، Rust tooling یا browser tooling؛
- stage، commit، stash، reset، clean یا push کردن Git؛
- overwrite کردن conflict بدون ownership؛
- تغییر user/global Codex configuration؛
- expose کردن Docker socket یا privileged container.

## مسیرهای Ownership و Recovery

State سازگار با contract نسخه 1.0:

```text
.qbit/toolkit/installed/codex-ai-tooling.json
```

Transaction، recovery و backup evidence:

```text
.qbit-toolkit/codex-ai-tooling/
```

تا زمانی که installer نصب است این pathها را دستی حذف نکنید.

## Flow پیشنهادی برای Automation

```text
plan --format json
-> بررسی exit code و conflict
-> install/update/repair --format json
-> verify
-> doctor در صورت نیاز به runtime validation
```

Caller باید exit code و JSON result خود installer را حفظ کند و ownership/transaction logic را دوباره پیاده‌سازی نکند.
