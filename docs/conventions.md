---
id: conventions
title: Conventions
sidebar_label: Conventions
---

# Conventions

Qbit AI Toolkit is organized by asset type rather than by consuming product.

- JSON is used for catalog and manifest contracts.
- Repository-relative paths use `/` separators in machine-readable metadata.
- Text files are UTF-8 with LF line endings and a final newline unless a contract explicitly requires byte-exact content.
- Stable IDs are lowercase and remain unchanged across compatible releases.
- Generated output, caches, logs, reports, and local runtime state are never canonical source.
- Consumer-specific support is declared in metadata instead of duplicating otherwise identical assets.

Installer-managed blocks use exact markers and preserve project-owned content outside those blocks. Historical `qbit-toolkit` marker namespaces remain compatibility identifiers until an explicit migration changes them.
