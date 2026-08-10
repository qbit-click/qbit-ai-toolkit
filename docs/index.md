---
id: index
slug: /
title: Qbit AI Toolkit
sidebar_label: Overview
sidebar_position: 1
---

# Qbit AI Toolkit

Qbit AI Toolkit is the canonical, versioned source for AI-development tooling and reusable automation assets in the Qbit ecosystem. It owns installer assets, schemas, policies, agent skills, templates, prompts, libraries, validation tooling, and the contracts that describe how consumers use them.

The repository is **not** the Qbit CLI and is **not** an application runtime. Product repositories consume versioned Toolkit assets through explicit contracts.

```text
qbit-cli            ─┐
qbit-console        ─┼── consumes versioned qbit-ai-toolkit assets
future consumers    ─┘
```

## Current implemented asset

The first implemented catalog asset is `installer.codex-ai-tooling` version `1.0.0`. It installs repository-owned AI development tooling into an existing Git work tree while preserving application dependencies, project-owned instructions, and Git index state.

The installer exposes the lifecycle operations `plan`, `install`, `update`, `repair`, `verify`, `doctor`, and `uninstall` through PowerShell and POSIX entrypoints.

## Documentation model

This documentation is part of the repository's versioned source of truth. Architecture, contracts, operational behavior, and compatibility rules should be documented before implementation changes are considered complete.

The documentation site is built with Docusaurus from the canonical Markdown under `docs/`. The Docusaurus application itself lives under `website/` and does not own the documentation content.

## Where to start

- [Getting started](./getting-started.md) — repository and documentation workflow.
- [Codex AI Tooling](./codex-ai-tooling.md) — installer lifecycle and safety model.
- [Architecture](./architecture.md) — repository boundaries and ownership.
- [Asset contract](./asset-contract.md) — catalog metadata and consumer contract.
- [Security](./security.md) — trust boundaries and secret-handling rules.
- [Versioning](./versioning.md) — immutable versions and compatibility expectations.
