# معماری AI tooling

## مالکیت و authority

فایل‌های root شامل `AGENTS.md`، `.agents/`، `.ai/`، `.codex/` و مستندات این بخش project-owned هستند. فایل‌های زیر `installers/codex-ai-tooling/templates/` templateهای installer برای repositoryهای مصرف‌کننده‌اند. runtime root نباید از markerهای managed installer استفاده کند و installer نیز نباید روی خود `qbit-ai-toolkit` نصب شود.

source canonical، schema و catalog contract، تست‌ها، installer state contract و architecture recordهای commit‌شده authoritative هستند. graph، index، cache، log، report و release output فقط evidence مشتق‌شده‌اند.

## مرز ابزارها

عملیات عادی فایل، command، Git، test و orchestration با ابزارهای اصلی انجام می‌شود. Serena فقط برای semantic operationهای PowerShell، Bash و Python استفاده می‌شود. Graphify فقط پشت wrapper صریح CLI برای تحلیل معماری سراسری مجاز است و نباید MCP server، hook یا action خودکار باشد. Context7 اختیاری و محدود به documentation خارجی وابسته به نسخه است.

`qbit-cli` یک repository مصرف‌کننده جداست و خارج از scope این repository باقی می‌ماند مگر صراحتاً وارد scope شود.

## ایزولیشن Phase 2

Serena repository را در `/workspace` به‌صورت read-write می‌بیند و state آن در named volume با project path ثابت `/serena-state/projects/qbit-ai-toolkit` قرار دارد. `.serena` tracked فقط config source immutable است.

Graphify `/workspace` را read-only می‌بیند و فقط در `/graphify-output` می‌نویسد. Doctor همه inputها را read-only mount می‌کند. سرویس‌ها network ندارند، root filesystem آن‌ها read-only است، `no-new-privileges` فعال است و capabilityها پس از bootstrap محدود حذف می‌شوند.

assetهای installer همچنان consumer-runtime assets هستند و تغییر project-local نباید بدون دلیل مرتبط در templateهای installer کپی شود.
