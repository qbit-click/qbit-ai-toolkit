---
id: clarification-and-verification-loops
title: حلقه‌های Clarification و Verification
sidebar_label: Clarification و Verification Loop
---

# حلقه‌های Clarification و Verification

دو pattern در سیستم‌های پرامپت بخش بزرگی از خطاهای workflow را کم می‌کنند:

1. **Clarify before execute** — تا وقتی ambiguity مهم حل نشده، task را اجرا نکن.
2. **Verify and repair** — بعد از اجرا، نتیجه را با check قابل مشاهده تست کن و فقط وقتی evidence failure وجود دارد وارد repair شو.

این patternها وقتی قابل اعتمادترند که orchestrator state و iteration را کنترل کند. Prompt می‌تواند policy هر iteration را تعریف کند، اما loop واقعی خارجی به runtime نیاز دارد تا tool اجرا کند، نتیجه را ببیند و تصمیم بگیرد iteration دیگری مجاز است یا نه.

## Pattern 1: قبل از اجرا ابهام را رفع کن

نسخه ضعیف:

```text
قبل از شروع سؤال بپرس.
```

این کافی نیست. مدل ممکن است سؤال غیرضروری بپرسد، سؤال critical را جا بیندازد یا قبل از آماده شدن requirements وارد execution شود.

الگوی بهتر **Readiness Gate** دارد.

## Fieldهای لازم را تعریف کنید

برای یک task عمومی readiness ممکن است به این موارد وابسته باشد:

```text
- goal
- target user/system
- required inputs
- constraints
- output contract
- acceptance criteria
- risk/permission boundary در صورت مرتبط بودن
```

همه workflowها به همه fieldها نیاز ندارند. Required field را برای همان flow تعریف کنید.

## Material Ambiguity را تعریف کنید

فقط وقتی سؤال بپرسید که جواب آن می‌تواند materially یکی از این موارد را تغییر دهد:

- architecture یا implementation؛
- public behavior؛
- security/permission boundary؛
- action برگشت‌ناپذیر؛
- output format مصرف‌شده توسط سیستم دیگر؛
- acceptance criteria.

برای ambiguity جزئی، اگر policy اجازه می‌دهد assumption امن را اعلام و ادامه دهید.

## State Machine برای Clarification

```text
INTAKE
  -> known facts را استخراج کن
  -> required fieldهای خالی را پیدا کن
  -> ambiguity را material/non-material طبقه‌بندی کن

اگر material question وجود دارد:
  -> CLARIFY
  -> کوچک‌ترین مجموعه سؤال مفید را بپرس
  -> جواب را در task state merge کن
  -> readiness را دوباره بررسی کن

اگر سؤال material باقی نمانده:
  -> READY
  -> task brief را freeze کن
  -> EXECUTE
```

اطلاعاتی که user قبلاً داده است دوباره پرسیده نشود.

## Template: Clarify-before-execute

```text
تو در stage = INTAKE هستی.

Goal:
درخواست user را قبل از اجرا به یک task brief آماده اجرا تبدیل کن.

Required fields:
- objective
- inputs/source of truth
- material constraints
- required output
- acceptance criteria

Clarification policy:
- فقط سؤال‌هایی را بپرس که جوابشان می‌تواند correctness، scope، security، public behavior یا output contract را materially تغییر دهد.
- اطلاعاتی را که قبلاً داده شده دوباره نپرس.
- سؤال‌های مستقل را در صورت امکان در یک turn گروه‌بندی کن.
- در هر turn حداکثر 3 سؤال بپرس.
- برای ambiguity غیرمادی assumption را اعلام کن و block نکن.

Readiness gate:
تا وقتی هر required field یکی از این دو وضعیت را ندارد اجرا نکن:
1. مقدار صریح و معلوم؛
2. assumption مجاز و اعلام‌شده.

وقتی READY شدی task brief را با این headingها تولید کن:
- Objective
- Inputs
- Constraints
- Output contract
- Acceptance criteria
- Assumptions

اگر workflow نیاز به approval دارد، قبل از execution منتظر approval بمان.
```

