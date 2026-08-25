---
id: index
slug: /overview
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

The first implemented catalog asset is `installer.codex-ai-tooling` version `1.1.3`. It installs repository-owned AI development tooling into an existing Git work tree while preserving application dependencies, project-owned instructions, and Git index state.

The installer exposes the lifecycle operations `plan`, `install`, `update`, `repair`, `verify`, `doctor`, and `uninstall` through PowerShell and POSIX entrypoints.

## Documentation model

This documentation is part of the repository's versioned source of truth. Architecture, contracts, operational behavior, and compatibility rules should be documented before implementation changes are considered complete.

The documentation site is built with Docusaurus from the canonical Markdown under `docs/`. The Docusaurus application itself lives under `website/` and does not own the documentation content.

## Documentation domains

The documentation is split into independent domains so each area can grow without turning the sidebar into a single mixed hierarchy:

- [Getting started](./getting-started.md) — repository and documentation workflow.
- [Prompt Engineering](./prompt-engineering/index.md) — writing, structuring, and evaluating prompts.
- [AI Tools](./ai-tools/index.md) — setup scripts, reusable assets, Codex AI Tooling, and repository-local tooling.
- [MCP](./mcp/index.md) — configuration, usage, capability boundaries, and security for Model Context Protocol integrations.
- [Agents & Skills](./agents/index.md) — building skills, ready-made skills, and reusable agent policies.
- [Engineering reference](./engineering/index.md) — architecture, asset contracts, conventions, security, and versioning.

The top navigation opens the relevant domain; each domain then exposes only its own topics in the sidebar.
