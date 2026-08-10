---
id: conventions
title: قراردادهای نگارشی و ساختاری
sidebar_label: Conventions
---

# Conventions

Qbit AI Toolkit بر اساس نوع asset سازمان‌دهی می‌شود، نه بر اساس محصول مصرف‌کننده.

- metadata ماشین‌خوان catalog و manifest با JSON نگهداری می‌شود.
- pathهای repository در metadata از `/` استفاده می‌کنند.
- فایل‌های متنی UTF-8 و LF هستند و در حالت عادی final newline دارند؛ مگر اینکه قرارداد byte-exact خلاف آن را بخواهد.
- stable IDها lowercase هستند و در releaseهای compatible تغییر نمی‌کنند.
- output تولیدشده، cache، log، report و runtime state source canonical نیستند.
- پشتیبانی consumerها با metadata تعریف می‌شود، نه با duplicate کردن asset یکسان.

managed blockهای installer marker دقیق دارند و محتوای متعلق به پروژه خارج از block را حفظ می‌کنند. namespace تاریخی `qbit-toolkit` تا زمان migration صریح به‌عنوان شناسه compatibility حفظ می‌شود.
