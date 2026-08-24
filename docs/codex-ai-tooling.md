---
id: codex-ai-tooling
title: Codex AI Tooling
sidebar_label: Codex AI Tooling
sidebar_position: 3
---

# Codex AI Tooling

`installer.codex-ai-tooling` is the first implemented Qbit AI Toolkit asset. It installs a repository-owned Serena/Graphify/Doctor environment into an existing Git work tree without adding application dependencies or modifying user-level Codex configuration.

## Supported hosts and profiles

The manifest currently declares Windows, Linux, and macOS support with these profiles:

- `auto` — detect the target profile.
- `generic` — language-neutral baseline.
- `typescript` — TypeScript-aware profile.
- `rust` — Rust-aware profile.

The `generic`, `typescript`, and `rust` profiles now have concrete templates and pinned runtime contracts. TypeScript uses TypeScript 5.9.3 with TypeScript Language Server 5.1.3; Rust uses toolchain 1.85.0 with `rust-analyzer` from the pinned Rust image. Profile readiness is enforced by repository validation and installer tests.

For installation and lifecycle commands, see [Using the Codex AI Tooling installer](./ai-tools/codex-ai-tooling-installer.md).

## Lifecycle operations

Both host entrypoints expose the same operations:

| Operation | Purpose | Mutation |
| --- | --- | --- |
| `plan` | Classify the target and report deterministic actions/conflicts | Read-only |
| `install` | Fresh or idempotent installation | Writes owned content |
| `update` | Apply a new payload using valid ownership evidence | Writes owned content |
| `repair` | Restore installer-owned content from the current payload | Writes owned content |
| `verify` | Check static ownership and integrity | Read-only |
| `doctor` | Run verify and isolated runtime health checks | Runtime checks |
| `uninstall` | Remove only content supported by ownership evidence | Removes owned content |

## Entrypoints

PowerShell:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan `
  -Target C:\work\consumer `
  -Profile generic `
  -Format json `
  -NonInteractive
```

POSIX:

```bash
installers/codex-ai-tooling/install.sh \
  --operation plan \
  --target /work/consumer \
  --profile generic \
  --format json \
  --non-interactive
```

Legacy verifier and uninstaller entrypoints remain available for compatibility, but new integrations should use the lifecycle operation exposed by `install.ps1` or `install.sh`.

## Ownership model

The installer does not treat matching bytes as ownership. Full-file ownership is established only by successfully publishing installer state.

- An absent path may be created.
- An unchanged installer-owned path may be updated or removed.
- A modified installer-owned path conflicts by default.
- `owned-modified=replace` may replace a previously owned file only after backup.
- An unowned conflicting path is never overwritten.
- An unowned byte-identical path remains unowned.

`AGENTS.md`, `.gitignore`, and `.gitattributes` use exact marker-owned blocks so project-owned content outside the block is preserved.

## Transaction and recovery model

Mutating operations classify conflicts before writing, acquire an installer lock, create transaction evidence, back up existing owned content, write non-state content, and publish ownership state last. Failed writes attempt rollback. Incomplete transactions are recovered only from explicit journal and backup evidence.

The compatibility state path remains `.qbit/toolkit/installed/codex-ai-tooling.json`. Portable transaction and recovery evidence remains under `.qbit-toolkit/codex-ai-tooling/` for the 1.1 compatibility contract.

## Runtime isolation

The payload is designed around a pinned container runtime:

- Serena receives the target workspace read-write for approved semantic operations.
- Graphify receives the workspace read-only and writes derived data outside the workspace.
- Doctor receives the workspace read-only.
- Services use a read-only root filesystem, disabled networking, `no-new-privileges`, and dropped capabilities except for tightly bounded bootstrap requirements.
- Graphify is CLI-only and is not configured as an MCP server.

## Future CLI boundary

A future standalone Qbit AI Toolkit CLI should treat this installer as a child-process contract rather than importing or reimplementing installer logic. The CLI may resolve the asset, verify release integrity, normalize arguments, invoke the host entrypoint, consume the single JSON result, and preserve the installer exit code.
