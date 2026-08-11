---
id: setup-scripts
title: Setup and helper scripts
sidebar_label: Setup scripts
---

# Setup and helper scripts

Setup scripts automate repeatable environment preparation and validation. They should make the supported path easier without hiding destructive or security-sensitive behavior.

## Expected characteristics

- **Idempotent where practical** — repeated execution should not create duplicate state or unnecessary drift.
- **Explicit prerequisites** — required runtimes, Docker capabilities, credentials, and platform assumptions should be checked before mutation.
- **Observable failures** — errors should identify the failed operation and a useful remediation path.
- **No embedded secrets** — secrets belong in environment-specific secret stores or ignored local configuration, not committed scripts.
- **Cross-platform parity** — PowerShell and POSIX wrappers should implement the same contract when both are supported.

## Qbit AI Toolkit scripts

Project-local AI helper scripts live under `.ai/scripts/`. Repository maintenance entrypoints live under `tools/` or `scripts/` depending on scope. Reusable installer payload scripts belong to the asset that owns them rather than being copied into unrelated directories.

Use `doctor` or verification commands after setup when the tooling provides them; successful file creation alone is not sufficient proof that the runtime works.
