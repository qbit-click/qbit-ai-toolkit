# رفع اشکال

- **project configuration بارگذاری نمی‌شود:** repository را در Codex trust کنید و در صورت نیاز session جدید بسازید.
- **Context7 در دسترس نیست:** اختیاری است. `CONTEXT7_API_KEY` را از parent process یا authentication تأییدشده فراهم کنید؛ MCP server جایگزین اضافه نکنید.
- **skillهای repository دیده نمی‌شوند:** پس از تغییر skillها session جدید Codex ایجاد کنید.
- **artifactهای تولیدشده باید پاک شوند:** فقط pathهای مشتق‌شده شناخته‌شده را حذف کنید؛ schema، template، catalog، installer، library، prompt، test، docs و agent asset canonical را حذف نکنید.

## مشکلات Phase 2

- mount مفقود یک خطای fatal است و نباید با directory داخل workspace جایگزین شود.
- language server مفقود build defect است؛ نصب runtime با npm، uvx، PowerShell module یا downloader fallback مجاز نیست.
- Doctor فقط گزارش می‌دهد و نباید permission، volume یا configuration را repair کند.
- write شدن Serena configuration نشانه config ناقص یا migrate‌شده است و باید validation را fail کند.
- Graphify clean فقط output mount دقیق را می‌پذیرد و symlink را دنبال نمی‌کند.
