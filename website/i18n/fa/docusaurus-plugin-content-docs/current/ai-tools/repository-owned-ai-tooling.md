---
id: repository-owned-ai-tooling
title: پیاده‌سازی AI Tooling تحت مالکیت Repository
sidebar_label: AI Tooling تحت مالکیت Repository
---

# پیاده‌سازی AI Tooling تحت مالکیت Repository

این راهنما یک معماری و روند عمومی برای اضافه کردن ابزارهای توسعه مبتنی بر AI به یک repository را توضیح می‌دهد؛ به‌گونه‌ای که ابزارها به‌صورت ضمنی مالک application، وضعیت Git، ماشین توسعه‌دهنده یا محیط production نشوند.

این الگو برای ترکیبی از موارد زیر قابل استفاده است:

- ابزارهای local برای semantic/code intelligence؛
- analyzerهای معماری و dependency؛
- MCP serverها؛
- connectorهای remote برای documentation یا incident؛
- Skillها و routing policyهای agent؛
- bootstrap، readiness، doctor و validatorهای repository-local.

محصولاتی مانند Serena، Graphify، Context7، Sentry، Codex، Claude یا هر client سازگار با MCP فقط **نمونه capability** هستند، نه dependency اجباری این معماری.

## ۱. ابتدا مرز مسئولیت‌ها را تعریف کنید

پیش از انتخاب tool، مشخص کنید هر لایه چه چیزی را مالک است.

| لایه | مسئولیت | چیزی که نباید ضمنی مالک شود |
|---|---|---|
| Application repository | source، test، schema، migration و architecture recordهای committed | state مربوط به AI runtime |
| Host | Git client، launcher runtime/container و AI client/CLI | نصب global تمام ابزارهای project مگر اینکه آگاهانه انتخاب شده باشد |
| Tooling runtime | ابزارهای local، language server و adapterها | dependency graph برنامه یا production runtime |
| Remote connector | evidence خارجی که صریحاً درخواست شده | source نامرتبط repository یا secretهای بدون محدودیت |
| Agent policy / skills | task classification، روش و evidence requirement | global workflow state یا authorization enforcement |
| Validator / doctor | اثبات سلامت tooling و contractها | repair خاموش application code نامرتبط |

Graph، index، cache، summary و model output تولیدشده **evidence aid** هستند، نه source of truth. مگر اینکه پروژه خلاف این را صریح تعریف کند، source code، schema، migration، test و decisionهای committed authoritative باقی می‌مانند.

## ۲. Capabilityها را قبل از implementation طبقه‌بندی کنید

Toolها را بر اساس مسئولیت دسته‌بندی کنید، نه نام محصول.

یک classification کاربردی:

1. **کار معمول repository** — file، Git inspection، test و edit معلوم.
2. **Semantic code intelligence** — declaration، reference، diagnostics و semantic refactor.
3. **Architecture/dependency analysis** — graph، blast radius و hypothesisهای cross-module.
4. **External documentation** — رفتار version-specific کتابخانه و API خارجی.
5. **Runtime incident evidence** — trace، error، release و production event.
6. **Workflow/review capability** — test review، security review، architecture review و prompt/workflow validation.

برای هر capability مشخص کنید:

- entry condition؛
- input authoritative؛
- toolهای مجاز؛
- read/write permission؛
- output مورد انتظار؛
- validation؛
- failure behavior؛
- نیاز یا عدم نیاز به network.

صرف وجود یک tool دلیل اضافه کردن آن نیست. هر capability باید use case واقعی و حداقل یک acceptance scenario داشته باشد.

## ۳. Routing را صریح و deterministic نگه دارید

Available بودن tool به معنی مجاز بودن استفاده از آن نیست.

Policy باید پاسخ دهد:

```text
این task از چه نوعی است؟
کدام capability با کمترین هزینه uncertainty را کم می‌کند؟
چه evidenceای باید تولید کند؟
چه زمانی نباید اجرا شود؟
```

نمونه:

| Task | مسیر پیشنهادی |
|---|---|
| edit معلوم Markdown/config | built-in file tools |
| پیدا کردن symbol reference | semantic tool |
| impact نامطمئن cross-module | architecture analyzer محدود + validation با source |
| بررسی API کتابخانه خارجی | documentation منطبق با locked version |
| incident واقعی production | connector read-only incident |

برای یک مسئولیت چند tool را بی‌دلیل اجرا نکنید. Tool دوم فقط وقتی وارد شود که claim متفاوتی را validate می‌کند.

## ۴. Portable Core را از Language Profile جدا کنید

