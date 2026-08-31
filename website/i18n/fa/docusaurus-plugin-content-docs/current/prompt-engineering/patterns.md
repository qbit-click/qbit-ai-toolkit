---
id: patterns
title: الگوهای پرامپت
sidebar_label: الگوهای پرامپت
---

# الگوهای پرامپت

Patternها ساختارهای reusable برای کلاس‌های تکراری کار هستند. باید ابهام را کم کنند، نه اینکه هر درخواست را به template صلب تبدیل کنند.

## ابتدا Zero-shot

اگر task روشن است و مدل رفتار مورد انتظار را می‌شناسد، از دستور مستقیم شروع کنید:

```text
پیام مشتری را در یکی از categoryهای زیر طبقه‌بندی کن:
- billing
- technical_support
- cancellation
- other

فقط label را برگردان.
```

Zero-shot baseline نشان می‌دهد آیا واقعاً به مثال نیاز دارید یا نه.

## One-shot prompting

One-shot prompting حالت تک‌مثالی میان Zero-shot و Few-shot گسترده‌تر است. وقتی یک مثال دقیق برای نشان‌دادن قالب یا رویهٔ موردنیاز کافی است، از آن استفاده کنید. یک مثال پوشش اندکی برای موارد مرزی دارد؛ پس به‌جای فرض تعمیم‌پذیری، آن را ارزیابی کنید.

## Few-shot

وقتی boundary بین labelها، edge case، tone یا transformation را به‌سختی می‌توان کوتاه توضیح داد، چند مثال انتخاب‌شده ارائه کنید:

```text
Text: "The app crashes when I open settings."
Label: technical_support

Text: "I was charged twice this month."
Label: billing

Text: "Please close my account at the end of the cycle."
Label: cancellation

Text: "Where can I download invoices?"
Label:
```

تعداد مثال مهم نیست؛ coverage مهم است. مثال‌هایی انتخاب کنید که categoryهای نزدیک را از هم جدا کنند. فرض نکنید few-shot همیشه بهتر است؛ با eval ثابت اندازه بگیرید.

## Role و perspective

Role framing می‌تواند vocabulary، audience، tone یا معیار review را تنظیم کند:

> این design را از perspective یک security engineer ارشد review کن. روی trust boundary، least privilege، secret handling و rollback risk تمرکز کن.

اما fictional credential صحت ایجاد نمی‌کند. جمله «تو پزشکی با ۲۰ سال سابقه هستی» تجربه پزشکی واقعی به مدل نمی‌دهد. معیار تخصص، checkهای لازم و sourceهای مجاز را صریح کنید.

## Step-back prompting

در Step-back prompting ابتدا اصل‌ها، معیارها، ناورداها یا انتزاع‌های سطح‌بالای حوزه را استخراج یا بازیابی می‌کنید و سپس آن‌ها را به مورد مشخص اعمال می‌کنید. این روش برای طراحی یا بازبینی‌هایی مفید است که یادآوری قواعد حاکم، تصمیم مشخص را بهتر می‌کند، یا برای نمونهٔ ناآشنایی که ابتدا به صورت‌بندی بهتر مسئله نیاز دارد.

مثال:

```text
پیش از بازبینی این طراحیِ تلاش مجدد پرداخت، ناورداهای جلوگیری از برداشت تکراری را فهرست کن.
سپس طراحی ارائه‌شده را با آن ناورداها بسنج و هر شکاف را مشخص کن.
```

این کار می‌تواند در یک پرامپت ساختاریافته یا، وقتی جداسازی و اعتبارسنجی مستقل اهمیت دارد، در فراخوانی‌ها یا مرحله‌های جدا انجام شود. این روش درخواست Chain-of-Thought پنهان نیست: اصل‌ها و شواهد کوتاه و قابل بازبینی بخواهید. آن را یک روش ابتکاریِ قابل ارزیابی بدانید، نه تضمین دقت بیشتر یا سوگیری کمتر.

## کار پیچیده را مرحله‌بندی کنید

وقتی task تصمیم‌های وابسته دارد، phaseهای observable تعریف کنید:

```text
1. requirements را بررسی و تصمیم‌های حل‌نشده را فهرست کن.
2. اگر تصمیمی public API را تغییر می‌دهد، قبل از حل آن implementation نکن.
3. پس از رفع تصمیم‌ها، implementation contract را بنویس.
4. نتیجه را با acceptance criteria validate کن.
```

این decomposition با درخواست hidden Chain-of-Thought فرق دارد؛ هدف کنترل workflow قابل مشاهده است.

## Critique و revision

برای draftهای کیفی، generation را از review جدا کنید:

```text
release note را draft کن.
سپس آن را بر اساس این معیارها review کن:
- factual accuracy
- بدون ادعای unsupported
- user-visible impact در ابتدا
- حداکثر ۱۸۰ کلمه
فقط نسخه نهایی اصلاح‌شده را برگردان.
```

در کار high-stakes، evaluator مستقل یا human review از self-review همان generation معتبرتر است.

## استخراج ساختاریافته

Field و missing-value behavior را مشخص کنید:

```text
این fieldها را استخراج کن:
- incident_id
- affected_service
- start_time
- customer_impact

اگر مقدار در source نیست null بده. مقدار گمشده را infer نکن.
```

اگر API Structured Outputs دارد، contract را با JSON Schema enforce کنید.

## کار با ابزار

Discovery read-only را از mutation جدا کنید:

```text
ابتدا repository و configuration را فقط با ابزارهای read-only بررسی کن.
پیش از هر mutation، target، impact و rollback را verify کن.
پس از تغییر، validation مشخص‌شده را اجرا و نتیجه واقعی را گزارش کن.
```

Permission را application enforce می‌کند، نه prompt.

## پاسخ grounded

```text
فقط بر اساس policy documentهای ارائه‌شده پاسخ بده.
برای هر ادعای مهم section پشتیبان را cite کن.
اگر source پاسخ را پشتیبانی نمی‌کند، به‌جای حدس زدن بگو پاسخ از منابع ارائه‌شده قابل اثبات نیست.
```

## Handoff بین agentها

اگر یک agent طراحی و agent دیگری implementation را انجام می‌دهد، پرامپت باید self-contained باشد: scope، facts، decisions، compatibility، failure behavior، file/boundary، acceptance criteria و tests را کامل بیاورید.

## از folklore پرامپت دوری کنید

عبارت‌هایی مثل «خیلی باهوش باش»، «عمیق فکر کن» یا personaهای داستانی جای requirement را نمی‌گیرند. اگر یک تکنیک outcome اندازه‌گیری‌شده را بهتر نمی‌کند، حذفش کنید.
