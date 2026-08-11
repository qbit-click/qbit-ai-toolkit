---
id: reusable-assets
title: دارایی‌های AI قابل استفاده مجدد
sidebar_label: دارایی‌های قابل استفاده مجدد
---

# دارایی‌های AI قابل استفاده مجدد

Reusable assetها building blockهای نسخه‌داری هستند که می‌توانند بدون کپی کردن conventionهای پنهان میان چند repository مصرف شوند.

## انواع رایج

- اسکریپت‌های setup و maintenance؛
- configuration templateها؛
- Docker یا repository templateها؛
- prompt libraryهای reusable؛
- templateهای MCP؛
- policy و skillهای agent.

## محل نگه‌داری اهمیت دارد

Promptها زیر `prompts/`، templateهای MCP زیر `agent-assets/mcp-configs/` و skillها زیر `agent-assets/skills/` قرار می‌گیرند. script و template عملیاتی هم باید کنار subsystem مالک lifecycle خود باشند تا ownership و release boundary مبهم نشود.

## Reuse بدون coupling پنهان

هر asset reusable باید assumptionها، consumerهای پشتیبانی‌شده، version، inputهای لازم، outputهای تولیدی و رفتار compatibility خود را روشن کند. consumer نباید به path یا implementation داخلی undocumented وابسته شود.

Skillهای آماده در بخش **ایجنت‌ها و اسکیل‌ها** مستند می‌شوند، چون قرارداد طراحی و اجرای آن‌ها با setup tooling عمومی متفاوت است.