## Task Brief را Freeze کنید

وقتی task آماده شد، یک brief canonical بسازید. Agentهای بعدی همان brief را دریافت کنند و original conversation را independently دوباره تفسیر نکنند.

برای کار high-impact، قبل از mutation approval صریح brief را بگیرید.

## Pattern 2: Verify and Repair

نسخه ضعیف:

```text
آن‌قدر تلاش کن تا درست شود.
```

این دستور unsafe است: تعریف success ندارد، attempt limit ندارد، evidence نمی‌خواهد و برای requirement اشتباه یا environment failure راه خروج ندارد.

به‌جایش از **bounded verification loop** استفاده کنید.

## حلقه Verification

```text
EXECUTE
   |
   v
VERIFY ---- pass ----> DONE
   |
  fail
   v
DIAGNOSE
   |
   v
REPAIR
   |
   +-------------> VERIFY
```

Verifier بر اساس observable check تصمیم می‌گیرد.

## ترتیب Verification

به‌صورت پیش‌فرض این ترتیب مناسب‌تر است:

1. deterministic check؛
2. integration/runtime check؛
3. specialist model review برای semantic issue؛
4. human review برای تصمیم high-impact یا subjective.

«خود مدل می‌گوید جوابش درست است» نباید تنها verifier باشد.

## Pass Criteria را قبل از Loop تعریف کنید

مثال:

```text
PASS when:
- همه automated testهای required پاس شوند؛
- lint/type error جدید ایجاد نشده باشد؛
- output با schema match کند؛
- security check blocking finding نداشته باشد؛
- برای همه acceptance criteria evidence وجود داشته باشد.
```

Verifier باید failure را structured برگرداند:

```yaml
status: fail
failed_checks:
  - id: test_payment_retry
    evidence: "expected 1 record, got 2"
failure_class: idempotency
recommended_scope: payment retry persistence only
```

## Repair Policy

Repair stage باید:

1. evidence واقعی failure را بررسی کند؛
2. کوچک‌ترین root cause plausible را پیدا کند؛
3. فقط scope لازم را تغییر دهد؛
4. check failشده را دوباره اجرا کند؛
5. regression set مرتبط را اجرا کند؛
6. attempt را ثبت کند.

برای سبز شدن test، requirement را silently تغییر ندهید.

## Stop Condition

Loop فقط با success متوقف نمی‌شود. در این شرایط stop و escalate کنید:

- maximum attempt رسیده؛
- همان failure بدون evidence جدید تکرار شده؛
- fix نیاز به product decision جدید دارد؛
- fix با security یا compatibility boundary تعارض دارد؛
- environment/tool unavailable است؛
- failure class جدید نشان می‌دهد scope در حال بزرگ شدن است؛
- verifier نمی‌تواند success را قابل اعتماد از failure تشخیص دهد.

## Attempt Budget

مثال ساده:

```text
max_attempts: 3

attempt 1:
  defect مبتنی بر evidence را fix کن

attempt 2:
  root cause را با evidence جدید دوباره ارزیابی کن

attempt 3:
  آخرین correction محدود

اگر هنوز fail است:
  stop و escalation report تولید کن
```

عدد مناسب workflow-specific است؛ مهم این است که finite و صریح باشد.

## Template: Bounded Repair Loop

