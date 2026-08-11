---
id: index
title: CodexPro
sidebar_label: معرفی
---

# CodexPro

CodexPro یک bridge متن‌باز برای متصل کردن workspace توسعه محلی به ChatGPT از طریق MCP است. در معماری مرجع، ابزارهای repository، اجرای Bash داخل sandbox و اجرای مستقیم روی Windows host سه boundary جدا هستند و نباید با یکدیگر یکی فرض شوند.

راهنمای این بخش deployment مرجع **AminPC روی Windows** را که در **2026-08-10** ثبت شده مستند می‌کند. این setup عمداً وابسته به version است و patch anchorهای آن برای **CodexPro `0.29.0`** نوشته شده‌اند.

## راهنماهای موجود

- [راهنمای canonical راه‌اندازی روی Windows](./windows-setup.md) — بازسازی deployment کامل شامل Cloudflare named tunnel، احراز هویت HTTP MCP، Codex workspace sandbox، ابزارهای `host_exec` و `open_app`، launcher، verification، update policy و recovery.

## مرز امنیتی مهم

در deployment مرجع، Bash همچنان داخل Codex workspace sandbox اجرا می‌شود، اما `host_exec` و `open_app` مستقیماً با دسترسی Windows user فعلی اجرا می‌شوند. بنابراین MCP token و connector URL حاوی token باید secret در نظر گرفته شوند.

Runbook شامل hashهای وابسته به byte و patch blockهای exact نیز هست. هنگام بازسازی setup مرجع، این blockها را بازنویسی نکنید و آن‌ها را برای version دیگری از CodexPro معتبر فرض نکنید.
