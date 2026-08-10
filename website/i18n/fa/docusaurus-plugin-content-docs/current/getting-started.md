---
id: getting-started
title: شروع کار
sidebar_label: شروع کار
sidebar_position: 2
---

# شروع کار

Qbit AI Toolkit در حال حاضر به‌صورت یک source repository توسعه داده می‌شود و مالک catalog دارایی‌ها، installerهای قابل استفاده مجدد، قراردادهای validation و سایت مستندات است.

## ساختار repository

```text
qbit-ai-toolkit/
├── catalog.json
├── schemas/
├── installers/
│   └── codex-ai-tooling/
├── agent-assets/
├── prompts/
├── libraries/
├── templates/
├── docs/
├── website/
├── tests/
└── tools/
```

`docs/` محتوای canonical مستندات را نگه می‌دارد. `website/` فقط برنامه Docusaurus برای render و deploy مستندات است.

## توسعه مستندات

سایت با Docusaurus و Bun ساخته می‌شود:

```bash
cd website
bun ci
bun run start
```

برای اجرای locale فارسی:

```bash
bun run start:fa
```

برای build نهایی هر دو زبان:

```bash
bun run build
```

سایت production برای `https://ai-toolkit.qbit.click` تنظیم شده و پس از رسیدن تغییرات مستندات یا website به branch `main` توسط GitHub Actions منتشر می‌شود.

## اعتبارسنجی repository

قراردادهای metadata و static با دستور زیر بررسی می‌شوند:

```bash
python tools/validate.py
```

قبول شدن unit test به‌تنهایی کافی نیست؛ catalog، manifest، templateها، version pinها و قواعد hygiene نیز باید با هم سازگار باشند.

## فرایند Documentation-first

برای تغییر رفتار یا معماری:

1. ابتدا قرارداد مطلوب و رفتار compatibility در مستندات تعریف شود.
2. اگر قرارداد ماشین‌خوان تغییر می‌کند، schema یا catalog به‌روزرسانی شود.
3. implementation بدون ساخت source of truth دوم انجام شود.
4. در لایه‌های لازم unit، integration و E2E تست معنادار اضافه شود.
5. documentation، implementation و release metadata با هم validation شوند.

namespaceهای تاریخی installer مانند `.qbit-toolkit/` و markerهای موجود بخشی از قرارداد سازگاری نسخه `1.0` هستند. تغییر نام repository به `qbit-ai-toolkit` به معنی rename خودکار این مسیرها نیست؛ تغییر آن‌ها نیازمند migration صریح است.
