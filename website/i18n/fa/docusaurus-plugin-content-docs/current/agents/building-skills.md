---
id: building-skills
title: ساخت اسکیل برای ایجنت
sidebar_label: ساخت اسکیل
---

# ساخت اسکیل برای ایجنت

یک skill باید یک workflow تصمیم‌گیری و اجرا را تعریف کند، نه اینکه صرفاً prompt دیگری باشد. trigger، scope، input، مراحل عملیات و validation آن باید روشن باشند.

## قرارداد skill را تعریف کنید

مشخص کنید:

- **چه زمانی skill فعال می‌شود** و چه زمانی نباید اجرا شود؛
- **چه context و inputهایی لازم است**؛
- **از چه tool یا capabilityهایی می‌تواند استفاده کند**؛
- **ترتیب مراحل** در جایی که مرحله بعد به نتیجه مرحله قبل وابسته است؛
- **مرزهای ایمنی** برای عملیات state-changing؛
- **خروجی و معیار completion**؛
- **رفتار failure و escalation** در صورت نبود اطلاعات یا مجوز لازم.

## Skill را composable نگه دارید

هر skill باید یک کلاس coherent از کار را حل کند. workflowهای نامرتبط را فقط به این دلیل که از یک مدل یا tool مشترک استفاده می‌کنند در یک skill ادغام نکنید.

## از assumption پنهان دوری کنید

Path، credential، platform یا tool availability را فرض نکنید مگر اینکه skill صریحاً آن را requirement بداند و verify کند.

## رفتار را validate کنید

success path، missing input، permission failure و regressionهای قبلی را تست کنید. برای skillهایی که repository یا production را تغییر می‌دهند، inspection خواندنی قبل از mutation و rollback/recovery مورد انتظار باید مشخص باشد.
