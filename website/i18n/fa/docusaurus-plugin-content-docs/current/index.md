---
id: index
slug: /overview
title: کیوبیت AI تولکیت
sidebar_label: معرفی
sidebar_position: 1
---

# Qbit AI Toolkit

**Qbit AI Toolkit** مخزن مرجع و نسخه‌پذیر ابزارها و دارایی‌های توسعه مبتنی بر هوش مصنوعی در اکوسیستم Qbit است. این مخزن مالک installerها، schemaها، policyها، skillهای ایجنت، templateها، promptها، libraryها و ابزارهای validation است و قرارداد استفاده مصرف‌کننده‌ها از این دارایی‌ها را نیز تعریف می‌کند.

این پروژه خود **Qbit CLI** یا یک application runtime نیست. پروژه‌های مصرف‌کننده، دارایی‌های نسخه‌دار آن را از طریق قراردادهای صریح مصرف می‌کنند.

```text
qbit-cli            ─┐
qbit-console        ─┼── مصرف دارایی‌های نسخه‌دار qbit-ai-toolkit
مصرف‌کننده‌های آینده ─┘
```

## دارایی پیاده‌سازی‌شده فعلی

اولین دارایی عملیاتی catalog، `installer.codex-ai-tooling` نسخه `1.0.0` است. این installer ابزارهای توسعه AI متعلق به repository را در یک Git work tree موجود نصب می‌کند، بدون اینکه dependencyهای برنامه، دستورالعمل‌های متعلق به پروژه یا Git index را به‌صورت ناخواسته تغییر دهد.

عملیات lifecycle آن شامل `plan`، `install`، `update`، `repair`، `verify`، `doctor` و `uninstall` است و در PowerShell و محیط POSIX قرارداد یکسانی دارد.

## مدل مستندسازی

مستندات بخشی از source of truth نسخه‌دار پروژه هستند. معماری، قراردادها، رفتار عملیاتی و قواعد سازگاری باید پیش از کامل تلقی شدن تغییرات implementation مستند شوند.

محتوای مرجع در `docs/` قرار دارد و برنامه Docusaurus در `website/` فقط لایه نمایش، ترجمه و انتشار سایت است.

## حوزه‌های مستندات

مستندات به domainهای مستقل تقسیم شده‌اند تا هر بخش بدون تبدیل کردن sidebar به یک فهرست طولانی و مخلوط رشد کند:

- [شروع کار](./getting-started.md) — workflow repository و توسعه مستندات.
- [مهندسی پرامپت](./prompt-engineering/index.md) — نوشتن، ساختاربندی و ارزیابی prompt.
- [ابزارهای AI](./ai-tools/index.md) — اسکریپت‌های راه‌اندازی، assetهای reusable، Codex AI Tooling و tooling محلی repository.
- [MCP](./mcp/index.md) — پیکربندی، استفاده، capability boundary و امنیت integrationهای Model Context Protocol.
- [ایجنت‌ها و اسکیل‌ها](./agents/index.md) — ساخت skill، skillهای آماده و policyهای reusable agent.
- [مرجع مهندسی](./engineering/index.md) — معماری، قرارداد asset، conventionها، امنیت و versioning.

Navbar ورودی هر domain است و sidebar فقط topicهای همان حوزه را نمایش می‌دهد.
