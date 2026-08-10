---
id: asset-contract
title: قرارداد دارایی‌ها
sidebar_label: قرارداد دارایی‌ها
---

# قرارداد دارایی‌ها

هر asset در catalog یک قرارداد ماشین‌خوان پایدار دارد.

فیلدهای اصلی شامل stable ID، نوع asset، semantic version، مسیر نسبی repository، consumerهای پشتیبانی‌شده، lifecycle status و description هستند. metadata اختیاری می‌تواند minimum consumer version، platformها، entrypointها، integrity و release information را مشخص کند.

## منبع canonical

`catalog.json` ورودی اصلی consumerهای ماشینی است و به `schemas/catalog.schema.json` ارجاع می‌دهد. قرارداد هر asset نیز توسط `schemas/asset.schema.json` تعریف می‌شود.

installerها علاوه بر catalog یک manifest دارند که با `schemas/installer-manifest.schema.json` کنترل می‌شود. نسخه موجود در catalog، manifest و فایل `VERSION` asset باید برابر باشد.

## metadata مصرف‌کننده

schema فعلی مقادیر `cli`، `console` و `shared` را می‌شناسد. این مقادیر قرارداد موجود هستند و لزوماً هویت تمام محصولات آینده را مشخص نمی‌کنند. قبل از اینکه CLI مستقل AI Toolkit به consumer رسمی catalog تبدیل شود، ممکن است مدل consumer identity نیازمند شفاف‌سازی باشد.

## placeholderها

template source می‌تواند از قالب `{{PLACEHOLDER_NAME}}` استفاده کند. خروجی نهایی نصب یا render نباید placeholder حل‌نشده داشته باشد.

## integrity

asset نسخه‌دار باید metadata کافی برای اثبات نسخه و صحت artifact فراهم کند. floating version، mutable image tag، branch selector و copy تولیدشده بدون قرارداد، هویت معتبر release نیستند.
