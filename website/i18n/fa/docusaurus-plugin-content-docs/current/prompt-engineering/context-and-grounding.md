---
id: context-and-grounding
title: Context، حافظه، ابزار و RAG
sidebar_label: Context و Grounding
---

# Context، حافظه، ابزار و RAG

قابل اعتماد بودن پاسخ فقط به wording پرامپت وابسته نیست؛ باید بدانیم مدل واقعاً چه اطلاعاتی را می‌بیند. Context management، حافظه محصول، retrieval و toolها مکانیزم‌های مرتبط اما متفاوت هستند.

## Context Window

هر مدل context window محدودی دارد. بسته به model و API، این window می‌تواند instruction، message، file، tool call/result، retrieved content و reasoning state را دربر بگیرد.

در مکالمه طولانی فرض نکنید هر جزئیات قدیمی همیشه با همان اهمیت در دسترس می‌ماند. برای workflowهای طولانی:

- requirementهای authoritative را compact و صریح نگه دارید؛
- decisionهای پایدار را خلاصه کنید، نه اینکه کل history را بارها append کنید؛
- identifier و state را در صورت امکان به‌صورت deterministic منتقل کنید؛
- context-limit/truncation را detect کنید و requirement را silently از دست ندهید.

## Conversation state در API

State گفتگو در API بخشی از runtime/application است. بسته به platform ممکن است prior itemها را خودتان ارسال کنید، به response قبلی reference بدهید یا از conversation/state resource استفاده کنید.

Persistence جای instruction صریح را نمی‌گیرد. برای مثال در Responses API، استفاده از `previous_response_id` به این معنی نیست که top-level `instructions` پاسخ قبلی خودکار برای پاسخ جدید carry شود.

## حافظه ChatGPT یک feature محصول است

Memory در ChatGPT با API context management یکی نیست. در ۲۰۲۶، بسته به plan، setting و rollout محصول، ChatGPT می‌تواند از context مرتبطِ chatها، فایل‌ها و connected appها برای personalization استفاده کند و memory system آن نیز در حال evolution است.

Reusable prompt را به memory شخصی کاربر وابسته نکنید مگر این dependency intentional و visible باشد. Promptی که باید در API یا محصول دیگری کار کند، context ضروری را خودش حمل کند.

## Tool use

Toolها مدل را فراتر از knowledge pretrained می‌برند، مثلاً:

- web search برای اطلاعات current؛
- file search و document retrieval؛
- code execution برای calculation/data analysis؛
- custom function برای actionهای application؛
- remote MCP server برای capability خارجی.

Prompt باید evidence یا action موردنیاز را مشخص کند؛ application فقط tool لازم را expose کند.

## چه زمانی Retrieval بهتر از Prompt است؟

یک knowledge base بزرگ را داخل static prompt نریزید اگر می‌توان فقط بخش مرتبط را در runtime retrieve کرد. Retrieval مناسب است وقتی:

- source سریع‌تر از prompt تغییر می‌کند؛
- در هر request فقط بخش کوچکی relevant است؛
- citation/provenance مهم است؛
- access control باید تعیین کند کدام document قابل مشاهده است.

## Retrieval-Augmented Generation (RAG)

Flow معمول:

```text
user query
  -> retrieval
  -> filtering / ranking
  -> selected context
  -> model answer
  -> citations / provenance
```

RAG صرفاً «اضافه کردن vector database» نیست. کیفیت به document quality، chunking، metadata، access control، query formulation، ranking/reranking، context assembly و citation handling بستگی دارد.

## رفتار در نبود پاسخ

سیستم grounded باید fallback روشن داشته باشد:

```text
برای ادعاهای factual فقط از sourceهای ارائه‌شده استفاده کن.
اگر sourceها پاسخ را پشتیبانی نمی‌کنند، بگو پاسخ از منابع موجود قابل تعیین نیست.
مگر اینکه کاربر صریحاً اجازه دهد، جای داده گمشده از general model knowledge استفاده نکن.
```

این wording حقیقت را تضمین نمی‌کند، اما unsupported behavior را قابل تست می‌کند.

## Retrieved content غیرقابل اعتماد است

Webpage، email، PDF، repository file، RAG chunk یا tool output ممکن است instruction برای دستکاری مدل داشته باشد. External content را به‌صورت پیش‌فرض **untrusted data** در نظر بگیرید.

Mitigationهای مهم:

- جدا کردن instruction از retrieved data؛
- محدودکردن tool permission؛
- validation argument و output ابزار؛
- authorization قبل از retrieval و قبل از action؛
- human approval برای عملیات حساس؛
- adversarial testing retrieval pipeline.

RAG و fine-tuning prompt injection را حذف نمی‌کنند.

## Citation discipline

اگر citation مهم است، از مدل بخواهید برای هر ادعای material source مشخص کند و سپس verify کنید source واقعاً آن claim را پشتیبانی می‌کند. وجود یک citation-shaped string به‌تنهایی evidence نیست.

## Context یک Budget است

Context را dump بی‌نهایت فرض نکنید. کوچک‌ترین context authoritative را نگه دارید که برای تصمیم صحیح و evidence لازم کافی باشد.
