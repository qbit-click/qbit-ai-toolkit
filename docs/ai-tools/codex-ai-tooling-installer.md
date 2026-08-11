---
id: codex-ai-tooling-installer
title: Using the Codex AI Tooling installer
sidebar_label: Installer usage
---

# Using the Codex AI Tooling installer

`installer.codex-ai-tooling` installs a versioned, repository-owned AI development environment into an existing Git work tree. It manages tooling configuration and runtime assets without installing application dependencies, modifying user-level Codex configuration, or taking ownership of unrelated project files.

## What is installed

The installed payload includes:

- project-scoped Codex MCP configuration;
- Serena semantic tooling with a bounded tool allowlist;
- scoped Graphify architecture-analysis wrappers;
- optional Context7 external-documentation routing;
- optional read-only Sentry incident routing;
- Docker/Compose runtime definitions;
- bootstrap and Doctor scripts;
- agent routing policy and reusable skills;
- repository-local AI tooling documentation;
- installer ownership state used for safe update, repair, verify, and uninstall.

Browser/Playwright tooling is not installed.

## Supported profiles

| Profile | Selection | Semantic runtime |
| --- | --- | --- |
| `auto` | Detect from root project metadata | Selects one of the profiles below |
| `generic` | Explicit or fallback | PowerShell, Bash, Python |
| `typescript` | Root `tsconfig.json` or TypeScript package metadata | TypeScript 5.9.3 + TypeScript Language Server 5.1.3, plus shared languages |
| `rust` | Root `Cargo.toml` | Rust 1.85.0 + `rust-analyzer`, plus shared languages |

With `auto`, TypeScript takes precedence if both TypeScript and Rust metadata are present.

## Prerequisites

The target must be an existing Git work tree. For full runtime bootstrap and Doctor, the host also needs:

- Docker with a Linux `amd64` backend;
- Docker Compose v2 or newer;
- PowerShell on Windows, or a POSIX shell on Linux/macOS;
- Codex when the installed MCP configuration will be used.

The installer itself does not require the target application's package manager to install dependencies.

## Start with a plan

A plan is read-only and should normally be the first operation.

### PowerShell

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

### POSIX

```bash
./installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /projects/example/backend \
  --profile auto
```

For automation, request JSON:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto `
  -Format json `
  -NonInteractive
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /projects/example/backend \
  --profile auto \
  --format json \
  --non-interactive
```

## Install

### PowerShell

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

### POSIX

```bash
./installers/codex-ai-tooling/install.sh \
  --operation install \
  --target /projects/example/backend \
  --profile auto
```

By default, installation writes the owned payload, builds the repository-owned image, prepares the Serena state/resource volumes without starting an MCP service, and then runs Doctor. For CI or a staged deployment you can separate those phases:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -Profile typescript `
  -SkipBootstrap `
  -SkipDoctor
```

Then run the installed entrypoints explicitly:

```powershell
& 'D:\Projects\Example\backend\.ai\scripts\bootstrap.ps1'
& 'D:\Projects\Example\backend\.ai\scripts\doctor.ps1'
```

```bash
/projects/example/backend/.ai/scripts/bootstrap.sh
/projects/example/backend/.ai/scripts/doctor.sh
```

## Project identity and allowed origins

The installer derives a project slug and display name by default. They may be set explicitly:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation install `
  -Target 'D:\Projects\Example\backend' `
  -ProjectSlug example-backend `
  -ProjectDisplayName 'Example Backend' `
  -AllowedOrigin 'http://localhost:3000','http://127.0.0.1:3000'
```

Only explicit HTTP/HTTPS origins are accepted. Wildcards, credentials, fragments, and relative values are rejected.

## Verify

`verify` is static and ownership-driven. It validates installer state and managed files without running the full container diagnostics.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation verify -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation verify --target /projects/example/backend
```

## Doctor

`doctor` first verifies ownership, then validates the isolated runtime: identity, security boundary, exact versions, MCP initialization/tool allowlist, semantic smoke checks, Graphify CLI availability, and persistent no-write behavior.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation doctor -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation doctor --target /projects/example/backend
```

Context7 or Sentry authentication is optional and is not a prerequisite for local Serena/Graphify health.

## Update

Use `update` after replacing the installer with a newer compatible payload. Update requires valid existing ownership state.

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation update `
  -Target 'D:\Projects\Example\backend' `
  -Profile auto
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation update \
  --target /projects/example/backend \
  --profile auto
```

