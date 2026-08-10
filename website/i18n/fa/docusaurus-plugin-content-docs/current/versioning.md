---
id: versioning
title: نسخه‌بندی
sidebar_label: نسخه‌بندی
---

# نسخه‌بندی

assetهای Qbit AI Toolkit از semantic versioning استفاده می‌کنند. نسخه catalog، manifest و فایل `VERSION` هر asset باید با یکدیگر یکسان باشند.

## ورودی‌های immutable

lockfileها، dependency hashها، image digestها، release checksumها و artifactهای runtime pin‌شده بخشی از قرارداد نسخه هستند. floating dependency، mutable image tag، branch name یا package selector بدون pin نباید release را تعریف کند.

## compatibility

release سازگار باید stable ID و قراردادهای مستند state/ownership را حفظ کند. breaking change نیازمند تغییر نسخه آگاهانه و migration path است.

rename repository از `qbit-toolkit` به `qbit-ai-toolkit` به‌تنهایی namespaceهای روی دیسک installer نسخه 1.0 مانند `.qbit-toolkit/` یا managed markerهای فعلی را تغییر نمی‌دهد. این مقادیر شناسه compatibility هستند.

## نظم release

در هر تغییر، version یک asset به‌صورت مستقل مدیریت و validation evidence ثبت می‌شود. packaging با publication متفاوت است؛ ساخت archive مجوز commit، tag، push یا release نیست.
