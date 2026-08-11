---
id: setup-scripts
title: اسکریپت‌های راه‌اندازی و کمکی
sidebar_label: اسکریپت‌های راه‌اندازی
---

# اسکریپت‌های راه‌اندازی و کمکی

اسکریپت‌های setup باید آماده‌سازی و validation محیط را تکرارپذیر کنند، بدون اینکه رفتار مخرب یا حساس به امنیت را پنهان کنند.

## ویژگی‌های مورد انتظار

- **Idempotent تا حد ممکن** — اجرای دوباره نباید state تکراری یا drift غیرضروری بسازد.
- **Prerequisite صریح** — runtime، Docker capability، credential و فرض‌های platform قبل از mutation بررسی شوند.
- **Failure قابل مشاهده** — خطا باید operation شکست‌خورده و مسیر remediation را مشخص کند.
- **بدون secret داخل source** — secretها در secret store یا config محلی ignored نگه‌داری شوند.
- **Parity بین platformها** — اگر PowerShell و POSIX هر دو پشتیبانی می‌شوند، قرارداد رفتاری یکسان داشته باشند.

## اسکریپت‌های Qbit AI Toolkit

اسکریپت‌های کمکی AI محلی پروژه زیر `.ai/scripts/` قرار می‌گیرند. entrypointهای maintenance repository بسته به scope زیر `tools/` یا `scripts/` هستند. scriptهایی که جزئی از installer payload هستند باید کنار asset مالک خود باقی بمانند.

بعد از setup، در صورت وجود `doctor` یا verification آن را اجرا کنید؛ صرف ساخته شدن فایل‌ها اثبات نمی‌کند runtime واقعاً سالم است.