Profile migration is transactional. For example, moving from a TypeScript profile to Rust removes only stale installer-owned profile files and adds the new owned profile files.

## Repair

`repair` re-applies the current payload only when valid ownership evidence exists. It does not adopt unrelated files.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation repair -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation repair --target /projects/example/backend
```

## Modified installer-owned files

The default policy is fail-closed. If an installer-owned file was edited after installation, mutation stops instead of overwriting the edit.

After reviewing the conflict, `replace` can back up and replace a previously owned file:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation repair `
  -Target 'D:\Projects\Example\backend' `
  -OwnedModified replace
```

```bash
./installers/codex-ai-tooling/install.sh \
  --operation repair \
  --target /projects/example/backend \
  --owned-modified replace
```

`replace` applies only to content supported by prior ownership state. It does not permit overwriting an unowned conflicting path.

## Uninstall

Uninstall is state-driven and removes only installer-owned content. Project-owned text outside managed blocks in files such as `AGENTS.md`, `.gitignore`, and `.gitattributes` is preserved.

```powershell
.\installers\codex-ai-tooling\install.ps1 -Operation uninstall -Target 'D:\Projects\Example\backend'
```

```bash
./installers/codex-ai-tooling/install.sh --operation uninstall --target /projects/example/backend
```

Use `-DryRun` / `--dry-run` to inspect an uninstall before mutation.

## Using Serena after installation

Trust the repository in Codex and start a fresh Codex session from the repository root so project-scoped `.codex/config.toml` is loaded.

Serena is selected for semantic tasks such as:

- declaration and symbol lookup;
- references and implementations;
- file/symbol diagnostics;
- explicitly approved symbol-aware edits.

Ordinary file reading, Git inspection, tests, and known literal edits should continue to use normal repository tools.

The Serena Compose command may build the pinned tooling image lazily on first use. MCP protocol output is isolated from Compose progress output.

## Using Graphify

Graphify is not an MCP server. Use only the installed wrappers and always provide an explicit repository-relative scope.

Build or reuse the graph for one scope:

```powershell
.\.ai\scripts\graphify-build.ps1 -Scope 'src/payments'
```

```bash
./.ai/scripts/graphify-build.sh src/payments
```

Query the same scope:

```powershell
.\.ai\scripts\graphify-query.ps1 `
  -Scope 'src/payments' `
  -Question 'Which modules depend on the retry policy?'
```

```bash
./.ai/scripts/graphify-query.sh src/payments 'Which modules depend on the retry policy?'
```

Force a rebuild when needed:

```powershell
.\.ai\scripts\graphify-update.ps1 -Scope 'src/payments'
```

The graph is derived evidence. Verify material conclusions against source code and, where appropriate, Serena.

## Context7 and Sentry

Context7 is for external, version-specific documentation only. Resolve the actual library version from the target manifest/lockfile before querying it.

Sentry is optional and restricted to the configured read-only tools. Use it only for a real incident. It is not a general debugging/search service and is never required for local tooling readiness.

Authentication is handled outside committed repository content.

## What the installer does not do

The installer does not:

- run application `npm install`, `pnpm install`, `yarn install`, or `bun install`;
- run `cargo build`, `cargo fetch`, or `cargo install` in the target repository;
- install Serena, Graphify, TypeScript language tooling, Rust tooling, or browser tooling globally on the host;
- modify the Git index, commit, stash, reset, clean, or push;
- overwrite unowned conflicts;
- modify user/global Codex configuration;
- expose Docker socket or privileged containers.

## Ownership and recovery paths

The compatibility ownership state is:

```text
.qbit/toolkit/installed/codex-ai-tooling.json
```

Transaction, recovery, and backup evidence for the 1.0 contract lives under:

```text
.qbit-toolkit/codex-ai-tooling/
```

Do not delete these paths manually while the installer is installed. Use the lifecycle operations so ownership evidence remains coherent.

## Recommended automation flow

For CI or a future CLI adapter:

```text
plan --format json
-> inspect exit code/conflicts
-> install/update/repair --format json
-> verify
-> doctor when runtime validation is required
```

Preserve the installer exit code and JSON result. Do not reimplement ownership or transaction logic in the calling CLI.
