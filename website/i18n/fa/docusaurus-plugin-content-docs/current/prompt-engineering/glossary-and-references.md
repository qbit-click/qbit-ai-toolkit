---
id: glossary-and-references
title: واژه‌نامه و منابع
sidebar_label: واژه‌نامه و منابع
---

# واژه‌نامه و منابع

## واژه‌نامه

| اصطلاح | معنی |
|---|---|
| Prompt | ورودی‌ای که به تعیین پاسخ یا action بعدی مدل کمک می‌کند و ممکن است فقط متن نباشد. |
| Prompt Engineering | طراحی و ارزیابی instruction، context، example، tool و output contract برای رفتار هدف. |
| Token | واحد پردازش متن مدل؛ مرز token الزاماً با مرز کلمه یکسان نیست. |
| Context Window | بیشترین context قابل پردازش در interaction/state مدل، مطابق محدودیت model و API. |
| Zero-shot | درخواست انجام task بدون example داخل prompt. |
| One-shot | ارائهٔ یک مثال دقیق برای نمایش قالب یا رویهٔ لازم؛ پوشش آن برای موارد مرزی محدود است. |
| Few-shot | ارائه چند example محدود برای نمایش task یا convention خروجی. |
| Step-back Prompting | استخراج یا بازیابی اصل و معیار سطح‌بالا پیش از اعمال آن‌ها به وظیفهٔ مشخص. |
| Chain-of-Thought (CoT) | intermediate reasoning trace. در مدل‌های قدیمی‌تر elicitation آن در برخی taskها مفید بود؛ برای reasoning modelهای جدید بهتر است به‌جای private reasoning، evidence یا summary قابل verify درخواست شود. |
| Reasoning Model | model familyای که برای task پیچیده inference/reasoning بیشتری انجام می‌دهد و ممکن است control اختصاصی reasoning داشته باشد. |
| Self-Consistency | sampling چند candidate و aggregate کردن answerها. |
| ReAct | الگوی پژوهشی/ایجنتی برای ترکیب تصمیم مدل، tool/action و observation. |
| Tree of Thoughts | الگوی search/orchestration برای بررسی و ارزیابی چند branch استدلالی جایگزین. |
| Structured Outputs | خروجی constrained در سطح API بر اساس schema، معمولاً JSON Schema در modelهای supported. |
| Function / Tool Calling | انتخاب tool و تولید argument توسط مدل، در حالی که execution توسط application انجام می‌شود. |
| MCP | Model Context Protocol برای expose کردن tool/resource از serverهای سازگار به مدل یا agent. |
| RAG | Retrieval-Augmented Generation: بازیابی context خارجی مرتبط پیش از generation. |
| Prompt Injection | instruction مخرب یا ناخواسته که behavior مدل را تغییر می‌دهد؛ می‌تواند direct یا indirect باشد. |
| System / Developer Instruction | instruction با priority بالاتر در APIهای دارای role hierarchy؛ secret store یا authorization boundary نیست. |
| Hallucination | output نادرست، ساختگی یا unsupported که ممکن است plausible ارائه شود. |
| Eval | تست تکرارپذیر برای سنجش behavior مدل/prompt با criteria مشخص. |
| Prompt Optimization | ساخت و انتخاب نسخه‌های پیشنهادی پرامپت بر اساس قرارداد ارزیابی مشخص؛ همچنان به اعتبارسنجی با دادهٔ کنارگذاشته‌شده نیاز دارد. |
| Multimodal Prompting | طراحی پرامپت و قرارداد شواهد برای متن، تصویر، ویدئو، صوت یا سند. |
| Prompt Template / Variable | الگوی دستورِ قابل استفادهٔ مجدد و نسخه‌دار، به‌همراه قرارداد نوع‌دار برای جایگزینی متغیر و رفتار مقدار گمشده. |
| Fine-tuning | تغییر behavior آموخته‌شده مدل با training data؛ با few-shot example داخل یک request متفاوت است. |
| AI Agent | سیستمی که مدل در چند step تصمیم می‌گیرد و تحت orchestration/permission مشخص از tool یا سیستم خارجی استفاده می‌کند. |

## اصلاحات اصلی نسبت به جزوه v4

جزوه منبع یک پایه مقدماتی مفید دارد، اما در این documentation این موارد اصلاح شده‌اند:

