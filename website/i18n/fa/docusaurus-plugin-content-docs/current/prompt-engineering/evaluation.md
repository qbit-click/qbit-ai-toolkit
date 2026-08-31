---
id: evaluation
title: ارزیابی پرامپت
sidebar_label: ارزیابی
---

# ارزیابی پرامپت

یک پرامپت فقط به این دلیل validated نیست که یک مثال پاسخ خوبی داده است. Behavior پرامپت را یک component نسخه‌دار در نظر بگیرید و آن را روی inputهای نماینده، edge case و failure condition ارزیابی کنید.

## قبل از تغییر wording، موفقیت را تعریف کنید

Acceptance criteria باید observable باشند. بسته به use case می‌توانند شامل این موارد باشند:

- factual correctness یا groundedness؛
- کامل بودن؛
- schema conformance؛
- انتخاب درست tool؛
- authorization و safety behavior؛
- citation accuracy؛
- latency و token cost؛
- tone یا تناسب با audience؛
- refusal، fallback یا escalation.

معیاری مثل «پاسخ باهوش به نظر برسد» بدون rubric قابل استفاده نیست.

## Eval Set نماینده بسازید

فقط happy path کافی نیست. مجموعه باید شامل موارد زیر باشد:

- input معمولی؛
- input مبهم؛
- missing data؛
- context طولانی یا noisy؛
- boundary value؛
- input چندزبانه در صورت support؛
- instruction متناقض با priority پایین‌تر؛
- adversarial/prompt-injection case؛
- regression case برای هر failure مهمی که قبلاً دیده شده است.

Eval set باید distribution واقعی مسئله را نمایندگی کند، نه فقط مثال‌هایی که prompt author راحت حل می‌کند.

## Expected Output یا Rubric؟

برای task deterministic مثل classification label یا ID extracted، exact expected value مناسب است.

وقتی چند جواب می‌تواند درست باشد rubric تعریف کنید:

| بُعد | پرسش نمونه |
|---|---|
| Correctness | آیا conclusion با evidence سازگار است؟ |
| Completeness | همه field/sectionهای لازم وجود دارند؟ |
| Grounding | claimهای factual با source مجاز پشتیبانی می‌شوند؟ |
| Safety | مدل داخل action boundary مجاز ماند؟ |
| Usefulness | پاسخ واقعاً به user هدف برای انجام task کمک می‌کند؟ |

Pass threshold را قبل از مقایسه prompt versionها مشخص کنید.

## Behavior را تست کنید، نه wording را

برای generative text معمولاً assertion روی رفتار observable بهتر از exact string match است. تغییر بی‌ضرر در جمله‌بندی نباید test را fail کند اگر decision و constraint اصلی حفظ شده است.

Exact match برای label، ID، command strict و field deterministic مناسب است.

## Revisionها را روی یک Set ثابت مقایسه کنید

هنگام تغییر reusable prompt:

1. prompt version و model configuration فعلی را ثبت کنید؛
2. baseline eval را اجرا کنید؛
3. کوچک‌ترین تغییر توجیه‌شده را اعمال کنید؛
4. همان eval set را دوباره اجرا کنید؛
5. improvement و regression را مقایسه کنید؛
6. failure جدید مهم را به regression suite دائمی اضافه کنید.

Test سخت را فقط برای سبز شدن نتیجه حذف نکنید مگر product requirement واقعاً تغییر کرده باشد.

## Execution Context را ثبت کنید

برای reproducibility موارد مؤثر بر behavior را ثبت کنید:

- prompt/template version؛
- model ID/snapshot؛
- API endpoint یا product mode؛
- model parameterهای relevant؛
- tool definition و permission؛
- retrieval configuration؛
- تاریخ اجرا؛
- dataset/eval-set version.

رفتار model بین snapshotها ممکن است تغییر کند، پس prompt change و model change را در یک validation framework بررسی کنید.

## ارزیابی خودکار و انسانی

Automated grader برای scale، structure، deterministic check و rubric روشن مفید است. Human review برای usefulness nuanced، requirement مبهم و decision پرریسک همچنان لازم است.

در safety-critical behavior، model grader نباید تنها authority باشد. Hard rule را تا حد امکان با validator deterministic بسنجید و model grader را برای judgment semantic به‌کار ببرید.

## Security Eval

Caseهای امنیتی باید شامل این‌ها باشند:

- direct و indirect prompt injection؛
- misuse ابزار؛
- source poisoning؛
- request برای resource غیرمجاز؛
- تلاش برای claim موفقیت action بدون tool evidence.

Pass condition این نیست که مدل هرگز malicious content نبیند؛ pass واقعی این است که malicious content نتواند deterministic permission/validation boundary را بشکند.

## Structured Output Eval

برای JSON/schema تست کنید:

- property required؛
- enum و type bound؛
- nullable/missing behavior؛
- additionalProperties policy؛
- semantic consistency بین fieldها؛
- representation refusal/fallback.

Schema-valid بودن به معنی درست بودن data نیست.

## Publish Gate

برای prompt production، pass rate یا zero-failure class مشخص کنید. مثال:

- صفر authorization-boundary failure؛
- ۱۰۰٪ schema conformance؛
- حداقل ۹۸٪ classification correctness روی reference set؛
- صفر regression در critical caseهای قبلی.

Threshold از risk و product requirement می‌آید، نه از قانون generic مهندسی پرامپت.

## مدیریت Prompt

اگر provider prompt ID، version history، variable، rollback یا linked eval دارد، در صورت تناسب از آن استفاده کنید. در این repository، reusable prompt همچنان باید کنار test و consumer contract خودش version شود تا behavior change در Git قابل review باشد.

## بهینه‌سازی خودکار پرامپت

بهینه‌سازی خودکار، جست‌وجوی نسخه‌های پیشنهادی است، نه تصمیم خودکار برای انتشار. فرایند کنترل‌شده چنین است:

1. معیارهای پذیرش و مجموعه‌دادهٔ نسخه‌دار را ثابت کنید؛
2. نسخه‌های پیشنهادی پرامپت را بسازید؛
3. همهٔ گزینه‌ها را روی زیرمجموعهٔ یکسانِ آموزش/تنظیم، با بررسی‌های قطعی و معیارنامهٔ متناسب با وظیفه ارزیابی کنید؛
4. گزینهٔ انتخاب‌شده را با داده‌های کنارگذاشته‌شده و موارد رگرسیون دائمی اعتبارسنجی کنید؛
5. تأخیر و هزینه را بررسی کنید، هرجا معنا یا ریسک ایجاب می‌کند بازبینی انسانی بگیرید و گزینهٔ برنده را همراه شواهد نسخه‌بندی کنید.

مستقیماً روی مجموعهٔ آزمون نهایی بهینه‌سازی نکنید؛ انتخاب مکرر بر اساس آن باعث بیش‌برازش پرامپت و از بین رفتن استقلال آزمون می‌شود. BLEU و ROUGE ممکن است برای وظایف محدودِ هم‌پوشانی متن مناسب باشند، اما معیار عمومی کیفیت پرامپت نیستند.

ابزارهای مدیریت‌شده توسط ارائه‌دهنده، مانند **Vertex AI Prompt Optimizer**، می‌توانند نسخه‌های پیشنهادی بسازند و با معیارهای تنظیم‌شده ارزیابی کنند. این ابزارها اختیاری‌اند؛ قرارداد ارزیابی، اعتبارسنجی با دادهٔ کنارگذاشته‌شده و دروازهٔ انتشار همچنان متعلق به برنامه است.
