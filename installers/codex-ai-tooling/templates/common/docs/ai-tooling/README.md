# Repository-owned AI tooling

This repository contains a pinned, container-only Serena and Graphify runtime.
Serena supplies semantic PowerShell, Bash, and Python operations through the
exact approved 12-tool MCP allowlist. Graphify is CLI-only architecture
hypothesis support. Context7 is optional external documentation. Playwright and
Sentry are absent.

Use `./.ai/scripts/bootstrap.sh` or `.ai\scripts\bootstrap.ps1` to build the
image, and the corresponding Doctor script for operational validation.

- [Architecture](architecture.md)
- [Onboarding](onboarding.md)
- [Maintenance](maintenance.md)
- [Troubleshooting](troubleshooting.md)
- [Immutable versions](versions.md)
