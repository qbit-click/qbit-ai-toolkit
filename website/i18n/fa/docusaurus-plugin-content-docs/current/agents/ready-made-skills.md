---
id: ready-made-skills
title: اسکیل‌های آماده
sidebar_label: اسکیل‌های آماده
---

# اسکیل‌های آماده

Qbit AI Toolkit می‌تواند skillهای reusable برای workflowهای تکراری مهندسی منتشر کند. مستندات توضیح می‌دهند هر skill چه کاری انجام می‌دهد و چه constraintهایی دارد؛ خود asset نسخه‌دار زیر `agent-assets/skills/` نگه‌داری می‌شود.

## نمونه‌های مناسب

- تحلیل impact معماری؛
- security review؛
- release validation؛
- توسعه و verification installer؛
- جست‌وجوی مستندات libraryهای بیرونی؛
- governance repository و validation gateها.

## هر skill آماده چه چیزهایی باید مستند کند؟

Trigger، toolهای لازم، environmentهای پشتیبانی‌شده، write permission، output مورد انتظار، failure behavior و مثال‌هایی از شرایطی که نباید از skill استفاده شود.

## Versioning

تغییر رفتار عملیاتی یک skill می‌تواند چند repository را تحت تأثیر قرار دهد، حتی اگر filename ثابت بماند. بنابراین behavior change باید به‌عنوان تغییر asset نسخه‌دار مدیریت شود و compatibility برای consumerها روشن باشد.
