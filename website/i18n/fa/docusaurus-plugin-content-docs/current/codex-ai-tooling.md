---
id: codex-ai-tooling
title: Codex AI Tooling
sidebar_label: Codex AI Tooling
sidebar_position: 3
---

# Codex AI Tooling

`installer.codex-ai-tooling` اولین asset عملیاتی Qbit AI Toolkit است. این installer یک محیط repository-owned شامل Serena، Graphify و Doctor را در Git work tree موجود نصب می‌کند، بدون اضافه کردن dependency به application یا تغییر user-level Codex configuration.

## hostها و profileها

manifest فعلی Windows، Linux و macOS و profileهای زیر را اعلام می‌کند:

- `auto`: تشخیص profile هدف.
- `generic`: baseline مستقل از زبان.
- `typescript`: profile مخصوص TypeScript.
- `rust`: profile مخصوص Rust.

Profileهای `generic`، `typescript` و `rust` اکنون template و runtime contract واقعی دارند. TypeScript با TypeScript 5.9.3 و TypeScript Language Server 5.1.3 اجرا می‌شود؛ Rust نیز toolchain نسخه 1.85.0 و `rust-analyzer` را از image pin‌شده استفاده می‌کند. Repository validation و installer testها readiness این profileها را enforce می‌کنند.

برای commandهای نصب و lifecycle به [راهنمای استفاده از Installer](./ai-tools/codex-ai-tooling-installer.md) مراجعه کنید.

## عملیات lifecycle

| عملیات | هدف | mutation |
| --- | --- | --- |
| `plan` | طبقه‌بندی target و گزارش action/conflict | فقط خواندنی |
| `install` | نصب جدید یا idempotent | نوشتن محتوای owned |
| `update` | اعمال payload جدید با ownership معتبر | نوشتن محتوای owned |
| `repair` | بازگردانی محتوای owned از payload فعلی | نوشتن محتوای owned |
| `verify` | بررسی ownership و integrity | فقط خواندنی |
| `doctor` | اجرای verify و health check runtime ایزوله | runtime check |
| `uninstall` | حذف فقط محتوایی که ownership evidence دارد | حذف محتوای owned |

## entrypointها

PowerShell:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target C:\work\consumer `
  -Profile generic `
  -Format json `
  -NonInteractive
```

POSIX:

```bash
installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /work/consumer \
  --profile generic \
  --format json \
  --non-interactive
```

## مدل ownership

برابر بودن bytes به معنی ownership نیست. full-file ownership فقط پس از انتشار موفق state installer ایجاد می‌شود.

- path غایب قابل ایجاد است.
- path owned و بدون تغییر قابل update یا remove است.
- path owned که کاربر تغییر داده به‌صورت پیش‌فرض conflict است.
- `owned-modified=replace` فقط بعد از backup برای محتوای قبلاً owned مجاز است.
- conflict متعلق به کاربر هرگز overwrite نمی‌شود.
- فایل unowned حتی اگر byte-identical باشد owned تلقی نمی‌شود.

`AGENTS.md`، `.gitignore` و `.gitattributes` از managed block دقیق استفاده می‌کنند تا محتوای متعلق به پروژه خارج از block حفظ شود.

## transaction و recovery

عملیات mutating ابتدا conflictها را محاسبه می‌کنند، lock می‌گیرند، journal می‌سازند، محتوای موجود را backup می‌کنند، فایل‌های غیر-state را می‌نویسند و ownership state را در آخر منتشر می‌کنند. failure باعث تلاش برای rollback می‌شود و recovery فقط بر اساس journal و backup معتبر انجام می‌شود.

برای سازگاری نسخه `1.0`، state در `.qbit/toolkit/installed/codex-ai-tooling.json` و شواهد transaction/recovery در `.qbit-toolkit/codex-ai-tooling/` باقی می‌ماند.

## ایزولیشن runtime

- Serena برای semantic operationهای مجاز workspace را read-write می‌بیند.
- Graphify workspace را read-only می‌بیند و output را خارج از workspace می‌نویسد.
- Doctor workspace را read-only می‌بیند.
- containerها تا حد ممکن network disabled، root filesystem فقط‌خواندنی، `no-new-privileges` و capabilityهای حذف‌شده دارند.
- Graphify فقط CLI است و MCP server دائمی نیست.

## مرز CLI آینده

CLI مستقل آینده Qbit AI Toolkit باید installer را به‌عنوان child-process contract مصرف کند، نه اینکه منطق آن را import یا دوباره پیاده‌سازی کند. CLI می‌تواند asset را resolve و verify کند، argumentها را normalize کند، host entrypoint را اجرا کند، JSON نهایی را بخواند و exit code installer را حفظ کند.
