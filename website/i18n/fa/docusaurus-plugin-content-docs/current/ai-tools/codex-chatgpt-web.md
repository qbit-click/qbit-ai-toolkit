---
id: codex-chatgpt-web
title: استفاده از مدل‌های وب ChatGPT در Codex با codex-chatgpt-web
sidebar_label: ChatGPT Web برای Codex
description: راهنمای نصب و راه‌اندازی codex-chatgpt-web برای استفاده از مدل‌های وب ChatGPT، از جمله ChatGPT Pro، داخل Codex در Windows، macOS و Linux.
keywords:
  - استفاده از مدل های وب در Codex
  - استفاده از ChatGPT Web در Codex
  - استفاده از ChatGPT Pro در Codex
  - مدل های وب برای Codex
  - codex-chatgpt-web
  - اتصال ChatGPT به Codex
  - ChatGPT Web for Codex
---

# استفاده از مدل‌های وب ChatGPT در Codex با codex-chatgpt-web

[`codex-chatgpt-web`](https://github.com/miuuyy/codex-chatgpt-web) یک bridge متن‌باز و مستقل است که امکان **استفاده از مدل‌های وب ChatGPT به‌عنوان مدل قابل انتخاب داخل Codex** را فراهم می‌کند. به‌جای اینکه task را از Codex خارج کنید و در یک ChatGPT browser chat جدا ادامه دهید، این ابزار Codex را به‌عنوان task harness اصلی نگه می‌دارد و فقط turn مربوط به مدل انتخاب‌شده را از طریق ChatGPT Web اجرا می‌کند.

این تفاوت، مهم‌ترین مزیت پروژه است: task history، lifecycle کانتکست، streaming، tracing، imageها، approvalها، sandbox و model picker خود Codex حفظ می‌شوند، اما می‌توانید از tierهای ChatGPT Web که حساب شما در اختیار می‌گذارد داخل همان workflow استفاده کنید.

> `codex-chatgpt-web` یک browser automation غیررسمی است؛ OpenAI API نیست و از طرف OpenAI تأیید یا endorse نشده است. فقط با حساب خودتان و مطابق policyهای ChatGPT، Codex و workspace از آن استفاده کنید.

## چرا از مدل‌های وب در Codex استفاده کنیم؟

اگر هدف شما **استفاده از مدل‌های وب در Codex** یا **استفاده از ChatGPT Pro در Codex** است، این پروژه دقیقاً برای همین سناریو طراحی شده است. به‌جای ساختن یک coding client دیگر، گزینه‌های `ChatGPT Web — ...` را به model workflow خود Codex اضافه می‌کند.

کاربردهای اصلی:

- **استفاده از ChatGPT Web داخل Codex:** task در همان Codex باقی می‌ماند و reasoning turn توسط ChatGPT Web انجام می‌شود.
- **استفاده از ChatGPT Pro در Codex:** اگر حساب احراز هویت‌شده Pro را expose کند، launcher گزینه Pro را به model picker اضافه می‌کند.
- **جابه‌جایی بین مدل‌های native Codex و مدل‌های وب:** proxy provider اصلی `openai` و live model catalog خود Codex را نگه می‌دارد و مدل‌های ChatGPT Web را کنار آن‌ها اضافه می‌کند.
- **حفظ کانتکست و task history:** هر browser turn کانتکست compile‌شده فعلی Codex را در یک ChatGPT Temporary Chat تازه دریافت می‌کند.
- **حفظ image و streaming در همان task:** attachmentها و فعالیت قابل مشاهده response دوباره به task فعال Codex برمی‌گردند.
- **اتصال اختیاری ابزارهای local Codex:** در Full Harness، مدل‌های وب پشتیبانی‌شده می‌توانند از طریق MCP و OpenAI Tunnel به toolهای همان Codex turn دسترسی پیدا کنند.

هدف پروژه تغییر **model backend** است، نه جایگزین کردن workflow خود Codex.

## معماری کلی

مسیر ساده‌شده به شکل زیر است:

```text
Codex task
   │
   │ Responses + SSE روی loopback
   ▼
codex-chatgpt-web launcher/runtime
   │
   │ embedded browser
   ▼
ChatGPT Web / Temporary Chat
   │
   └── Full Harness اختیاری: MCP → OpenAI Tunnel → ابزارهای فعال Codex
```

Codex همچنان source of truth برای task محلی است. Bridge یک Responses service روی loopback اجرا می‌کند، برای browser turn یک Temporary Chat تازه باز می‌کند و خروجی را به Codex stream می‌کند. در Full Harness نیز connector سفارشی ChatGPT می‌تواند tool call پشتیبانی‌شده را به همان task فعال Codex برگرداند.

## اسکرین‌شات‌های demo رسمی پروژه

تصاویر زیر از frameهای `assets/demo.gif` رسمی repository اصلی استخراج شده‌اند و صرفاً برای آشنایی با جریان setup در این مستند قرار گرفته‌اند.

![نمای launcher در codex-chatgpt-web](/img/codex-chatgpt-web/launcher-setup.png)

*نمونه‌ای از جریان setup در demo رسمی upstream.*

![انتخاب مدل ChatGPT Web در Codex](/img/codex-chatgpt-web/model-picker.png)

*مدل‌های ChatGPT Web در workflow انتخاب مدل Codex قرار می‌گیرند.*

![استفاده از مدل وب ChatGPT در Codex](/img/codex-chatgpt-web/codex-web-model.png)

*یک turn مبتنی بر ChatGPT Web در demo رسمی پروژه.*

## تفاوت Browser-only و Full Harness

Launcher دو حالت عملیاتی اصلی دارد:

| حالت | مدل‌های وب | ابزارهای local Codex | راه‌اندازی اضافه |
| --- | --- | --- | --- |
| Browser-only | Free/Go: Luna؛ Plus: Instant تا High؛ Pro: اضافه شدن Extra High و Pro | خیر | فقط sign-in و setup launcher |
| Full Harness | همان مجموعه وابسته به حساب | مدل‌های غیر-Pro: در صورت وجود connector بله؛ Pro: read-only | OpenAI Tunnel + ChatGPT connector |

مدل‌های قابل انتخاب به حساب شما وابسته‌اند. Launcher controlهایی را که حساب sign-in شده واقعاً expose می‌کند تشخیص می‌دهد و فرض نمی‌کند همه حساب‌ها به همه tierها دسترسی دارند.

### رفتار مهم Pro

**استفاده از ChatGPT Pro در Codex زمانی ممکن است که Pro روی حساب احراز هویت‌شده در دسترس باشد.** با این حال، طبق وضعیت فعلی upstream، ChatGPT Pro custom MCP connector موردنیاز برای tool callهای local را expose نمی‌کند. بنابراین Pro می‌تواند کانتکست compile‌شده Codex را دریافت کند و از قابلیت‌های native خود مثل web search و research استفاده کند، اما نمی‌تواند از طریق این bridge یک MCP action محلی در Codex آغاز کند.

یک workflow عملی این است که context gathering و tool work محلی را با یکی از web modeهای غیر-Pro پشتیبانی‌شده انجام دهید و در صورت نیاز برای تحلیل عمیق‌تر به Pro سوییچ کنید.

## سیستم‌عامل‌های پشتیبانی‌شده

پروژه upstream در حال حاضر launcher package برای این پلتفرم‌ها منتشر می‌کند:

- Windows x64؛
- Linux x64؛
- macOS 13+ روی arm64 و x64.

طبق مستندات upstream، browser flow به‌صورت دستی روی macOS و Windows 11 تست شده و runtime، testها و native packaging در CI روی هر سه خانواده سیستم‌عامل gate می‌شوند.

## پیش‌نیازها

برای مسیر عادی launcher نیاز دارید:

- Codex نصب و قابل استفاده باشد؛
- یک حساب ChatGPT داشته باشید؛
- Google Chrome یا Chromium برای sign-in handoff نصب باشد؛
- دسترسی شبکه به ChatGPT و GitHub Releases داشته باشید.

برای استفاده معمول از مدل‌های وب در Codex به **model API key، Node.js سیستم، Bun سیستم یا browser دانلودشده توسط Playwright نیاز ندارید**. Launcher بسته‌بندی‌شده runtime خودش را دارد و Chrome/Chromium نصب‌شده را فقط برای handoff ورود سازگار با passkey استفاده می‌کند؛ turnهای مدل داخل embedded browser خود launcher اجرا می‌شوند.

Full Harness پیش‌نیازهای اضافه دارد که پایین‌تر توضیح داده شده است.

## نصب روی Windows

PowerShell را باز کنید و installer آخرین GitHub Release را اجرا کنید:

```powershell
irm https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.ps1 | iex
```

بعد از نصب، launcher را باز کنید و setup checks را انجام دهید.

> تا زمانی که release موردنظر platform signing کامل نداشته باشد ممکن است Windows SmartScreen هشدار unknown publisher نشان دهد. Installer upstream قبل از نصب manifest منتشرشده SHA-256 را verify می‌کند.

## نصب روی macOS یا Linux

دستور زیر را اجرا کنید:

```bash
curl -fsSL https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh | sh
```

بعد launcher را باز کرده و sign-in را ادامه دهید.

## اجرا از source

اگر بخواهید پروژه را مستقیماً از source اجرا کنید:

```bash
git clone https://github.com/miuuyy/codex-chatgpt-web.git
cd codex-chatgpt-web
bun run app
```

مسیر source طبق upstream فعلی به **Bun 1.3.14** نیاز دارد. اگر فقط هدفتان استفاده از مدل‌های وب در Codex است، packaged launcher معمولاً گزینه ساده‌تر و مناسب‌تری است.

## راه‌اندازی اولیه: اتصال ChatGPT Web به Codex

بعد از نصب launcher:

1. Launcher را باز کنید.
2. **Sign in** را شروع کنید.
3. احراز هویت ChatGPT را در Chrome/Chromium اختصاصی که launcher باز می‌کند کامل کنید و تا پایان verification پنجره را باز نگه دارید.
4. **browser smoke test** را اجرا کنید.
5. روی **Install models** بزنید.
6. Codex را یک‌بار restart کنید.
7. Model picker خود Codex را باز کنید و یکی از گزینه‌های `ChatGPT Web — ...` را انتخاب کنید.

از این مرحله به بعد می‌توانید **مدل وب ChatGPT را مستقیماً در Codex استفاده کنید** و نیازی به انتقال دستی task به یک chat جدا ندارید.

Mapping حساب‌ها در مستند upstream فعلی:

- Free/Go: `Luna`؛
- Plus: از `Instant` تا `High`؛
- Pro: در صورت expose شدن توسط حساب، `Extra High` و `Pro` نیز اضافه می‌شوند.

## استفاده روزمره از مدل‌های وب ChatGPT در Codex

بعد از Install models، workflow عادی داخل Codex باقی می‌ماند:

1. یک Codex task را باز کنید یا ادامه دهید.
2. Native model picker را باز کنید.
3. مدل `ChatGPT Web — ...` موردنظر را انتخاب کنید.
4. task را مثل همیشه ارسال کنید.
5. Bridge کانتکست compile‌شده فعلی Codex را به یک Temporary Chat تازه می‌فرستد.
6. response، فعالیت قابل مشاهده، imageها و lifecycle ابزارهای پشتیبانی‌شده به همان Codex task بازمی‌گردند.

مزیت کلیدی این است که **برای استفاده از مدل‌های وب در Codex لازم نیست یک browser conversation موازی نگه دارید یا context repository را مرتب بین Codex و ChatGPT کپی کنید.**

## راه‌اندازی اختیاری Full Harness

اگر فقط reasoning مدل‌های ChatGPT Web را داخل Codex می‌خواهید، Browser-only کافی است. Full Harness زمانی لازم است که web modeهای پشتیبانی‌شده بخواهند toolهای task فعال Codex را هم فراخوانی کنند.

Flow فعلی upstream:

1. ابتدا setup عادی launcher را کامل کنید.
2. صفحه **MCP** را در launcher باز کنید.
3. یک OpenAI Tunnel و یک regular API key روی همان OpenAI account که connector را استفاده می‌کند بسازید.
4. Tunnel ID و API key را در launcher وارد کرده و **Connect harness** را بزنید.
5. Developer Mode را در ChatGPT فعال کنید.
6. یک connector **جدید** با Tunnel transport بسازید.
7. Authentication را روی `None` قرار دهید.
8. نام connector را دقیقاً **`Codex Native2`** بگذارید.
9. در صورتی که policy workspace اجازه می‌دهد، Permission را روی **Allow all actions** قرار دهید.
10. در launcher گزینه **Verify runtime** را اجرا کنید.

Connector قدیمی `Codex Native` را rename یا reuse نکنید. Contract فعلی direct turn-token از identity جدید `Codex Native2` استفاده می‌کند و upstream عمداً legacy connector را به‌عنوان fallback قبول نمی‌کند.

API key این بخش برای OpenAI Tunnel استفاده می‌شود؛ معنی آن این نیست که turn مدل وب به model API call تبدیل می‌شود. با این حال حساب و policy workspace باید connector actionهای موردنظر را اجازه دهند.

## Full Harness چه چیزهایی را حفظ می‌کند؟

در Full Harness، bridge به یک coding agent دوم تبدیل نمی‌شود. همچنان Codex مالک موارد زیر است:

- task فعال؛
- filesystem و shell tools؛
- sandbox policy؛
- approvalها؛
- command sessionها؛
- tool resultها.

Bridge فقط تصمیم tool مدل وب پشتیبانی‌شده را به همان Codex turn برمی‌گرداند. ترکیب‌های unsupported به‌صورت explicit fail می‌شوند و قرار نیست مخفیانه به مدل یا transport دیگری fallback شود.

## آپدیت یا Repair

Launcher را ببندید و همان installer مربوط به سیستم‌عامل را دوباره اجرا کنید.

### Windows

```powershell
irm https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.ps1 | iex
```

### macOS/Linux

```bash
curl -fsSL https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh | sh
```

طبق upstream، reinstall باعث جایگزینی application و embedded runtime می‌شود و ChatGPT profile و launcher configuration را حفظ می‌کند.

## Health check و عملیات روزمره

عملیات فعلی عمدتاً از UI launcher در دسترس‌اند:

- **Activity** — logهای ساخت‌یافته local؛
- **Settings → Run doctor** — health check انتها‌به‌انتها؛
- **Settings → Cancel retained browser turn** — پاک کردن browser turn باقی‌مانده بعد از stop شدن task؛
- **Settings → Remove Codex integration** — restore کردن route قبلی Codex قبل از حذف launcher؛
- **MCP** — setup مربوط به Full Harness و Tunnel.

برای debug مرورگر، runtime از `CODEX_CHATGPT_WEB_BROWSER_DIAGNOSTICS=1` هم پشتیبانی می‌کند. با فعال کردن آن در هر checkpoint اسکرین‌شات diagnostic ثبت می‌شود. در حالت عادی screenshot بیشتر برای turnهای stalled یا failed ذخیره می‌شود که مشاهده UI برای تشخیص DOM drift لازم است.

## امنیت و حریم خصوصی

استفاده از ChatGPT Web در Codex مسیر داده را تغییر می‌دهد و باید به‌عنوان یک trust decision صریح در نظر گرفته شود.

نکات مهم از security model upstream:

- Temporary Chat یک privacy mode است، نه local inference یا anonymity. Prompt همچنان توسط OpenAI و مطابق تنظیمات حساب پردازش می‌شود.
- Responses bridge فقط روی loopback (`127.0.0.1`) listen می‌کند، اما process دیگری با همان OS user می‌تواند به این surface محلی دسترسی داشته باشد.
- Browser profile launcher شامل authenticated state حساس است؛ آن را sync، upload، attach یا commit نکنید.
- Full Harness می‌تواند write/command capability داشته باشد، اگر workspace، connector permissions و sandbox/approval policy Codex اجازه دهند.
- Repository content، tool output، website و prompt text داده قابل اعتماد محسوب نمی‌شوند و ممکن است prompt injection داشته باشند.
- Project در برابر model/capability unsupported یا browser UI drift explicit fail می‌شود و نباید مخفیانه backend دیگری انتخاب کند.
- هدف پروژه دور زدن plan، workspace control، usage limit، authentication یا access restriction نیست.

Full Harness را فقط روی workstation قابل اعتماد و با permissionهایی فعال کنید که با هدف task سازگار هستند.

## Troubleshooting

### مدل‌های ChatGPT Web در Codex دیده نمی‌شوند

- اعتبار sign-in launcher را بررسی کنید؛
- browser smoke test را دوباره اجرا کنید؛
- **Install models** را دوباره بزنید؛
- Codex را یک‌بار restart کنید؛
- **Settings → Run doctor** را اجرا و **Activity** را برای error صریح بررسی کنید.

### مدل Pro دیده نمی‌شود

Pro فقط زمانی اضافه می‌شود که حساب ChatGPT احراز هویت‌شده واقعاً آن mode را expose کند. Launcher دسترسی به tierی که حساب ندارد ایجاد نمی‌کند.

### ابزارهای local Codex در دسترس نیستند

اگر Browser-only هستید این رفتار طبیعی است. برای tool call مدل‌های وب غیر-Pro باید Full Harness را راه‌اندازی کنید.

اگر Full Harness راه‌اندازی شده، بررسی کنید:

- Tunnel connected باشد؛
- Developer Mode در ChatGPT فعال باشد؛
- connector دقیقاً `Codex Native2` نام داشته باشد؛
- permission صحیح انتخاب شده باشد؛
- **Verify runtime** launcher پاس شود.

### ChatGPT Pro نمی‌تواند فایل ویرایش کند

این محدودیت فعلی product/bridge است، نه خطای setup. Pro می‌تواند compiled context مربوط به Codex را دریافت کند، اما نمی‌تواند custom MCP call این پروژه را آغاز کند. برای local tool round از web mode غیر-Pro پشتیبانی‌شده استفاده کنید.

### Selectorهای browser از کار می‌افتند

این پروژه ChatGPT browser UI را automate می‌کند و DOM یک API پایدار نیست. در صورت UI drift، releaseها و repository upstream را بررسی کنید و validation را برای اجبار fallback تضعیف نکنید.

## سوالات متداول درباره استفاده از مدل‌های وب در Codex

### آیا می‌توانم مدل‌های ChatGPT Web را مستقیم داخل Codex استفاده کنم؟

بله. هدف اصلی `codex-chatgpt-web` همین است: مدل‌های ChatGPT Web قابل دسترس برای حساب شما را به model workflow بومی Codex اضافه می‌کند و turn انتخاب‌شده را از طریق ChatGPT Web اجرا می‌کند.

### آیا می‌توانم ChatGPT Pro را در Codex استفاده کنم؟

بله، اگر Pro در حساب احراز هویت‌شده در دسترس باشد. Pro کانتکست فعلی Codex را دریافت می‌کند، اما در وضعیت فعلی نمی‌تواند custom MCP connector این bridge را برای toolهای local Codex استفاده کند.

### برای استفاده از ChatGPT Web در Codex به OpenAI API key نیاز دارم؟

برای Browser-only و turn عادی مدل وب خیر. Full Harness برای OpenAI Tunnel یک regular API key می‌خواهد، اما model turn همچنان از authenticated ChatGPT browser session route می‌شود و model API key نیست.

### آیا codex-chatgpt-web جای Codex را می‌گیرد؟

خیر. Codex task harness باقی می‌ماند. این پروژه فقط route مدل انتخابی را تغییر می‌دهد و native workflow Codex را حفظ می‌کند.

### آیا این integration رسمی OpenAI است؟

خیر. پروژه مستقل و متن‌باز است و upstream صریحاً اعلام می‌کند که وابسته به OpenAI یا مورد تأیید آن نیست.

## منابع اصلی

- Repository و setup فعلی: [miuuyy/codex-chatgpt-web](https://github.com/miuuyy/codex-chatgpt-web)
- معماری: [docs/architecture.md](https://github.com/miuuyy/codex-chatgpt-web/blob/main/docs/architecture.md)
- مدل امنیتی: [docs/security-model.md](https://github.com/miuuyy/codex-chatgpt-web/blob/main/docs/security-model.md)

جزئیات setup و capabilityهای این صفحه در **2026-08-11** با repository upstream تطبیق داده شده‌اند. چون این integration به ChatGPT UI، routing behavior در Codex و releaseهای launcher وابسته است، در نصب‌های آینده مستند upstream را دوباره بررسی کنید.