- اصطلاح استاندارد **Prompt Engineering** جای `Engineering Prompt` معکوس را گرفته است؛
- Chain-of-Thought عمدتاً به‌عنوان زمینه تاریخی/پژوهشی معرفی می‌شود و از reasoning model جدید private reasoning مطالبه نمی‌شود؛
- ReAct و Tree of Thoughts از «ترفند یک‌خطی prompt» به orchestration/search pattern منتقل شده‌اند؛
- role promptهای مبتنی بر سابقه ساختگی با perspective و review criteria explicit جایگزین شده‌اند؛
- مثال‌های OpenAI بر اساس Responses API، Structured Outputs، `reasoning.effort` و `max_output_tokens` به‌روز شده‌اند؛
- range ثابت temperature و recipe عمومی parameterها حذف شده است؛
- Structured Outputs/JSON Schema شکل خروجی را محدود می‌کند، نه درستی واقعیت‌ها را؛
- تعداد همگانی برای مثال‌های Few-shot تجویز نمی‌شود؛
- BLEU/ROUGE معیار پیش‌فرض و عمومی برای کیفیت پرامپت نیستند؛
- دستور ثابت برای نمونه‌گیری یا CoT/temperature یک قانون همگانی نیست؛
- پرامپت‌نویسی چندوجهی و کدنویسی به قابلیت، امنیت، اعتبارسنجی و زمینهٔ عملیاتی نیاز دارند؛
- ChatGPT Memory از API conversation state جدا شده است؛
- صریح شده که system prompt یک secret یا authorization boundary نیست؛
- RAG با access control، citation validation و indirect prompt injection کامل‌تر شده است؛
- eval و regression test بخشی از lifecycle prompt شده‌اند، نه صرفاً review اختیاری در پایان.

## منابع پژوهشی پایه

Techniqueهای تاریخی این راهنما از پژوهش‌های شناخته‌شده زیر می‌آیند:

- Brown et al. (2020), *Language Models are Few-Shot Learners*.
- Wei et al. (2022), *Chain-of-Thought Prompting Elicits Reasoning in Large Language Models*.
- Kojima et al. (2022), *Large Language Models are Zero-Shot Reasoners*.
- Wang et al. (2022), *Self-Consistency Improves Chain of Thought Reasoning in Language Models*.
- Yao et al. (2023), *ReAct: Synergizing Reasoning and Acting in Language Models*.
- Yao et al. (2023), *Tree of Thoughts: Deliberate Problem Solving with Large Language Models*.
- Lewis et al. (2020), *Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks*.

این مقاله‌ها performance تکنیک‌ها را در settingهای مشخص نشان می‌دهند؛ نتیجه آن‌ها را نباید تضمین بهبود برای هر model فعلی دانست.

## منابع عملیاتی فعلی

برای implementation، documentation فعلی رسمی را به جدول‌های parameter ثابت در tutorialهای قدیمی ترجیح دهید:

- OpenAI Help Center — *Prompt engineering best practices for ChatGPT*.
- OpenAI Help Center — *Best practices for prompt engineering with the OpenAI API*.
- OpenAI API Reference — Responses API، roleها، reasoning، tools و Structured Outputs.
- OpenAI documentation — model compatibility/versioning و eval guidance.
- OpenAI Help Center — ChatGPT Memory.
- Google Cloud — *Overview of prompting strategies* و راهنمای پرامپت‌نویسی Gemini/Vertex AI.
- Google Cloud — مستندات *Vertex AI Prompt Optimizer*.
- Google Cloud — راهنمای پرامپت‌نویسی چندوجهی برای تصویر، ویدئو، صوت و سند.
- OWASP GenAI Security Project — `LLM01:2025 Prompt Injection`.
- OWASP GenAI Security Project — `LLM07:2025 System Prompt Leakage`.
- OWASP GenAI Security Project — guidance فعلی RAG/vector/embedding risk.

## تاریخ بازبینی

این مستندات در **۲۰۲۶-۰۸-۳۱** با منابع عمومی فعلی بازبینی فنی شده است. رفتار ارائه‌دهندگان سریع تغییر می‌کند؛ پیش از واردکردن نام پارامتر، مقدار پشتیبانی‌شده یا تاریخ چرخهٔ عمر به کد عملیاتی، مرجع همان مدل/API را دوباره بررسی کنید.
