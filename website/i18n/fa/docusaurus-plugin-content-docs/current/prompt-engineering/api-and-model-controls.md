---
id: api-and-model-controls
title: API و کنترل‌های مدل
sidebar_label: API و کنترل‌های مدل
---

# API و کنترل‌های مدل

متن پرامپت فقط یکی از عوامل رفتار مدل است. در applicationهای API، انتخاب model، role پیام‌ها، tool configuration، structured output، reasoning control، token limit و version مدل هم بخشی از contract هستند.

## مسیر فعلی OpenAI API

برای یکپارچه‌سازی‌های جدید OpenAI، **Responses API** و مستندات فعلی همان مدل را مبنا قرار دهید. برای Assistants API قدیمی تاریخ خاموشی **۲۰۲۶-۰۸-۲۶** اعلام شده بود که اکنون گذشته است؛ کار جدید در محیط عملیاتی را بر پایهٔ آن آغاز نکنید. پیش از نتیجه‌گیری دربارهٔ وضعیت دسترس‌پذیری یا جزئیات مهاجرت، مستندات فعلی ارائه‌دهنده را بررسی کنید.

Chat Completions هنوز برای use caseهای سازگار وجود دارد، اما مثال‌های جدید این راهنما تا حد امکان از conceptهای Responses استفاده می‌کنند.

## Instructions و role پیام‌ها

در Responses API فعلی، input message می‌تواند roleهای `developer`، `system`، `user` و `assistant` داشته باشد. `developer` و `system` از نظر instruction priority بالاتر از `user` هستند.

فیلد top-level به نام `instructions` رفتار developer-level دارد. هنگام استفاده از `previous_response_id` فرض نکنید `instructions` پاسخ قبلی خودکار به response جدید منتقل می‌شود؛ instruction لازم را مطابق contract API دوباره supply کنید.

Secret، authorization rule یا policy امنیتی critical را فقط داخل system/developer prompt قرار ندهید.

## Structured Outputs

اگر software باید JSON machine-readable مصرف کند، در مدل‌هایی که پشتیبانی می‌کنند از **Structured Outputs** همراه JSON Schema و strict adherence استفاده کنید.

این دستور:

```text
فقط JSON معتبر برگردان.
```

از schema enforce‌شده در API ضعیف‌تر است. JSON mode قدیمی‌تر می‌تواند valid JSON را تضمین کند، اما Structured Outputs می‌تواند shape را به schema پشتیبانی‌شده محدود کند.

## Function calling و Toolها

بسته به platform، toolها می‌توانند provider-built tool، custom function، file/search، code execution، computer-use یا remote MCP server باشند.

Tool definition خوب شامل این موارد است:

- نام و purpose محدود؛
- parameterهای strongly typed؛
- description روشن برای selection؛
- strict schema در صورت support؛
- authorization و validation در application.

`tool_choice` یا کنترل مشابه ممکن است انتخاب auto، عدم استفاده از tool، اجبار به tool یا اجبار به یک tool مشخص را فراهم کند.

Prompt مشخص می‌کند **چه زمانی** tool مناسب است؛ application باید enforce کند **آیا** action مجاز است.

## Reasoning control

مدل‌های reasoning ممکن است parameterهایی مانند `reasoning.effort` یا thinking control محصول داشته باشند. این تنظیم‌ها model-specific هستند و trade-off بین latency/token usage و reasoning را تغییر می‌دهند.

مجموعه valueهای reasoning effort را بدون نام model family به‌عنوان قانون عمومی document نکنید؛ support و default تغییر می‌کند.

## Verbosity

برخی مدل‌های فعلی کنترل `verbosity` برای میزان جزئیات خروجی دارند. وقتی provider چنین controlی می‌دهد، از آن برای preference کلی استفاده کنید؛ hard output contract همچنان باید در prompt یا schema تعریف شود.

## Temperature و Top-p

`temperature` و `top_p` در مدل‌هایی که آن‌ها را support می‌کنند sampling را کنترل می‌کنند. temperature بالاتر معمولاً randomness را بیشتر می‌کند و `top_p` probability mass قابل انتخاب را محدود می‌کند.

Rangeهایی مثل «۰ تا ۰.۳ برای کد» را قانون عمومی آموزش ندهید. model familyها متفاوت‌اند، برخی reasoning configurationها sampling control را محدود یا نادیده می‌گیرند و temperature پایین صحت را تضمین نمی‌کند.

اگر هر دو parameter موجودند، بدون evidence از eval بهتر است هر بار یکی را تغییر دهید.

## Top-k

برخی ارائه‌دهندگان `top_k` هم دارند که در سطح مفهومی، انتخاب را به مجموعه‌ای رتبه‌بندی‌شده از توکن‌های پیشنهادی محدود می‌کند. نحوهٔ تعامل و ترتیب اعمال آن با `top_p` و temperature به ارائه‌دهنده و مدل وابسته است؛ پس به‌جای دستورالعمل عمومی یا مقدارهای افراطی در آموزش‌های قدیمی، مرجع همان مدل را بررسی کنید.

## محدودیت token خروجی

نام parameter را از endpoint/model فعلی بگیرید. در Responses API، limit سطح response با `max_output_tokens` بیان می‌شود؛ APIها یا مثال‌های قدیمی‌تر ممکن است نام‌هایی مثل `max_completion_tokens` داشته باشند.

Token limit سقف فنی است، نه جایگزین دستور طول انسانی. اگر business constraint دارید، آن را با واحد قابل فهم هم تعریف و تست کنید.

## Presence و Frequency penalty

برخی model familyها penaltyهایی برای تغییر token selection بر اساس حضور یا تکرار token دارند. این کنترل‌ها می‌توانند repetition/novelty را تغییر دهند، اما support آن‌ها model-specific است و معادل «واژگان بهتر» نیستند.

آن‌ها را در generic prompt recipe قرار ندهید مگر model انتخابی رسماً support کند.

## Version pinning و Eval

Behavior پرامپت می‌تواند بین model snapshotها تغییر کند. برای prompt production که stability مهم است:

1. در صورت امکان model snapshot/version را کنترل یا pin کنید؛
2. prompt را مستقل version کنید؛
3. settingهای مؤثر را ثبت کنید؛
4. قبل و بعد از prompt/model change همان eval set را اجرا کنید؛
5. migration مدل را behavior change بدانید، نه صرفاً dependency bump.

## اصطلاحات قدیمی را مستقیم کپی نکنید

Tutorial قدیمی را به API فعلی map کنید. `max_tokens`، Assistants/Threads یا JSON-mode قدیمی را بدون بررسی reference جدید وارد کد production نکنید.
