---
id: index
title: CodexPro
sidebar_label: معرفی
---

# CodexPro

CodexPro یک bridge متن‌باز است که workspace توسعه محلی را از طریق MCP در اختیار ChatGPT قرار می‌دهد و در عین حال repository tooling، اجرای sandboxed Bash و قابلیت اختیاری اجرای مستقیم روی host را به‌عنوان مسیرهای جدا نگه می‌دارد.

مستندات این بخش به‌صورت **deployment-neutral** نوشته شده‌اند. در public docs برای username، workspace root، connector name، package location، hostname، tunnel ID و credential از placeholder استفاده می‌شود و مقدار یک سیستم یا پروژه خاص به‌عنوان مرجع عمومی ثبت نمی‌شود.

## راهنماهای موجود

- [راهنمای راه‌اندازی Windows](./windows-setup.md) — تنظیم CodexPro روی Windows با pathهای عمومی، نصب مستقل از package-manager storage layout، workspace containment، tunnel و capabilityهای اختیاری version-specific.
- [راهنمای راه‌اندازی Linux](./linux-setup.md) — نصب و اجرای CodexPro روی Linux، local/public HTTPS، repository boundary، interactive/headless operation و troubleshooting.
- [راهنمای راه‌اندازی macOS](./macos-setup.md) — نصب و اجرای CodexPro روی macOS با پوشش shell/PATH، privacy permission، Apple Silicon/Intel، tunnel و repository-scoped access.

## مرز package manager

CodexPro به‌صورت package در اکوسیستم npm توزیع می‌شود، اما setup به Bun وابسته نیست. هر package manager سازگاری که version موردنظر CodexPro را نصب کند و executable `codexpro` را روی `PATH` قرار دهد قابل استفاده است. Storage layout package manager یک جزئیات installation است، نه بخشی از معماری CodexPro.

## مرز امنیتی مهم

Sandboxed Bash و اجرای مستقیم روی host دو capability مستقل هستند:

- Bash باید داخل repository/workspace انتخاب‌شده محدود بماند.
- Direct host execution، اگر وجود داشته و فعال شود، با سطح دسترسی OS user جاری اجرا می‌شود و به approval و credential model سخت‌گیرانه‌تری نیاز دارد.

MCP token و connector URL حاوی token را secret در نظر بگیرید. Narrowest practical workspace root را انتخاب کنید و فقط capabilityهای لازم workflow را فعال کنید.

## customizationهای version-specific

اگر deployment فایل‌های source CodexPro را patch می‌کند یا tool سفارشی اضافه می‌کند، build دقیق CodexPro را pin و آن تغییر را به‌عنوان patch asset versioned مدیریت کنید. Hash، package path، username، hostname یا connector name یک ماشین دیگر را به‌عنوان مقدار universal در مستندات عمومی منتشر نکنید.
