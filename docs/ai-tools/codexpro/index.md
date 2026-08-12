---
id: index
title: CodexPro
sidebar_label: Overview
---

# CodexPro

CodexPro is an open-source bridge used to expose a local development workspace to ChatGPT through MCP while keeping repository tooling, sandboxed Bash execution, and optional direct host execution as separate capability paths.

The documentation in this section is written as a **deployment-neutral guide**. Public docs use placeholders for usernames, workspace roots, connector names, package locations, hostnames, tunnel IDs, and credentials instead of copying values from a specific machine or project.

## Available guides

- [Windows setup guide](./windows-setup.md) — configure CodexPro on Windows with deployment-neutral paths, package-manager-independent installation, workspace containment, tunnel setup, and optional version-specific host capabilities.
- [Linux setup guide](./linux-setup.md) — install and operate CodexPro on Linux, configure local or public HTTPS access, validate repository boundaries, and run safely in interactive or headless environments.
- [macOS setup guide](./macos-setup.md) — install and operate CodexPro on macOS with explicit guidance for shell/PATH behavior, privacy permissions, Apple Silicon/Intel differences, tunnels, and repository-scoped access.

## Package-manager boundary

CodexPro is distributed as an npm package, but the setup is not tied to Bun. Use any compatible package manager that installs the required CodexPro version and exposes the `codexpro` executable on `PATH`. Package-manager storage layout is an installation detail, not part of the CodexPro architecture.

## Important security boundary

Sandboxed Bash and direct host execution are distinct capabilities:

- Bash should remain bounded by the selected repository/workspace.
- Direct host execution, when available and enabled, runs with the current OS user's authority and therefore requires a stricter approval and credential model.

Treat MCP tokens and token-bearing connector URLs as secrets. Use the narrowest practical workspace root and only enable capabilities required by the workflow.

## Version-specific customizations

If a deployment modifies CodexPro source files or adds custom tools, pin the exact CodexPro build and manage those changes as a versioned patch asset. Do not publish hashes, package paths, usernames, hostnames, or connector names copied from another machine as if they were universal reference values.
