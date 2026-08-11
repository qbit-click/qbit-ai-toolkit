---
id: using-mcp
title: استفاده از MCP
sidebar_label: پیکربندی و استفاده
---

# استفاده از MCP

MCP server را یک capability boundary بیرونی در نظر بگیرید، نه بخشی نامرئی از خود مدل. فقط serverها و toolهایی را فعال کنید که workflow واقعاً به آن‌ها نیاز دارد.

## روند معمول

1. **Capability را مشخص کنید** — معلوم کنید به تحلیل repository، مستندات، issue tracker، database، browser automation یا integration دیگری نیاز دارید.
2. **Server را انتخاب کنید** — server نگه‌داری‌شده با مستندات روشن capability و security را ترجیح دهید.
3. **Transport و credential را تنظیم کنید** — secretهای محلی را خارج از templateهای commit‌شده نگه دارید.
4. **Capability را محدود کنید** — اگر client از allowlist پشتیبانی می‌کند فقط tool و resource لازم را فعال کنید.
5. **Initialization را verify کنید** — شروع process، MCP initialize و capability discovery باید موفق باشد.
6. **ابتدا operation خواندنی را تست کنید** — قبل از write، connectivity و semantics را با عملیات read-only بررسی کنید.

## Templateهای پیکربندی

Template reusable باید environment variableهای لازم و فیلدهای consumer را مستند کند، بدون اینکه secret واقعی را داخل source قرار دهد. این templateها در `agent-assets/mcp-configs/` نگه‌داری می‌شوند.

## ترتیب troubleshooting

ابتدا config client، سپس startup server، transport، initialize، discovery و در نهایت خود tool call را بررسی کنید. جدا نگه داشتن این لایه‌ها علت failure را سریع‌تر مشخص می‌کند.
