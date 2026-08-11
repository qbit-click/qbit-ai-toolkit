---
id: index
title: پروتکل Model Context Protocol (MCP)
sidebar_label: معرفی
---

# Model Context Protocol (MCP)

MCP مرز integration میان یک AI client و capabilityهایی است که serverهای بیرونی ارائه می‌کنند. این بخش روی استفاده امن، قابل پیش‌بینی و قابل عیب‌یابی MCP در workflowهای توسعه تمرکز دارد.

## این بخش چه چیزهایی را پوشش می‌دهد؟

- انتخاب و پیکربندی MCP server؛
- نقش tool، resource و permission در مدل client/server؛
- بررسی initialization و capability discovery؛
- محدود کردن access و حفاظت از credentialها؛
- تشخیص خطاهای رایج connection و tool execution.

Templateهای reusable مربوط به MCP زیر `agent-assets/mcp-configs/` قرار می‌گیرند. credential یا secret وابسته به محصول یا ماشین نباید همراه این templateها commit شود.
