---
id: index
title: CodexPro
sidebar_label: Overview
---

# CodexPro

CodexPro is an open-source bridge used to expose a local development workspace to ChatGPT through MCP while keeping repository tooling, sandboxed Bash execution, and optional direct Windows-host execution as separate capability paths.

The setup documented here is the **reference AminPC Windows deployment**, captured on **2026-08-10**. It is intentionally version-specific: the custom patch anchors target **CodexPro `0.29.0`**.

## Available guides

- [Windows canonical setup runbook](./windows-setup.md) — rebuild the complete reference deployment, including the Cloudflare named tunnel, HTTP MCP authentication, Codex workspace sandbox, `host_exec`, `open_app`, launcher, verification, update policy, and recovery guidance.

## Important boundary

The Windows runbook contains security-sensitive configuration. In the reference deployment, Bash remains inside the Codex workspace sandbox, while `host_exec` and `open_app` run directly as the current Windows user. The MCP token and the token-bearing connector URL must therefore be treated as secrets.

The runbook also contains byte-sensitive hashes and exact patch blocks. When reproducing the reference setup, do not rewrite those blocks or assume they apply to another CodexPro build.