Core reusable نباید assumptionهای یک زبان یا framework را hardcode کند.

ساختار پیشنهادی:

```text
AI tooling core
├── runtime boundary
├── readiness / doctor
├── state and locking
├── protocol adapters
├── validation framework
└── routing contracts

Language/profile layer
├── language server
├── semantic-tool configuration
├── source roots
├── ignore rules
├── profile-specific version pins
└── semantic acceptance fixture
```

با این separation می‌توان همان lifecycle را برای TypeScript، Rust، Python یا stack دیگر reuse کرد.

## ۵. Runtime Ownership Model را انتخاب کنید

برای local repository tooling، تا جای ممکن runtimeی reproducible و project-owned انتخاب کنید. گزینه‌های رایج:

- container image؛
- virtual environment محلی project؛
- environment hermetic package manager؛
- binary/tool bundle با version pin‌شده.

اصل مهم «Docker برای همه‌چیز» نیست؛ اصل مهم این است که version، dependency و startup behavior صریح و reproducible باشند.

Container project-owned زمانی مفید است که tool به language server، dependencyهای Python/Node، native binary یا compatibility بین hostهای مختلف نیاز دارد.

### Local Tool و Remote Tool را یکی نکنید

یک network policy واحد را کورکورانه روی همه capabilityها اعمال نکنید.

Default مناسب:

- **local analyzer:** بدون runtime network مگر use case مستند؛
- **remote connector:** مسیر network-enabled جدا با کمترین data disclosure و credential محدود.

این کار مانع می‌شود semantic/graph tool محلی فقط به دلیل وجود یک connector remote به اینترنت دسترسی پیدا کند.

## ۶. Local Runtime را harden کنید

در containerها، در صورت compatibility با tool این defaultها مناسب‌اند:

```yaml
read_only: true
cap_drop:
  - ALL
security_opt:
  - no-new-privileges:true
```

همچنین ترجیح دهید:

- runtime identity غیر root؛
- بدون privileged mode؛
- بدون host network مگر با justification؛
- بدون mount کردن Docker socket؛
- بدون published port برای toolهای stdio-only؛
- narrow bind mount؛
- writable mount صریح برای state/cache؛
- secret فقط در runtime، نه در config committed.

اگر tool واقعاً به capability بیشتری نیاز دارد، exception و threat boundary را مستند کنید؛ کل runtime را خاموش و broad نکنید.

## ۷. Runtime Identity را واقعی بسازید

اجرای process با UID/GID عددی همیشه کافی نیست. برخی runtimeها از APIهای OS برای resolve کردن user/group استفاده می‌کنند.

اگر UID/GID ثابت دارید، account mapping واقعی بسازید و این موارد را validate کنید:

```text
numeric identity
name resolution
home directory
writable state ownership
```

مشکل identity نباید اولین بار هنگام اجرای language server یا package runtime دیده شود.

## ۸. Supply Chain را pin کنید

برای versionها یک authority machine-readable داشته باشید.

بر اساس ecosystem موارد زیر را pin کنید:

- tool version؛
- base image و در صورت امکان immutable digest؛
- dependency مستقیم و transitive از طریق lockfile؛
- artifact download با checksum/signature verification؛
- language-server/runtime version؛
- انتظار compatibility بین protocol و client.

در tooling reproducible از `latest` و installer downloadهای unbounded دوری کنید.

برای محیط‌های حساس‌تر، SBOM و artifact attestation یا evidence معادل را به release process اضافه کنید.

## ۹. Authority Fileها را صریح کنید

Layout عمومی می‌تواند چنین باشد:

```text
.ai/
├── policies/
├── scripts/
├── tooling/
│   ├── versions.*
│   ├── container/runtime definition
│   └── profile resources
├── state/          # generated, ignored
└── cache/          # generated, ignored

.agent-or-client-config/
.semantic-tool-config/
.agent-skills/
docs/ai-tooling/
```

Path دقیق مهم نیست؛ owner هر concern باید واضح باشد:

| Concern | Authority نمونه |
|---|---|
| Version | version manifest / lockfile |
| Runtime build | Dockerfile / environment definition |
| Security boundary | Compose/runtime config |
| Readiness/state | یک lifecycle core |
| MCP launcher | یک adapter/launcher |
| Architecture lifecycle | یک scoped dispatcher |
| Task routing | agent policy / skills |
| Project profile | config مختص زبان |

دو script مستقل نباید همزمان owner repair یا state transition یک tool باشند.

## ۱۰. Bootstrap، Readiness و Doctor را جدا کنید

### Bootstrap

