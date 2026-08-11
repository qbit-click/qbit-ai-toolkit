---
id: prompt-systems-and-orchestration
title: سیستم‌های پرامپت و Orchestration
sidebar_label: سیستم پرامپت و Orchestration
---

# سیستم‌های پرامپت و Orchestration

برای کار چندمرحله‌ای قابل اعتماد، یک prompt بزرگ معمولاً کافی نیست. **Prompt System** ترکیبی است از promptهای نقش‌ها، state، toolها، قرارداد handoff، verifier، سیاست retry و یک orchestrator که تعیین می‌کند مرحله بعدی چیست.

سؤال اصلی این نیست که «چند persona را داخل یک prompt بنویسیم؟»؛ سؤال اصلی این است که **کنترل workflow کجا قرار دارد** و **کدام مرحله باید context یا permission مستقل داشته باشد**.

## اجزای اصلی

- **Prompt** — instruction و context برای یک task یا role.
- **Skill** — دانش عملیاتی reusable: روش، checklist، example، راهنمای tool و output schema.
- **Agent** — مدل همراه instruction، tool، context/state و در صورت نیاز delegation.
- **Workflow** — ترتیب یا graph از پیش تعریف‌شده مراحل.
- **Orchestrator** — ترتیب stageها، انتقال state، retry/limit و finalization را کنترل می‌کند.
- **Verifier** — check deterministic، reviewer تخصصی یا human gate که نتیجه را با evidence ارزیابی می‌کند.

قاعده مفید:

> Skill مشخص می‌کند **متخصص چگونه کار کند**؛ Orchestrator مشخص می‌کند **چه زمانی آن متخصص اجرا شود**.

## Workflow یا Agent-driven Flow؟

وقتی stageهای اجباری از قبل مشخص‌اند از **workflow** استفاده کنید:

```text
Intake
  -> Clarify
  -> Implement
  -> Test
  -> Security review
  -> Repair if needed
  -> Final acceptance
```

اگر test و security review همیشه باید اجرا شوند، آن‌ها را در workflow enforce کنید. تصمیم اجرای این gateها را به LLM واگذار نکنید.

Agent-driven routing زمانی مناسب است که مرحله بعدی واقعاً به judgment باز نیاز دارد؛ مثلاً انتخاب specialist، انتخاب source یا شکستن task به subtaskهای موازی.

معمولاً معماری hybrid بهتر است: code gateهای mandatory را کنترل کند و agent داخل هر gate تصمیم محدود بگیرد.

## معماری پیشنهادی: Implementation -> Test -> Security

```text
Requirements / acceptance criteria
            |
            v
      +-------------+
      | Implementer |
      +------+-------+
             |
             v
      deterministic tests
             |
       fail / \ pass
           /   \
      repair    v
         ^   security reviewer
         |        |
         +--fail  | pass
                  v
             final acceptance
```

Reviewer باید **evidence** را بررسی کند، نه اعتمادبه‌نفس implementer را. requirements، artifact/diff واقعی، test output، logهای مرتبط و decisionهای قطعی را منتقل کنید.

## یک Chat یا Contextهای جدا؟

مرحله‌ها را در یک conversation نگه دارید وقتی continuity از independence مهم‌تر است؛ مثل clarification، drafting یا refinement یک artifact.

Context/session مستقل استفاده کنید وقتی stage باید review مستقل بدهد، context محدودتری ببیند، permission متفاوت داشته باشد یا از توضیح implementer anchor نشود. Test review و security review معمولاً از این جداسازی سود می‌برند.

این دستور independence واقعی ایجاد نمی‌کند:

```text
نقش قبلی را فراموش کن و حالا یک security reviewer مستقل باش.
```

اگر در همان conversation هستیم، مدل هنوز history و assumptionهای قبلی را دارد.

## Handoff ساختاریافته

به specialist جدید به‌جای کل transcript یک artifact فشرده بدهید:

```yaml
stage: security_review
objective: verify the implemented change
requirements:
  - auth boundary must not change
  - secrets must not be logged
artifacts:
  diff: <reference>
  test_results: <reference>
known_decisions:
  - public API compatibility is required
review_output:
  - status
  - findings
  - evidence
  - required_corrections
```

این کار hidden coupling را کم و context filtering را صریح می‌کند.

## Manager در برابر Handoff

### Manager / Agents-as-tools

