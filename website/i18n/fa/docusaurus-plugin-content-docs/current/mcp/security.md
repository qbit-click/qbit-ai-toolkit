---
id: security
title: امنیت MCP
sidebar_label: امنیت
---

# امنیت MCP

MCP می‌تواند capabilityهای قدرتمند بیرونی را در اختیار AI client قرار دهد. بنابراین کنترل امنیت باید در لایه‌های server، transport، credential و permission انجام شود و نباید فقط به متن prompt متکی باشد.

## کمترین سطح دسترسی

فقط server و toolهای مورد نیاز workflow را فعال کنید. به‌صورت پیش‌فرض read-only را ترجیح دهید و برای write، deploy، عملیات مخرب یا administrative دلیل و مجوز صریح داشته باشید.

## Credentialها

API key، token یا secret وابسته به ماشین را داخل template reusable commit نکنید. فقط نام environment variable یا secret store مورد انتظار را مستند کنید.

## مرز اعتماد

خروجی tool را external input در نظر بگیرید. سرویس متصل ممکن است داده stale، malformed یا adversarial برگرداند. identifier، path و state مهم را قبل از mutation بررسی کنید.

## Network و filesystem

در صورت امکان مقصدهای network و mountهای filesystem را محدود کنید. ابزاری که فقط به read access repository نیاز دارد نباید host access نامحدود داشته باشد.

## Auditability

برای integrationهای state-changing باید مشخص باشد چه capabilityای، روی چه targetی، با چه نتیجه‌ای اجرا شده است. secret valueها نباید log شوند.