Tooling را از starting state مشخص آماده می‌کند؛ ممکن است image بسازد یا managed state ایجاد کند.

### Quick Readiness

پاسخ می‌دهد: «آیا tool موردنیاز همین حالا قابل اجراست؟»

باید cheap، conditional و قابل reuse باشد.

### Full Doctor

Diagnostics عمیق‌تر: version، identity، state coherence، protocol، language runtime، permission، connector اختیاری و lifecycle consistency.

Full Doctor را روی هر prompt یا session startup اجرا نکنید. برای این موارد نگه دارید:

- tooling/version change؛
- maintenance صریح؛
- inconsistency واقعی؛
- validation installation/repair.

## ۱۱. Lazy Execution را ترجیح دهید

Capabilityهای گران را فقط وقتی task class به آن‌ها نیاز دارد اجرا کنید.

مثال:

- semantic server روی اولین semantic query؛
- architecture graph بعد از معلوم شدن scope؛
- external docs بعد از معلوم شدن dependency/version؛
- incident connector فقط برای incident concrete.

Watcher، periodic refresh یا full-repository scan را بدون operational need مستند اجرا نکنید.

## ۱۲. State، Cache و Lock را صریح مدیریت کنید

Generated state باید:

- Git ignored؛
- rebuildable؛
- در صورت نیاز per-repository/profile/scope namespaced؛
- از نظر size/retention محدود؛
- برای writer همزمان دارای lock/lease باشد.

مثال:

```text
.ai/state/toolchain.json
.ai/state/doctor.json
.ai/state/locks/
.ai/state/logs/
.ai/cache/
graph-output/<scope-id>/
```

برای مدیریت state از `git clean`، reset گسترده یا روش‌های مشابه استفاده نکنید.

## ۱۳. Cache Validity را Fingerprint کنید

Readiness cache یا architecture graph فقط زمانی reusable است که input مؤثر آن تغییر نکرده باشد.

فقط authorityهایی را fingerprint کنید که باید state را invalidate کنند:

```text
version manifest
runtime/container definition
profile configuration
launcher/dispatcher code
sourceهای مربوط به همان analysis scope
```

تغییر file نامرتبط خارج scope نباید graph محدود را invalidate کند.

## ۱۴. Persistent Volume Masking را مدیریت کنید

Mount کردن named volume روی pathی که در image file دارد، آن fileهای image layer را پنهان می‌کند.

Immutable runtime و writable state را جدا کنید:

```text
immutable runtime: /opt/tool-runtime
managed state:     /tool-state
```

سپس فقط resource لازم را در missing/version mismatch seed کنید.

خالی بودن persistent state نباید باعث package install کنترل‌نشده در runtime شود.

## ۱۵. MCP Stdio را پاک نگه دارید

در MCP stdio، stdout برای protocol است.

قواعد:

- فقط MCP/JSON-RPC معتبر روی stdout؛
- log روی stderr؛
- build/progress/UI wrapper نباید stdout را آلوده کند؛
- interactive menu و ANSI progress در صورت نیاز disable شوند؛
- signalها forward شوند؛
- shutdown deadline داشته باشد.

گاهی server سالم است ولی launcher با نوشتن progress package manager یا container build روی stdout protocol را خراب می‌کند.

## ۱۶. Protocol Path واقعی را Validate کنید

فقط «process اجرا شد» کافی نیست.

برای semantic MCP server، acceptance مفید:

```text
initialize
-> tools/list
-> یک semantic call واقعی read-only
-> assert روی result مورد انتظار/non-empty
-> bounded graceful shutdown
```

Fixture یا symbol acceptance باید متعلق به language profile باشد، نه hardcode شده در reusable core.

## ۱۷. Lifecycle Deterministic را جداگانه Test کنید

Fake transport/mock و integration واقعی مکمل‌اند.

Fake transport مناسب است برای:

- timeout/state-machine branch؛
- shutdown behavior؛
- malformed response؛
- wrapper exit-code behavior؛
- retry/lock deterministic.

Real integration لازم است برای:

- protocol exchange واقعی؛
- language server startup؛
- tool inventory؛
- semantic response واقعی؛
- container/runtime boundary.

Fake نباید جای integration را بگیرد و integration هم نباید تنها راه تست branchهای نادر lifecycle باشد.

## ۱۸. Timeout Budget مستقل داشته باشید

همه lifecycle را زیر یک timer عمومی مخفی نکنید.

Budget جدا برای:

```text
startup
normal tool call
expensive semantic operation
shutdown
external connector call
```

Valueها را از cold/warm behavior واقعی و requirement محصول استخراج کنید. Client و server timeout باید coherent باشند.

