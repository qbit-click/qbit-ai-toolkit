# Codex AI Tooling installer

`installer.codex-ai-tooling` installs a self-contained, repository-owned
Serena/Graphify/Doctor runtime into an existing Git work-tree root. It never
changes application dependencies, user-level Codex configuration, or the Git
index. Playwright and Sentry are intentionally absent.

## Entrypoints

PowerShell 5.1 or later:

```powershell
.\installers\codex-ai-tooling\install.ps1 `
  -Operation plan -Target C:\work\consumer -Profile generic `
  -Format json -NonInteractive
```

POSIX Bash:

```bash
installers/codex-ai-tooling/install.sh \
  --operation plan --target /work/consumer --profile generic \
  --format json --non-interactive
```

Both entrypoints expose the same operations:

- `plan`: deterministic, read-only planning.
- `install`: fresh or idempotent repeated installation.
- `update`: requires valid ownership state and applies a new payload.
- `repair`: requires valid ownership state and restores owned content.
- `verify`: strictly read-only static integrity checks.
- `doctor`: verify followed by the installed isolated runtime Doctor.
- `uninstall`: removes only content supported by ownership evidence.

Common options are target, profile (`auto`, `generic`, `typescript`, or `rust`),
output format (`text` or `json`), non-interactive mode, dry-run, and
owned-modified policy (`fail` or `replace`). `replace` applies only to a
previously recorded installer-owned file, makes a backup, and never overrides
unowned conflicts. There is no general force option.

The legacy `verify.ps1`, `verify.sh`, `uninstall.ps1`, and `uninstall.sh`
entrypoints remain available, but new process integrations should use
`install.ps1` or `install.sh` with `operation`.

## Runtime

The payload contains the exact pinned project-local behavioral reference:
Serena 1.5.3, Graphify 0.9.12, PowerShell 7.6.4,
PowerShellEditorServices 4.4.0, PSScriptAnalyzer 1.25.0, ShellCheck 0.10.0,
Pyright 1.1.403, and Bash Language Server 5.6.0. Image digests, Debian snapshot,
artifact hashes, and hashed Python locks are immutable inputs.

Serena receives `/workspace` read-write. Graphify and Doctor receive it
read-only. Graphify writes only to `/graphify-output`. Every service has network
disabled, a read-only root filesystem, `no-new-privileges`, and dropped
capabilities. Graphify is CLI-only. The Codex MCP configuration contains only
Serena and optional Context7, with Serena restricted to the approved 12 tools.

## State and safety

The published 1.0 ownership state remains at
`.qbit/toolkit/installed/codex-ai-tooling.json` for compatibility. Paths and
hashes in this state are authoritative; matching unowned files are not silently
adopted. Mutations compute conflicts before writing, back up replaced owned
content, publish ownership state last, and roll back completed writes after a
failure. Verify and plan use OS temporary storage only.

See:

- [process and JSON contract](docs/process-contract.md)
- [ownership and conflicts](docs/ownership.md)
- [rollback and recovery](docs/recovery.md)
- [architecture](docs/architecture.md)
- [release preparation](docs/release.md)
- [migration notes](MIGRATION.md)

## Future Toolkit CLI boundary

A future standalone Toolkit CLI may locate the host entrypoint from
`manifest.json`, invoke it as a child process, pass only normalized arguments,
consume the single JSON result, and preserve the installer exit code. The
installer neither imports nor depends on that future CLI. qbit-cli is outside
this contract.
