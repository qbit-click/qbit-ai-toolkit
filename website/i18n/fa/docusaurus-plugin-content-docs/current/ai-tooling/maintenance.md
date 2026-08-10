# نگه‌داری

- skillها، routing، policyها و documentation مرتبط باید با هم review شوند.
- assetهای project-owned ریشه از templateهای installer جدا نگه داشته شوند.
- runtime و dependencyها فقط با نسخه و digest immutable pin شوند؛ floating version مجاز نیست.
- graph، index، cache، log، report، build، فایل موقت و release output track نشوند.
- تغییر version pin باید همراه با update مستندات نسخه و validation compatibility باشد.

## نگه‌داری Phase 2

هر version فقط همراه source immutable و digest مربوط به آن تغییر می‌کند. lockfileها باید به‌صورت reproducible به‌روزرسانی شوند و تغییر dependency set به‌صورت صریح review شود.

runtime download fallback مجاز نیست. image build تنها مرحله networked برای دریافت dependencyهاست. resourceهای runtime بر اساس manifest کنترل می‌شوند و corruption در named volume باید از محتوای immutable image و تحت lock repair شود.

هر تغییر ابتدا static/unit gate هدفمند را پاس می‌کند و Docker validation به‌صورت gate جدا اجرا می‌شود.