```text
داخل یک bounded verification loop هستی.

Acceptance criteria:
[CRITERIA]

Current artifact:
[ARTIFACT]

Verifier evidence:
[EVIDENCE]

Attempt:
[CURRENT] of [MAX]

Rules:
- Evidence verifier را برای failure فعلی authoritative در نظر بگیر.
- Requirement را برای pass شدن check تغییر نده.
- کوچک‌ترین correction را برای root cause مبتنی بر evidence اعمال کن.
- بعد از تغییر verification مشخص‌شده را دوباره اجرا کن.
- اگر pass شد stop کن.
- اگر fail شد قبل از repair بعدی evidence جدید را ثبت کن.
- اگر product decision گمشده، security boundary، dependency unavailable یا scope expansion مانع fix امن است زودتر stop کن.
- از maximum attempt عبور نکن.

بعد از هر iteration برگردان:
- status
- change made
- evidence
- remaining failures
- next action
```

## Prompt Loop با Runtime Loop فرق دارد

این تفاوت مهم است.

### Self-review داخل یک Prompt

می‌توان گفت:

```text
یک draft بساز، آن را با rubric بررسی کن، issueهای پیدا‌شده را اصلاح کن و فقط final version را برگردان.
```

برای revision کم‌هزینه مفید است، اما check همچنان داخل همان execution/context انجام می‌شود.

### Runtime Verification Loop

Loop واقعی بیرون prompt کنترل می‌شود:

```text
model artifact می‌سازد
-> test tool اجرا می‌شود
-> orchestrator نتیجه را می‌خواند
-> failure evidence به model برمی‌گردد
-> model repair می‌کند
-> test tool دوباره اجرا می‌شود
```

وقتی verification به external truth وابسته است از runtime loop استفاده کنید: test، file، API response، database state، browser behavior، security scanner یا reviewer مستقل.

## Loop نامحدود نسازید

`تا رسیدن به نتیجه کامل ادامه بده` stop condition production نیست. «کامل» تعریف نشده و agent می‌تواند time/cost نامحدود مصرف یا سیستم را repeatedly mutate کند.

همیشه مشخص کنید:

- success چیست؛
- چه کسی آن را اندازه می‌گیرد؛
- حداکثر attempt/turn/time/cost؛
- mutation scope مجاز؛
- escalation condition؛
- rollback/recovery برای state-changing workflow.

## Implementer و Verifier را در صورت نیاز جدا کنید

```text
Implementer context
  -> artifact + evidence
Verifier context (read-only)
  -> pass / structured findings
Implementer context
  -> repair from findings
```

اگر independence مهم است، verifier نباید self-justification implementer را ببیند مگر اینکه خود آن توضیح بخشی از evidence مورد review باشد.

## Run Ledger نگه دارید

برای workflow طولانی state را explicit ثبت کنید:

```yaml
workflow_id: task-123
state: VERIFY
attempt: 2
requirements_version: 4
artifact_version: 7
checks:
  unit: pass
  integration: fail
  security: pending
last_failure: retry-idempotency
```

Ledger باید application state باشد، نه اطلاعاتی که انتظار داریم مدل از conversation طولانی بدون خطا به خاطر بسپارد.

## Anti-patternهای رایج

پرهیز کنید از:

- `تا وقتی کار کرد ادامه بده` بدون limit؛
- implementer به‌عنوان تنها judge موفقیت؛
- تکرار همان fix بدون evidence جدید؛
- تغییر test صرفاً برای سبز شدن؛
- full validation گران در هر iteration وقتی targeted check امن برای diagnosis کافی است؛
- پنهان کردن assumption حل‌نشده داخل repair loop؛
- اجازه mutation به reviewerی که باید artifact را independently inspect کند.

## Flow ترکیبی پیشنهادی

```text
INTAKE
  -> CLARIFY until READY
  -> freeze task brief
  -> EXECUTE
  -> deterministic VERIFY
      -> fail: bounded REPAIR loop
  -> independent REVIEW
      -> fail: bounded REPAIR loop
  -> SECURITY GATE
      -> fail: bounded REPAIR or escalation
  -> FINAL ACCEPTANCE
```

این pattern از workflow دستی در ChatGPT/Claude تا سیستم programmatic چند-agentی قابل توسعه است، چون contract، evidence و stop condition آن صریح هستند.
