# CodexPro Windows Deployment Installer

`installer.codexpro` provisions the complete Qbit CodexPro Windows deployment used by the ChatGPT MCP connector path. It is intentionally pinned to **CodexPro 0.29.0** because the Windows workspace-sandbox and direct-host extensions modify that exact build.

## What the installer owns

The PowerShell installer:

1. validates Windows and the requested workspace;
2. ensures Git for Windows/Git Bash, a supported JavaScript package manager, Codex CLI, CodexPro 0.29.0, and `cloudflared` are available;
3. verifies Codex CLI authentication and starts interactive `codex login` when required;
4. applies the version-specific CodexPro package patch, including the workspace Bash sandbox/environment fix and the `host_exec` / `open_app` extension;
5. creates or preserves a 256-bit MCP token under the current user's CodexPro state directory;
6. writes deployment configuration and installs `Start-CodexPro.ps1` plus a connector-URL helper;
7. installs a managed `cpx` function in the current PowerShell profile unless disabled;
8. creates or reuses the requested Cloudflare named tunnel and routes the supplied hostname unless tunnel setup is explicitly skipped;
9. runs the installer verifier before reporting success.

The installer does **not** create a ChatGPT connector in the ChatGPT UI. After installation, run `cpx` and use the generated MCP Server URL, or explicitly run the installed connector-URL helper when you need to copy the secret URL.

## Required parameters

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 `
  -WorkspaceRoot 'D:\Projects\ExampleProject' `
  -Hostname 'codexpro.example.com' `
  -TunnelName 'codexpro-local'
```

`WorkspaceRoot` and `Hostname` are mandatory. `TunnelName` defaults to `codexpro-local`.

Important optional parameters:

- `-HostExecMode off|on-request|full-access` — default `on-request`;
- `-TunnelProtocol auto|quic|http2` — default `http2`;
- `-PackageManager auto|bun|npm|pnpm` — default `auto`;
- `-SkipTunnelSetup` — install everything locally without changing Cloudflare tunnel/DNS state;
- `-ProfilePath <path>` — override the PowerShell profile file that receives the managed `cpx` block; by default the active user's PowerShell profile is used;
- `-SkipProfileUpdate` — do not edit the PowerShell profile;
- `-SkipCodexLogin` — require an already-authenticated Codex CLI instead of starting login;
- `-Force` — allow intentional replacement of conflicting installer-owned state/token or an exact-0.29.0 unrecognized patch file after review. It does not overwrite or migrate a different CodexPro version.

## Hostname and Cloudflare ownership

The installer receives the public hostname as a parameter; it does not invent a domain. The caller must control that hostname in the Cloudflare account used by `cloudflared`.

When tunnel setup is enabled, the installer checks Cloudflare authentication, starts `cloudflared tunnel login` interactively if needed, creates or reuses `TunnelName`, and routes `Hostname` to that named tunnel.

## Security model

- The local MCP listener remains on loopback.
- Bash runs through the Codex `:workspace` sandbox and remains bounded by the selected workspace.
- Direct host execution is separate. `on-request` requires a local approval dialog; `full-access` deliberately removes that per-request dialog and therefore requires stricter connector/token handling.
- ChatGPT connector permissions remain a separate authorization gate. Enabling `full-access` locally does not force ChatGPT to permit host actions.
- The MCP token and any token-bearing connector URL are secrets and are not written to repository files or normal installer logs.
- Uninstall restores the package backup only when it can do so safely. If CodexPro did not exist before this installer, uninstall also removes that installer-owned global CodexPro package. Git, Codex CLI, the selected package manager, and cloudflared are preserved because they are shared host dependencies.
- Cloudflare tunnel deletion is opt-in during uninstall.

## Installed state

Default user state:

```text
~\.codexpro\
├── backups\
├── deployment.json
├── http-token
├── Start-CodexPro.ps1
└── Get-CodexProConnectorUrl.ps1
```

The installer also writes an ownership/rollback record in `deployment.json` and a managed `cpx` block in the active PowerShell profile unless profile updates are disabled.

## Verification

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
```

Verification checks the pinned package version, patch markers, token format, launcher/config state, Git Bash, Codex CLI login state, `cloudflared`, and the named tunnel when tunnel checking is enabled. It never prints the MCP token.

## Uninstall

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

The default uninstall removes managed launcher/profile/state assets and restores the CodexPro package from the installer-owned backup when safe. Use `-RemoveTunnel` only when the named Cloudflare tunnel is owned exclusively by this deployment and should be deleted.

## Platform boundary

Version 1.0.0 is Windows-only because the custom host-execution approval flow and the pinned package patch target Windows. The POSIX entrypoints intentionally return an unsupported-platform error instead of pretending to provide equivalent behavior.
