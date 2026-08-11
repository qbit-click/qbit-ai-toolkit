---
id: reasoning-and-agents
title: استدلال و الگوهای ایجنتی
sidebar_label: استدلال و ایجنت‌ها
---

# استدلال و الگوهای ایجنتی

چند مقاله مهم در سال‌های گذشته تکنیک‌هایی معرفی کردند که برای نسل‌های قبلی مدل‌های زبانی مؤثر بودند. این مفاهیم هنوز برای فهم تاریخچه و معماری سیستم‌های AI مهم‌اند، اما نباید همه آن‌ها را به‌صورت recipe مستقیم برای مدل‌های reasoning جدید استفاده کرد.

## Chain-of-Thought: زمینه تاریخی

Chain-of-Thought یا CoT نشان داد که تولید یا ارائه intermediate reasoning در برخی مسائل چندمرحله‌ای می‌تواند performance مدل‌های آن دوره را بهتر کند. Zero-shot CoT نیز عبارت‌هایی مانند «قدم‌به‌قدم فکر کن» را رایج کرد.

برای مدل‌های reasoning امروزی، فرض نکنید درخواست یک chain-of-thought طولانی و قابل مشاهده مفید است. این مدل‌ها reasoning داخلی خود را انجام می‌دهند و سیستم‌های production معمولاً پاسخ نهایی یا reasoning summary قابل ارائه را برمی‌گردانند.

به‌جای درخواست private reasoning، evidence قابل بررسی بخواهید:

```text
مسئله را حل کن و برگردان:
1. پاسخ نهایی؛
2. فرمول یا مراحل کلیدی لازم برای verify کردن پاسخ؛
3. assumptionهایی که نتیجه به آن‌ها وابسته است.
```

## Reasoning effort

برخی APIها برای مدل‌های reasoning کنترل‌هایی مانند `reasoning.effort` دارند. وقتی چنین کنترلی وجود دارد، trade-off کیفیت/latency را با parameter رسمی مدل مدیریت کنید، نه با عبارت‌هایی مثل «بیشتر فکر کن» یا تکرار «قدم‌به‌قدم فکر کن».

مقادیر و support این parameter مدل‌محور است؛ مستندات همان model snapshot را بررسی کنید.

## Self-Consistency

Self-Consistency چند candidate مستقل تولید و نتیجه را aggregate یا majority-vote می‌کند. این یک strategy در سطح application است، نه تضمین حقیقت.

زمانی مفید است که:

- sampling مستقل diversity واقعی ایجاد کند؛
- answer space روشن یا verifier قابل اعتماد وجود داشته باشد؛
- هزینه و latency چند فراخوانی توجیه شود.

Majority vote جای source verification یا deterministic validation را نمی‌گیرد.

## ReAct

ReAct یا Reasoning + Acting الگویی پژوهشی برای ترکیب تصمیم مدل، action و observation است. abstraction مناسب‌تر در agentهای امروزی معمولاً این است:

```text
model decision -> tool call -> tool result -> next model decision
```

لازم نیست فیلد literal به نام `Thought:` به کاربر نمایش داده شود. در production موارد مهم‌تر عبارت‌اند از tool selection، permission boundary، نحوه پردازش observation، stop condition، retry و validation.

بنابراین ReAct را بهتر است **agent orchestration pattern** بدانیم، نه یک عبارت جادویی داخل prompt.

## Tree of Thoughts

Tree of Thoughts چند branch جایگزین را بررسی و score می‌کند و branchهای امیدوارکننده را ادامه می‌دهد. این الگو برای search/problem-solving پیچیده مفید است، اما معمولاً به چند model call، scoring strategy یا search logic نیاز دارد.

آن را به‌صورت یک جمله ساده که خودبه‌خود «استدلال مدل را بهتر می‌کند» آموزش ندهید.

## Plan-then-execute

برای taskهای طولانی یا stateful، جدا کردن planning از execution عملی‌تر است:

```text
قبل از هر تغییر:
- وضعیت فعلی را inspect کن؛
- dependencyها و عملیات برگشت‌ناپذیر را مشخص کن؛
- یک execution plan کوتاه ارائه بده.

سپس فقط plan تأییدشده را اجرا کن و هر نتیجه قابل مشاهده را verify کن.
```

این الگو workflow را کنترل می‌کند بدون اینکه private chain-of-thought را مطالبه کند.

## Verification از verbosity مهم‌تر است

در ریاضی، کد، تحقیق و عملیات، artifact قابل بررسی بخواهید:

- فرمول و مقدار جایگذاری‌شده؛
- citation معتبر؛
- test و نتیجه test؛
- diff؛
- tool output؛
- assumption و uncertainty؛
- pass/fail criteria.

توضیح طولانی‌تر الزاماً پاسخ قابل اعتمادتر نیست.

## چند Agent چه زمانی ارزش دارد؟

Generator/reviewer یا planner/executor را زمانی جدا کنید که separation واقعی ایجاد می‌کند؛ مثلاً reviewer مستقل، tool permission متفاوت یا context مستقل. اینکه یک مدل را در همان context مجبور کنیم «دو agent را بازی کند» استقلال واقعی ایجاد نمی‌کند.
