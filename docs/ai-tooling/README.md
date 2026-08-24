---
title: Repository AI tooling
sidebar_label: Overview
---

# Repository-owned AI tooling

Qbit AI Toolkit carries a project-local AI development runtime for working on this repository itself. This runtime is separate from the reusable `installer.codex-ai-tooling` asset.

## Status

Phase 1 is active: repository governance, routing skills, tool policies, documentation, ignore rules, and optional Context7 configuration are repository-owned and available.

Phase 2 source is implemented and pinned, but runtime availability must be treated as **pending validation** until a clean `linux/amd64` build, Doctor, Serena MCP/LSP smoke tests, and fixture-only Graphify lifecycle gates all pass for the current revision.

Playwright and Sentry are intentionally absent. Context7 is optional and limited to external version-specific documentation.

## Ownership

The repository root owns the container-only Serena and Graphify runtime under `.ai/tooling`, together with `.ai/scripts`, `.codex`, and `.serena` configuration. These files activate AI tooling for `qbit-ai-toolkit`; they are not emitted by the reusable installer and are not a consumer-repository state directory.

Generated graphs, logs, caches, reports, and runtime volume contents are derived evidence only. Canonical source, schemas, tests, and committed contracts remain authoritative.

## Documentation

- [Architecture and ownership](./architecture.md)
- [Project-local versus installer ownership](./project-local-vs-installer.md)
- [Onboarding](./onboarding.md)
- [Maintenance](./maintenance.md)
- [Troubleshooting](./troubleshooting.md)
- [Pinned versions](./versions.md)
- [Installer rollout and onboarding](./installer-rollout.md)
