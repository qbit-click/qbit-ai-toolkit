---
title: ابزارهای AI خود repository
sidebar_label: معرفی
---

# ابزارهای AI متعلق به repository

Qbit AI Toolkit یک runtime محلی برای توسعه خود این repository دارد. این runtime با asset قابل توزیع `installer.codex-ai-tooling` متفاوت است.

## وضعیت

Phase 1 فعال است: governance، routing skillها، policyهای ابزار، مستندات، ignore ruleها و تنظیم اختیاری Context7 متعلق به repository هستند.

source مربوط به Phase 2 پیاده‌سازی و pin شده، اما availability آن تا زمانی که build تمیز `linux/amd64`، Doctor، smoke testهای Serena MCP/LSP و lifecycle محدود Graphify برای همین revision همگی پاس نشوند **در انتظار validation** است.

Playwright و Sentry عمداً وجود ندارند. Context7 اختیاری و فقط برای مستندات خارجی وابسته به نسخه است.

## مالکیت

root repository مالک runtime container-only Serena/Graphify زیر `.ai/tooling` و configurationهای `.ai/scripts`، `.codex` و `.serena` است. این فایل‌ها برای توسعه `qbit-ai-toolkit` هستند و توسط installer عمومی emit نمی‌شوند.

graph، log، cache، report و state volumeهای runtime فقط derived evidence هستند؛ source، schema، test و قراردادهای commit‌شده authoritative باقی می‌مانند.

## ادامه مطالعه

- [AI Context Continuity v2](./continuity-v2.md)
- [معماری و مالکیت](./architecture.md)
- [تفکیک project-local و installer](./project-local-vs-installer.md)
- [راه‌اندازی](./onboarding.md)
- [نگه‌داری](./maintenance.md)
- [رفع اشکال](./troubleshooting.md)
- [نسخه‌ها](./versions.md)
