# Codex AI Tooling installer

`installer.codex-ai-tooling` installs a self-contained, repository-owned AI development toolchain into an existing Git work-tree root. It manages local Serena/Graphify runtime assets, project-scoped MCP configuration, routing policy, and lifecycle state without installing application dependencies, changing user-level Codex configuration, or mutating the Git index.

Local browser/Playwright tooling is intentionally absent. Context7 and read-only Sentry are optional remote capabilities and are not prerequisites for local runtime readiness.

## Entrypoints

PowerShell 5.1 or later:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan -Target C:\work\consumer -Profile auto `
  -Format json -NonInteractive
```

POSIX Bash:

```bash
installers/codex-ai-tooling/install.sh \
  --operation plan --target /work/consumer --profile auto \
  --format json --non-interactive
```

Both entrypoints expose the same operations:

- `plan`: deterministic, read-only planning.
- `install`: fresh or idempotent repeated installation.
- `update`: requires valid ownership state and applies a new payload/profile.
- `repair`: requires valid ownership state and restores owned content.
- `verify`: strictly read-only static integrity checks.
- `doctor`: verify followed by the installed isolated runtime Doctor.
- `uninstall`: removes only content supported by ownership evidence.

Common options are target, profile (`auto`, `generic`, `typescript`, or `rust`), output format (`text` or `json`), non-interactive mode, dry-run, and owned-modified policy (`fail` or `replace`). `replace` applies only to a previously recorded installer-owned file, makes a backup, and never overrides unowned conflicts. There is no general force option.

The legacy `verify.ps1`, `verify.sh`, `uninstall.ps1`, and `uninstall.sh` entrypoints remain available, but new integrations should use `install.ps1` or `install.sh` with `operation`.

## Profiles and runtime

The common runtime pins Serena 1.5.3, Graphify 0.9.12, PowerShell 7.6.4, PowerShellEditorServices 4.4.0, PSScriptAnalyzer 1.25.0, ShellCheck 0.10.0, Pyright 1.1.403, Bash Language Server 5.6.0, TypeScript 5.9.3, and TypeScript Language Server 5.1.3. Image digests, Debian snapshot metadata, artifact hashes, and dependency locks are immutable build inputs.

Profiles add project-specific semantic capability:

- `generic`: PowerShell, Bash, and Python.
- `typescript`: shared languages plus TypeScript 5.9.3 / TypeScript Language Server 5.1.3.
- `rust`: shared languages plus Rust 1.85.0 and its pinned `rust-analyzer` component.
- `auto`: detects root TypeScript metadata first, then root `Cargo.toml`, otherwise generic.

TypeScript and Rust language tooling is built into the repository-owned image. Bootstrap and Doctor never run target-root application package installation, `cargo build`, `cargo fetch`, or `cargo install` to prepare AI tooling.

Serena receives `/workspace` read-write only so explicitly approved semantic edit tools can operate. Graphify and Doctor receive it read-only. Graphify writes only to `/graphify-output`, with output namespaced by explicit repository-relative scope. Local runtime services have network disabled, read-only root filesystems, `no-new-privileges`, and dropped capabilities. Doctor runs as the mapped `ai-tooling` UID/GID 10001.

Graphify remains CLI-only and is invoked through the installed scoped wrappers. Project-scoped Codex MCP configuration exposes Serena plus optional Context7 and read-only Sentry connectors. Serena uses the approved 12-tool semantic allowlist; Sentry uses only organization/project/resource/event/issue reads.

## Routing contract

Installed `AGENTS.md`, `.ai/policies/tool-boundaries.md`, and skills enforce these categories:

- ordinary repository work -> built-in file/command/Git tools;
- semantic code work -> Serena;
- broad architecture-impact work -> scoped Graphify, then source/Serena validation;
- external version-specific documentation -> Context7;
- real runtime incident analysis -> read-only Sentry.

Tool availability is not permission to invoke every tool on every task.

## State and safety

The published 1.0 ownership state remains at `.qbit/toolkit/installed/codex-ai-tooling.json` for compatibility. Paths and hashes in this state are authoritative; matching unowned files are not silently adopted. Transaction and recovery evidence is kept under `.qbit-toolkit/codex-ai-tooling/`.

Mutations compute conflicts before writing, acquire an installer lock, back up replaced owned content, publish ownership state last, and roll back completed writes after a failure. Plan and verify are read-only. Broad Git reset/clean/stash operations are not part of installer recovery.

## Documentation

See:

- [process and JSON contract](docs/process-contract.md)
- [ownership and conflicts](docs/ownership.md)
- [rollback and recovery](docs/recovery.md)
- [architecture](docs/architecture.md)
- [release preparation](docs/release.md)
- [migration notes](MIGRATION.md)
- public site guide: `docs/ai-tools/codex-ai-tooling-installer.md`

## Future Toolkit CLI boundary

A future standalone Toolkit CLI may locate the host entrypoint from `manifest.json`, invoke it as a child process, pass only normalized arguments, consume the single JSON result, and preserve the installer exit code. The installer neither imports nor depends on that future CLI. `qbit-cli` is outside this contract.
