# Installer architecture

The PowerShell and Bash host entrypoints normalize the same seven operations,
result schema, and exit codes. Declarative templates and fragments form the
self-contained payload. Compatibility ownership state remains at
`.qbit/toolkit/installed/codex-ai-tooling.json`; the portable manifest,
transactions, backups, lock, and recovery evidence live at
`.qbit-toolkit/codex-ai-tooling/`.

Planning classifies every destination before mutation. Host engines share the
same state-first ownership rules, marker algorithms, payload checksum manifest,
state-last transaction ordering, and wrapper contract. The future standalone
Toolkit CLI boundary is process-only and introduces no installer dependency.
