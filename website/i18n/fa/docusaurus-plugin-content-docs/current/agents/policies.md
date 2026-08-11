---
id: policies
title: پالیسی‌های ایجنت
sidebar_label: پالیسی‌ها
---

# پالیسی‌های ایجنت

Policyها constraintهایی هستند که باید در چند skill یا workflow مشترک اعمال شوند. آن‌ها باید ruleهای پایدار رفتاری یا امنیتی را بیان کنند، نه مراحل implementation یک task خاص را.

## موضوعات رایج policy

- inspection خواندنی قبل از state change؛
- حفاظت از secret و credential؛
- toolهای مجاز یا ممنوع؛
- الزامات ایمنی production؛
- scope و ownership boundary؛
- validation و evidence مورد نیاز؛
- الزام سؤال کردن درباره تصمیم‌های مهم به‌جای حدس زدن.

## Skill در برابر Policy

وقتی به workflow reusable برای انجام یک task نیاز دارید از **skill** استفاده کنید. وقتی چند workflow باید از یک boundary مشترک پیروی کنند از **policy** استفاده کنید. کپی کردن یک policy در چند skill باعث drift می‌شود.

## محل نگه‌داری

Policyهای reusable زیر `agent-assets/policies/` قرار می‌گیرند. دستورالعمل‌های خاص یک repository می‌توانند کنار همان repository باقی بمانند، اگر بخشی از governance contract خود آن باشند.
