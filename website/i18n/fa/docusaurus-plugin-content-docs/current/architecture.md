---
id: architecture
title: معماری
sidebar_label: معماری
---

# معماری

`qbit-ai-toolkit` منبع canonical و نسخه‌دار assetهای قابل مصرف توسط محصولات Qbit است. این repository خود Qbit CLI، Qbit Console یا application runtime نیست.

```text
qbit-cli            ─┐
qbit-console        ─┼── مصرف دارایی‌های نسخه‌دار qbit-ai-toolkit
مصرف‌کننده‌های آینده ─┘
```

## مالکیت assetها

دارایی‌ها بر اساس **نوع** سازمان‌دهی می‌شوند، نه بر اساس محصول مصرف‌کننده. prompt، Docker template، installer، policy، skill یا script باید یک asset canonical باقی بماند و consumerهای پشتیبانی‌شده را در metadata اعلام کند.

ساخت copyهای موازی `cli/`، `console/` یا `shared/` برای یک asset منطقی واحد مجاز نیست. تفاوت مصرف‌کننده باید با metadata، variant صریح یا compatibility boundary مستند مدیریت شود.

## مرزهای repository

دو حوزه AI tooling جدا وجود دارد:

1. فایل‌های root زیر `.ai/`، `.agents/`، `.codex/` و `.serena/` ابزارهای project-local برای توسعه خود `qbit-ai-toolkit` هستند.
2. `installers/codex-ai-tooling/` یک asset نسخه‌دار و قابل استفاده مجدد برای نصب ابزار مشابه در repositoryهای دیگر است.

این دو حوزه نباید به dependency ضمنی یکدیگر تبدیل شوند. runtime محلی نباید installer را روی خود پروژه نصب کند و خروجی تولیدشده installer نیز نباید جای source canonical را بگیرد.

## ترتیب authority

در صورت تعارض منابع، ترتیب اعتبار به این صورت است:

1. source و assetهای canonical نسخه‌دار؛
2. schemaها و قراردادهای catalog؛
3. تست‌های خودکار و installer state contract؛
4. مستندات commit‌شده معماری و compatibility؛
5. graph، index، cache، log، report و summary تولیدشده.

خروجی‌های مشتق‌شده فقط evidence هستند و source of truth محسوب نمی‌شوند.

## namespaceهای compatibility

نام repository برابر `qbit-ai-toolkit` است. با این حال pathها و managed markerهای installer نسخه 1.0 که شامل `qbit-toolkit` هستند، شناسه‌های compatibility محسوب می‌شوند و حفظ می‌شوند. rename آن‌ها نیازمند migration صریح است و از rename repository نتیجه نمی‌شود.