یک manager مرکزی کنترل را نگه می‌دارد و specialistها را فراخوانی می‌کند.

برای حالتی مناسب است که یک front door با user صحبت کند، چند نتیجه باید aggregate شوند یا budget/guardrail مرکزی لازم است. برای `implementation -> test -> security -> final synthesis` انتخاب مناسبی است.

### Handoff

Agent فعلی کنترل conversation را به specialist واگذار می‌کند.

وقتی routing dynamic است و specialist باید ادامه conversation را در دست بگیرد مفید است. برای pipeline ثابت و اجباری، code orchestration معمولاً از chain کردن handoffهای model-selected قابل پیش‌بینی‌تر است.

## داخل Skill چه چیزی قرار بگیرد؟

مثلاً `security-review` skill می‌تواند شامل این موارد باشد:

```text
- threat-model checklist
- trust-boundary review method
- secret-handling checks
- dependency-risk checks
- evidence requirements
- finding severity rubric
- allowed read-only tools
- output schema
```

Global workflow ordering، retry نامحدود، state مخصوص یک run یا authorization control را داخل skill قرار ندهید؛ این‌ها متعلق به orchestration/application هستند.

## Custom GPT یا Custom Assistant چه نقشی دارد؟

Custom GPT برای بسته‌بندی **یک assistant reusable** با instruction، knowledge و capability ثابت مفید است؛ مثلاً «Security Reviewer» یا «Prompt Designer».

اما به‌تنهایی orchestration engine چند-agentی قابل اتکا نیست. جابه‌جایی دستی بین GPT/chat برای workflow شخصی ممکن است، اما sequence خودکار، retry policy، state transition و independent verification باید در orchestration layer باشد اگر reliability مهم است.

برای automation از API/agent SDK یا workflow runtime صریح استفاده کنید.

## Workflow فقط در UI

اگر می‌خواهید کاملاً داخل ChatGPT یا Claude UI بمانید:

1. clarification را در chat اصلی انجام دهید؛
2. یک task brief نهایی و frozen بسازید؛
3. implementation را در یک chat/assistant اجرا کنید؛
4. task brief + artifact + evidence را به context مستقل test/review بدهید؛
5. findingها را به implementation context برگردانید؛
6. با attempt limit صریح تکرار کنید؛
7. security review را در context مستقل دیگری اجرا کنید؛
8. یک run ledger کوچک بیرون از chat نگه دارید.

این روش برای استفاده شخصی قابل انجام است، اما coordination دستی دارد و state راحت‌تر drift می‌کند.

## Workflow برنامه‌نویسی‌شده

برای automation تکرارپذیر state machine را در code صریح کنید:

```text
CLARIFY -> READY -> EXECUTE -> VERIFY -> SECURITY -> DONE
                          ^        |          |
                          |        v          v
                          +----- REPAIR <-----+
```

State را explicit ذخیره کنید و به memory conversation وابسته نباشید.

## Agentهای موازی

Parallelism وقتی مفید است که reviewها مستقل باشند:

```text
                 -> dependency review ---+
implementation -> test review -----------+-> aggregator
                 -> security review ------+
```

چند agent را بدون isolation روی یک workspace mutable مشترک همزمان رها نکنید؛ race و merge دشوار ایجاد می‌شود.

## Independence یک ویژگی معماری است

Reviewer وقتی مستقل‌تر است که context جدا، rubric جدا، read-only access، tool evidence مستقل و عدم دسترسی به self-justification implementer داشته باشد. تغییر نام role به‌تنهایی استقلال ایجاد نمی‌کند.

## معماری پیشنهادی برای Workflowهای reusable

```text
Workflow definition
  -> stage contracts
  -> specialist skills
  -> agent configurations
  -> tools/permissions
  -> verifier gates
  -> bounded repair policy
  -> trace/run ledger
```

Workflow definition را از skill جدا نگه دارید تا یک skill بتواند در چند flow استفاده شود.

## منابع رسمی

- OpenAI Agents SDK — Agent orchestration: https://openai.github.io/openai-agents-python/multi_agent/
- OpenAI Agents SDK — Handoffs: https://openai.github.io/openai-agents-python/handoffs/
- OpenAI Help — GPTs in ChatGPT: https://help.openai.com/en/articles/8554407-gpts-in-chatgpt
- Anthropic Engineering — Building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic Engineering — Multi-agent research system: https://www.anthropic.com/engineering/multi-agent-research-system
