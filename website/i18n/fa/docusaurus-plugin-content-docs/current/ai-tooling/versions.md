---
title: نسخه‌های AI tooling
sidebar_label: نسخه‌ها
---

# نسخه‌های AI tooling

runtime محلی Phase 2 از version pinهای immutable استفاده می‌کند. pin شدن نسخه یعنی source contract مشخص است؛ این موضوع به‌تنهایی ثابت نمی‌کند که runtime برای revision فعلی Docker/Doctor/semantic gateها را پاس کرده است.

| مؤلفه | نسخه / منبع |
| --- | --- |
| Runtime platform | `linux/amd64` |
| Python image | `python:3.13.14-slim-trixie` با digest ثابت |
| Node build image | `node:24.18.0-trixie-slim` با digest ثابت |
| Serena | `serena-agent==1.5.3` با hashed Python lock |
| Graphify | `graphifyy==0.9.12` با hashed Python lock |
| PowerShell | `7.6.4` با SHA-256 artifact |
| PowerShell Editor Services | `4.4.0` |
| PSScriptAnalyzer | `1.25.0` |
| ShellCheck | `0.10.0` |
| Pyright | `1.1.403` با npm lock integrity |
| Bash Language Server | `5.6.0` با npm lock integrity |
| Debian runtime libraries | snapshot `20260720T000000Z` با SHA-256 هر package |

منابع authoritative برای pinها شامل `.ai/tooling/versions.env`، `serena-artifacts.lock`، `debian-trixie-amd64.lock`، Python lock هش‌شده و npm lockfile هستند.

نسخه‌ها در configuration تعیین‌کننده release نباید float شوند. هر تغییر pin باید همراه با update قرارداد و validation مربوطه باشد.