Timeout باید مشخص کند کدام phase fail شده است.

## ۱۹. Architecture Analyzer محدود باید Dispatcher داشته باشد

Analyzerهای graph/dependency state مشتق‌شده گران می‌سازند.

یک dispatcher owner این موارد باشد:

```text
scope validation
fingerprint
reuse / rebuild decision
state metadata
output location
locks
cleanup همان scope
```

Agent باید scope صریح درخواست کند، نه اینکه low-level graph command را مستقیم اجرا کند.

Graph خروجی hypothesis است. نتیجه material را با source authoritative و در صورت نیاز semantic tooling validate کنید.

## ۲۰. Remote Connector Trust Boundary متفاوت دارد

Documentation remote، issue tracker، observability و remote MCP به network و credential نیاز دارند.

قواعد:

- task دقیق قبل از call مشخص باشد؛
- minimum context ارسال شود؛
- secret و source نامرتبط ارسال نشود؛
- read-only به‌صورت default؛
- org/project/environment/release narrow شود؛
- auth failure به‌عنوان capability limitation گزارش شود؛
- credential خارج از repository committed نگه داشته شود.

## ۲۱. Skill باید رفتار Specialist را encode کند

Skill جای مناسبی است برای:

```text
entry gate
method/checklist
allowed tools
prohibitions
evidence requirements
output schema
failure behavior
```

مثال:

- architecture-impact analysis؛
- external-library docs؛
- incident analysis؛
- security review.

Global orchestration state، retry نامحدود و authorization enforcement را داخل skill قرار ندهید؛ این‌ها متعلق به workflow/application هستند.

## ۲۲. Implementation توسط AI را Scope-Guard کنید

وقتی خود AI agent tooling را implement می‌کند، pre-existing work را محافظت کنید.

قبل از mutation baseline ثبت شود:

```text
repository root
branch / revision فعلی در صورت مرتبط بودن
tracked changed paths
staged changed paths
untracked non-ignored paths
hash فایل‌های modified قبلی که نباید تغییر کنند
```

سپس allowlist دقیق pathهای مجاز را تعریف کنید.

بعد از هر write stage:

```text
changed paths ⊆ allowed paths + pre-existing changed paths
protected hashes unchanged
no unexpected generated artifact tracked
```

Rollback گسترده که کار developer را نابود می‌کند ممنوع باشد. در recovery فقط path متعلق به operation فعلی را از same-run backup یا recovery source verify‌شده restore کنید.

برای implementation بزرگ، read-only diagnosis را از mutation جدا کنید و stop condition واقعی داشته باشید. برای Clarification، Verification و bounded repair loop به **مهندسی پرامپت → سیستم‌ها و Workflowها** مراجعه کنید.

## ۲۳. لایه‌های Validation

### Static Validation

بررسی:

- syntax؛
- consistency version metadata؛
- floating version ممنوع؛
- config coherence؛
- ignore rule؛
- mount/capability unsafe؛
- unresolved placeholder؛
- host absolute path یا secret تصادفی.

### Unit Test

برای logic pure:

- fingerprint؛
- lock reclamation؛
- timeout transition؛
- scope resolution؛
- metadata validation؛
- process-result classification.

### Integration Test

برای runtime واقعی:

- container identity؛
- local network policy؛
- language/runtime presence؛
- stdio protocol؛
- semantic call؛
- dispatcher architecture؛
- reuse/rebuild state.

### End-to-End Routing

Scenarioهای task classification را اجرا کنید:

```text
ordinary task -> no expensive AI tool
semantic task -> semantic capability
architecture task -> scoped architecture capability + validation
external docs -> remote documentation connector
incident -> read-only incident connector
```

## ۲۴. Leak Detection را با Delta انجام دهید

قبل از test، process/container baseline ثبت شود.

سؤال درست:

```text
چه process/container جدیدی بعد از run باقی مانده؟
```

نه:

```text
آیا الان process/container مشابهی وجود دارد؟
```

Sessionهای قبلی developer نباید leak این validator محسوب شوند.

## ۲۵. Documentation بخشی از Contract است

حداقل این موارد را document کنید:

```text
architecture و trust boundaries
version authorities
onboarding
readiness / doctor behavior
tool routing
maintenance و upgrades
troubleshooting
validation commands
known limitations
```

هر lifecycle claim باید به authority file یا automated check قابل ردیابی باشد. Documentation drift وقتی operator به docs متکی است یک tooling defect محسوب می‌شود.

## ۲۶. Upgrade Process

Tool upgrade کنترل‌شده معمولاً:

