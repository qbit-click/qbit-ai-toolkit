# راه‌اندازی AI tooling

## Phase 1

1. repository را در Codex باز و trust کنید تا project configuration بارگذاری شود.
2. `AGENTS.md` ریشه و skill مرتبط زیر `.agents/skills/` را پیش از کار گسترده بخوانید.
3. در صورت نیاز `CONTEXT7_API_KEY` را از parent process یا secret manager تأییدشده فراهم کنید. `.env.ai.example` فقط documentation است.

## Phase 2

پیش‌نیاز runtime، Docker با Compose و Codex configuration مورد اعتماد در scope پروژه است.

در PowerShell:

```powershell
.ai/scripts/bootstrap.ps1
```

در Bash:

```bash
.ai/scripts/bootstrap.sh
```

bootstrap فقط image pin‌شده را می‌سازد؛ نباید package روی host نصب کند یا سرویس‌ها را خودکار start کند. Doctor فقط پس از initialization صریح runtime اجرا می‌شود.

Graphify فقط برای درخواست صریح تحلیل معماری سراسری استفاده می‌شود. output آن در named volume مربوط به `/graphify-output` قرار می‌گیرد و state Serena یا output Graphify نباید زیر working tree ذخیره شود.
