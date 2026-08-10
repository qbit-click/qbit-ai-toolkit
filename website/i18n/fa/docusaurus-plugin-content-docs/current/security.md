---
id: security
title: امنیت
sidebar_label: امنیت
---

# امنیت

Qbit AI Toolkit باید مرزهای اعتماد را میان source repository، target installer، downloadها، containerها، state تولیدشده و release artifactها صریح حفظ کند.

## قواعد پایه

- credential، access token، private key یا connection string واقعی commit نمی‌شود.
- فایل‌های environment نمونه فقط placeholder دارند.
- downloadهای runtime نسخه‌دار باید pin و پیش از استفاده integrity-verified شوند.
- archive extraction باید traversal، link ناامن، device، FIFO و special entry پشتیبانی‌نشده را رد کند.
- نوشتن installer فقط زیر Git work tree هدفِ validation‌شده انجام می‌شود.
- conflictهای unowned overwrite نمی‌شوند.
- محتوای owned و تغییرکرده بدون policy محدود replace و backup جایگزین نمی‌شود.
- `plan` و `verify` فقط‌خواندنی می‌مانند.

## ایزولیشن runtime

runtime محلی repository و runtime تولیدشده installer تا حد امکان از container boundary استفاده می‌کنند: network غیرفعال، root filesystem فقط‌خواندنی، capabilityهای حذف‌شده و mount فقط‌خواندنی workspace، مگر جایی که semantic edit مستند به write access نیاز داشته باشد.

## GitHub Pages

workflow مستندات در build فقط `contents: read` دارد و در مرحله deploy صرفاً `pages: write` و `id-token: write` دریافت می‌کند. secret مخصوص deploy در repository ذخیره نمی‌شود.

برای دامنه سفارشی بهتر است دامنه در GitHub organization تأیید شود و wildcard DNS ساخته نشود تا ریسک subdomain takeover کاهش یابد.