1. version authority را تغییر می‌دهد؛
2. lockfile/checksum/digest را reproducibly update می‌کند؛
3. runtime را rebuild می‌کند؛
4. static/unit validation اجرا می‌کند؛
5. real integration acceptance اجرا می‌کند؛
6. routing/profile test مرتبط را اجرا می‌کند؛
7. version/maintenance docs را update می‌کند؛
8. supply-chain/security impact را review می‌کند؛
9. در صورت امکان tooling change را مستقل release می‌کند.

Tool upgrade نباید خاموش application dependencyها را update کند.

## ۲۷. Patternهای Troubleshooting قابل انتقال

| علامت | علت عمومی برای بررسی |
|---|---|
| Protocol parse error | stdout آلوده به output غیر protocol |
| Numeric user failure | UID/GID بدون account mapping |
| Offline runtime package install می‌کند | runtime resource لازم pre-bake/seed نشده |
| Tool در image هست ولی runtime نمی‌بیند | volume path image را mask کرده |
| Semantic timeout intermittent | cold-start budget کم است |
| Shutdown hang | deadline مستقل یا signal forwarding وجود ندارد |
| Cache graph/index غلط | fingerprint ناقص یا بیش از حد broad است |
| Process leak false positive | pre-run inventory ثبت نشده |
| Docs با implementation تناقض دارد | authority و docs جدا evolve شده‌اند |
| Self-test ظاهراً pass می‌شود | test production state machine را bypass می‌کند |

این موارد را diagnostic pattern بدانید، نه اینکه هر implementation باید همان fix تاریخی را بازسازی کند.

## ۲۸. چه چیزهایی باید Project-Specific بمانند؟

این‌ها universal constant نیستند:

- exact tool version؛
- exact timeout؛
- symbol مشخص semantic acceptance؛
- threshold تعداد module برای architecture analysis؛
- branch/commit/hash یک repository؛
- command یک package manager؛
- absolute path یک host/user؛
- یک language server یا framework profile؛
- strategy تاریخی commit/staging.

این مقادیر باید در profile/config یا runbook مختص همان project باشند.

## ۲۹. Completion Checklist

### Architecture

- [ ] Capability boundaryها صریح‌اند.
- [ ] Sourceهای authoritative مشخص‌اند.
- [ ] Portable core از profile زبان جداست.
- [ ] Routing دارای entry و non-entry rule است.

### Reproducibility

- [ ] Versionها pin شده‌اند.
- [ ] Lockfile/checksum/digest در صورت کاربرد وجود دارد.
- [ ] Runtime روی hostهای supported reproducible است.
- [ ] Generated state ignored و rebuildable است.

### Security

- [ ] Runtime least privilege دارد.
- [ ] Writable mount صریح است.
- [ ] Docker socket/privileged access بدون justification وجود ندارد.
- [ ] Local و remote network boundary جدا هستند.
- [ ] Secret در repository یا protocol/log قرار نمی‌گیرد.

### Lifecycle

- [ ] Bootstrap، quick readiness و full doctor مسئولیت جدا دارند.
- [ ] Toolهای گران lazy هستند.
- [ ] State دارای lock/fingerprint است.
- [ ] Timeout phase و shutdown bounded هستند.

### Validation

- [ ] Static check وجود دارد.
- [ ] Unit lifecycle test وجود دارد.
- [ ] Real integration test وجود دارد.
- [ ] Protocol validation یک useful call واقعی انجام می‌دهد.
- [ ] Routing scenarioها تست شده‌اند.
- [ ] Leak detection با pre-run baseline مقایسه می‌شود.

### Documentation

- [ ] Architecture، maintenance، onboarding و troubleshooting مستندند.
- [ ] مقدار project-specific بیرون generic core guide است.
- [ ] Claimهای docs با authority file و automated check هماهنگ‌اند.

## ۳۰. اصل طراحی

> AI tooling باید capabilityهای repository را توسعه دهد بدون اینکه به مالک ضمنی repository تبدیل شود. Tooling باید scoped، reproducible، auditable، replaceable و فاقد اختیار خاموش برای گسترش permission یا mutation state نامرتبط باشد.

## مطالعه بیشتر

- Docker Compose service configuration and security options: https://docs.docker.com/reference/compose-file/services/
- Docker rootless mode: https://docs.docker.com/engine/security/rootless/
- Model Context Protocol transports: https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
- GitHub supply-chain security: https://docs.github.com/en/code-security/concepts/supply-chain-security/supply-chain-security
- OpenAI Agents SDK orchestration: https://openai.github.io/openai-agents-python/multi_agent/
