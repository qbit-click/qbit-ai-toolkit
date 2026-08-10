# مالکیت project-local در برابر installer

فایل‌های `.ai/tooling` و `.ai/scripts` ابزار AI را برای خود `qbit-ai-toolkit` فعال می‌کنند. همراه با configurationهای root در `.codex` و `.serena`، این فایل‌ها runtime محلی Serena، Graphify و Doctor را می‌سازند و اجرا می‌کنند.

در مقابل، `installers/codex-ai-tooling/` یک محصول توزیع‌شونده برای نصب ابزار معادل در repositoryهای دیگر است. این tree نباید build input، runtime dependency یا activation mechanism خود `qbit-ai-toolkit` باشد.

bootstrap، Doctor، validation و runtime code مربوط به project-local نباید installer-owned assetها را به‌عنوان source خود بخوانند، کپی یا نصب کنند و نباید `qbit-cli` را فراخوانی کنند.

فعال‌سازی project-local باید مستقل از installer عملیاتی شود. sync میان root runtime و payload installer فقط از طریق قراردادهای صریح و review‌شده انجام می‌شود؛ تولید output یا template installer نباید source of truth دوم بسازد.
