---
id: windows-setup
title: CodexPro on Windows — Setup Guide
sidebar_label: Windows setup
---

# CodexPro on Windows — Setup Guide

This guide documents a **reusable Windows setup**, not a snapshot of any specific developer machine, customer project, hostname, tunnel, account, or package-manager layout.

The examples use placeholders such as `<PUBLIC_HOSTNAME>` and `<WORKSPACE_PATH>`. Replace them with values from your own environment. Do not copy credentials, tunnel IDs, usernames, local package paths, or connector names from another deployment.

## Target architecture

A typical remote-to-local setup looks like this:

```text
ChatGPT
  |
  | MCP connector
  v
https://<PUBLIC_HOSTNAME>/mcp
  |
  | secure named tunnel
  v
http://127.0.0.1:8787/mcp
  |
  v
CodexPro
  |
  +-- repository/workspace tools
  +-- bash -> Codex workspace sandbox -> Git Bash
  +-- optional host execution extension
```

The important trust boundaries are:

- the MCP listener stays on loopback;
- the public endpoint is provided by a secure tunnel;
- the MCP endpoint is authenticated;
- Bash remains bounded by the selected workspace;
- direct Windows-host execution, when enabled, is a separate and more privileged capability.

## Version policy

The historical Qbit reference setup was validated against **CodexPro `0.29.0`** for version-specific Windows customizations. Treat any source patch or custom extension as tied to the exact build it was written for.

For a stock installation, use the CodexPro version required by your environment and verify the supported CLI flags before deployment. Do not assume a patch written for `0.29.0` applies to another build.

Record the actual versions used by your deployment:

```powershell
pwsh --version
git --version
codex --version
codexpro --version
cloudflared --version
```

## Deployment values

Use environment-specific values rather than hardcoded personal values:

| Item | Recommended form |
|---|---|
| Windows home | `$HOME` |
| Workspace root | `<WORKSPACE_PATH>` |
| CodexPro state | `$HOME\.codexpro` |
| CodexPro package directory | `<CODEXPRO_PACKAGE_DIR>` |
| Git Bash | discovered with `Get-Command` or configured explicitly |
| Local MCP | `http://127.0.0.1:8787/mcp` |
| Public hostname | `<PUBLIC_HOSTNAME>` |
| Tunnel name | `<TUNNEL_NAME>` |
| Tunnel transport | `http2` by default; `auto` or `quic` when explicitly selected |
| ChatGPT connector name | `<CONNECTOR_NAME>` |
| Host execution mode | `off`, `on-request`, or `full-access` |

A reusable launcher should accept these as parameters or configuration values instead of embedding a username, machine name, project name, DNS name, tunnel ID, or global package path.

## Recommended: complete Qbit installer

For the Qbit-patched Windows deployment, prefer the versioned installer under `installers/codexpro/` instead of assembling the patch, token, launcher, profile helper, and tunnel manually:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\installers\codexpro\install.ps1 `
  -WorkspaceRoot '<WORKSPACE_PATH>' `
  -Hostname '<PUBLIC_HOSTNAME>' `
  -TunnelName '<TUNNEL_NAME>'
```

The installer validates or installs host dependencies, pins `codexpro@0.29.0`, verifies Codex CLI authentication, applies the Windows workspace-sandbox and host-execution extension, creates/preserves the MCP token, writes `deployment.json`, installs `Start-CodexPro.ps1` and the managed `cpx` profile helper, creates or reuses the named Cloudflare tunnel, routes the supplied hostname, and runs `verify.ps1` before reporting success.

The caller supplies the hostname because domain ownership is an external deployment fact. If Cloudflare credentials are not already present, the installer starts the normal interactive `cloudflared tunnel login` flow. Use `-SkipTunnelSetup` only when tunnel/DNS provisioning is intentionally managed elsewhere.

Useful policy overrides include `-HostExecMode off|on-request|full-access`, `-TunnelProtocol auto|quic|http2` (default `http2`), and `-PackageManager auto|bun|npm|pnpm`. The sections below document the components the complete installer owns and are also useful for troubleshooting or custom deployments.

## Security boundary

### Sandboxed Bash

```text
ChatGPT -> CodexPro bash -> Codex workspace sandbox -> Git Bash
```

A permissive Bash command policy does **not** imply filesystem access outside the selected workspace. Test containment explicitly, including attempts to use `cwd=..`.

For Windows sandbox operation, keep environment inheritance narrow. Do not enable broad host-environment inheritance merely to fix one missing variable.

### Direct host execution

```text
ChatGPT -> CodexPro host execution -> direct Windows process
```

If your CodexPro build or local extension exposes capabilities such as `host_exec` or `open_app`, treat them as privileged operations:

- use absolute executable paths;
- pass argv directly rather than shell command strings;
- keep `shell: false`;
- filter secret-bearing environment variables;
- prefer `on-request` unless unattended direct execution is an explicit requirement;
- remember that `full-access` does not bypass Windows UAC or administrator boundaries.

ChatGPT connector permissions are a separate gate from CodexPro's local `hostExecMode`. If a workflow intentionally uses `host_exec` or `open_app`, the connector must permit those actions; a low-risk/default connector permission policy can leave workspace tools usable while higher-risk host actions are unavailable.

A token-bearing MCP URL with direct host execution enabled is highly sensitive.

## Prerequisites

Install and verify:

1. PowerShell 7;
2. a package manager capable of installing the `codexpro` npm package;
3. Git for Windows with Git Bash;
4. Codex CLI with valid authentication;
5. `cloudflared` if you use a Cloudflare named tunnel;
6. control of the public hostname used for the connector.

### Package manager choice

**Bun is not required.** CodexPro may be installed with the package manager used by your environment. The important contract is that the selected CodexPro version is installed and the `codexpro` executable is available on `PATH`.

Examples for CodexPro `0.29.0`:

```powershell
# npm
npm install -g codexpro@0.29.0

# pnpm
pnpm add -g codexpro@0.29.0

# Bun
bun add -g codexpro@0.29.0

# Yarn Classic
# yarn global add codexpro@0.29.0
```

Yarn installation syntax differs across Yarn generations; use the global-install mechanism supported by the Yarn version in your environment.

Verify the result independently of the package manager:

```powershell
codexpro --version
Get-Command codexpro
```

## Resolve the CodexPro package directory only when needed

Normal CLI usage should rely on `codexpro` from `PATH`. A package directory is needed only for version-specific inspection or a local patch workflow.

Do not assume a Bun-specific location. Resolve or configure the directory explicitly:

```powershell
$CodexProPackageDir = '<CODEXPRO_PACKAGE_DIR>'
$PackageJson = Join-Path $CodexProPackageDir 'package.json'

if (-not (Test-Path -LiteralPath $PackageJson -PathType Leaf)) {
    throw "CodexPro package.json not found: $PackageJson"
}

$Package = Get-Content -LiteralPath $PackageJson -Raw | ConvertFrom-Json
if ($Package.name -ne 'codexpro') {
    throw "Unexpected package at $CodexProPackageDir"
}
```

Common package-manager helpers may include:

```powershell
# npm
$NpmRoot = npm root -g

# pnpm
$PnpmRoot = pnpm root -g
```

Other package managers may use a different global store or shim layout. The reusable configuration should store the resolved package directory rather than reconstructing it from a username or package-manager assumption.

## Create the CodexPro state directory

Use the current user's home directory:

```powershell
$CodexProDir = Join-Path $HOME '.codexpro'
New-Item -ItemType Directory -Path $CodexProDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'backups') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'bin') -Force | Out-Null
```

Recommended layout:

```text
~\.codexpro\
├── backups\
├── bin\
├── http-token
└── Start-CodexPro.ps1
```

Do not commit this directory or copy it between users as a deployment template.

## Generate the HTTP MCP token

Create a fresh token for each deployment:

```powershell
$TokenFile = Join-Path $HOME '.codexpro\http-token'

$Rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$Bytes = New-Object byte[] 32
$Rng.GetBytes($Bytes)
$Rng.Dispose()

$Token = ($Bytes | ForEach-Object { $_.ToString('x2') }) -join ''
[IO.File]::WriteAllText($TokenFile, $Token)

if ($Token.Length -ne 64 -or $Token -notmatch '^[0-9a-f]{64}$') {
    throw 'Generated MCP token is invalid.'
}
```

Do not print the token in routine logs. Do not place it in repository files.

## Configure a Cloudflare named tunnel

The examples below use Cloudflare because the CodexPro deployment pattern supports a stable public hostname over a named tunnel. Substitute your own values.

```powershell
$TunnelName = '<TUNNEL_NAME>'
$Hostname = '<PUBLIC_HOSTNAME>'

cloudflared tunnel login
cloudflared tunnel create $TunnelName
cloudflared tunnel route dns $TunnelName $Hostname
cloudflared tunnel list
```

The tunnel ID is generated by Cloudflare. Record it only where the tunnel tooling requires it; do not hardcode another deployment's tunnel ID into a reusable launcher.

The public hostname is a deployment input, not something the Windows patch installer discovers or generates. The deployment owner chooses a DNS hostname they control and binds it to the named tunnel with `cloudflared tunnel route dns`. Keep `<PUBLIC_HOSTNAME>` and `<TUNNEL_NAME>` as explicit launcher/configuration inputs.

## Configure Git Bash

Prefer discovery over a user-specific path:

```powershell
$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)

$GitBash = $GitBashCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $GitBash) {
    throw 'Git Bash was not found. Configure its path explicitly.'
}
```

If Git is installed elsewhere, configure that location rather than changing unrelated environment variables.

## Version-specific Windows customizations

Some deployments extend a specific CodexPro build to enforce a particular Windows Bash sandbox path or to expose direct host capabilities such as `host_exec` and `open_app`.

These customizations are **not portable deployment values**. Treat them as a versioned patch asset with the following rules:

1. pin the exact CodexPro build the patch targets;
2. pass `<CODEXPRO_PACKAGE_DIR>` explicitly;
3. never embed a Windows username, home directory, project path, public hostname, tunnel ID, or connector name in patch source;
4. use exact structural anchors and fail if an expected anchor is absent or duplicated;
5. back up changed package files before mutation;
6. validate the resulting files before startup;
7. calculate hashes from the patch version you actually deploy rather than copying hashes from another machine;
8. re-review and re-test the patch after every CodexPro update.

If stock CodexPro already provides the capability you need, prefer the stock implementation instead of maintaining a local patch.

### Current Qbit Windows patch-installer boundary

The Qbit reference script named `Install-CodexProWorkspaceSandbox.ps1` is a **package patch installer**, not a complete CodexPro deployment installer. Its current responsibility is limited to the version-specific Windows Bash sandbox/environment patch:

- it receives the CodexPro package directory;
- it patches the supported `dist` files and creates rollback backups;
- it does **not** create `Start-CodexPro.ps1`;
- it does **not** create the MCP token;
- it does **not** request, discover, or store a public hostname or Cloudflare tunnel name.

The launcher and tunnel configuration are therefore separate deployment assets. In the current design, `<PUBLIC_HOSTNAME>` and `<TUNNEL_NAME>` are supplied to the launcher/configuration, while the patch installer remains independent of DNS and tunnel ownership.

`qbit-ai-toolkit` now publishes this as the formal Windows-only `installer.codexpro` asset under `installers/codexpro/`. The installer owns the complete deployment flow: dependency validation/installation, the pinned CodexPro `0.29.0` package patch, MCP token, launcher, `cpx` helper, and named-tunnel/DNS setup. `installer.codex-ai-tooling` remains a separate repository AI-development-tooling installer.

## Reusable launcher

A launcher should take deployment values as parameters. The following example intentionally contains no personal path or hostname:

```powershell
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path,

    [Parameter(Mandatory)]
    [string]$Hostname,

    [Parameter(Mandatory)]
    [string]$TunnelName,

    [ValidateSet('off', 'on-request', 'full-access')]
    [string]$HostExecMode = 'on-request',

    [ValidateSet('auto', 'quic', 'http2')]
    [string]$TunnelProtocol = 'http2'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Workspace does not exist: $Root"
}

$TokenFile = Join-Path $HOME '.codexpro\http-token'
if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "CodexPro token file not found: $TokenFile"
}

$GitBashCandidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe'
)
$GitBash = $GitBashCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $GitBash) {
    throw 'Git Bash was not found.'
}

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$McpToken = [IO.File]::ReadAllText($TokenFile).Trim()
if ([string]::IsNullOrWhiteSpace($McpToken) -or $McpToken -match '\s') {
    throw 'CodexPro token is empty or invalid.'
}

$PreviousBashSandbox = $env:CODEXPRO_BASH_SANDBOX
$PreviousBashExecutable = $env:CODEXPRO_BASH_EXECUTABLE
$PreviousHostExecMode = $env:CODEXPRO_HOST_EXEC_MODE
$PreviousTunnelTransportProtocol = $env:TUNNEL_TRANSPORT_PROTOCOL

$env:CODEXPRO_BASH_SANDBOX = 'workspace'
$env:CODEXPRO_BASH_EXECUTABLE = $GitBash
$env:CODEXPRO_HOST_EXEC_MODE = $HostExecMode
$env:TUNNEL_TRANSPORT_PROTOCOL = $TunnelProtocol

$CodexProArgs = @(
    'stable',
    '--root', $ResolvedRoot,
    '--hostname', $Hostname,
    '--tunnel-name', $TunnelName,
    '--token', $McpToken,
    '--agent',
    '--tool-mode', 'full',
    '--write', 'workspace',
    '--bash', 'full'
)

try {
    & codexpro @CodexProArgs
}
finally {
    $env:CODEXPRO_BASH_SANDBOX = $PreviousBashSandbox
    $env:CODEXPRO_BASH_EXECUTABLE = $PreviousBashExecutable
    $env:CODEXPRO_HOST_EXEC_MODE = $PreviousHostExecMode
    $env:TUNNEL_TRANSPORT_PROTOCOL = $PreviousTunnelTransportProtocol
}
```

Save it under your local state directory, for example:

```text
~\.codexpro\Start-CodexPro.ps1
```

The launcher remains portable because workspace root, hostname, tunnel name, host-execution mode, and tunnel transport are supplied as deployment values. `http2` is the recommended default for this long-lived MCP/SSE path; `auto` and `quic` remain available for environments where they are preferable.

## Optional `cpx` helper

A PowerShell helper can launch CodexPro for the current repository without hardcoding a home directory:

```powershell
function cpx {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Root = (Get-Location).Path,

        [Parameter(Mandatory)]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [string]$TunnelName
    )

    $Launcher = Join-Path $HOME '.codexpro\Start-CodexPro.ps1'
    & $Launcher -Root $Root -Hostname $Hostname -TunnelName $TunnelName
}
```

Example project invocation:

```powershell
cpx -Root 'D:\Projects\ExampleProject' -Hostname 'codexpro.example.com' -TunnelName 'codexpro-local'
```

For routine project work, prefer the narrowest practical repository root instead of exposing an entire user profile.

## Connect ChatGPT

After the server and tunnel are healthy, create an MCP connector in ChatGPT with deployment-owned values:

| Field | Value |
|---|---|
| Name | `<CONNECTOR_NAME>` |
| Server URL | the exact token-bearing URL produced by the running CodexPro instance |
| Authentication | the mode required by the deployed endpoint |
| Permissions | only the actions required by the workflow |

Do not standardize a personal connector name in public documentation. The connector name is a deployment choice.

Treat the generated connector URL as a secret if it contains authentication material.

## Verification

### 1. Local health

Verify the local endpoint before testing the public tunnel:

```text
http://127.0.0.1:8787/healthz
```

It should return a healthy response for the running build.

### 2. Configuration

Use CodexPro's configuration/diagnostic command or MCP configuration resource to confirm the effective values for:

- host and port;
- authentication enabled;
- selected workspace root;
- Bash mode;
- write mode;
- tool mode;
- environment inheritance;
- host-execution mode, if that extension is installed;
- the intended tunnel transport when a public Cloudflare tunnel is used.

Do not validate against a fixed tool count copied from another deployment; tool inventory may vary by version and enabled capability set.

### 3. Workspace containment

Open a test repository as `<WORKSPACE_PATH>`, then verify that a request using `cwd=..` cannot escape the selected root.

The expected result is a containment error, not execution in the parent directory.

### 4. Bash path

Run a harmless command such as `pwd` and verify that the resulting path corresponds to the selected workspace.

### 5. Host execution

Only if your deployment intentionally enables a host-execution extension, test it with a harmless absolute executable such as:

```text
C:\Windows\System32\whoami.exe
```

Confirm that approval behavior matches the selected mode.

Also confirm the ChatGPT connector permission policy allows the intended host action. Workspace-scoped tools and `open_workspace` remain governed by CodexPro `allowedRoots`; successful `host_exec` outside that workspace is a separate capability and should only be tested intentionally with a harmless read-only command.

### 6. Public tunnel

Verify that the public hostname routes to the local CodexPro endpoint and that unauthenticated requests cannot gain MCP access. With the recommended launcher default, `cloudflared` startup should report `Initial protocol http2` and registered tunnel connections with `protocol=http2`.

### 7. End-to-end connector

Use a disposable test repository and confirm a minimal read → controlled edit/write → verification loop. Do not use a production repository as the first end-to-end test.

## Update policy

Do not update a version-specific patched installation blindly.

Before updating:

1. record the installed CodexPro version;
2. back up local state required for recovery, excluding secrets from source control;
3. back up any package files changed by a local extension;
4. install the intended new version with your chosen package manager;
5. resolve the new package directory if the manager or layout changed;
6. compare the new implementation with the patch assumptions;
7. re-apply or retire custom patches only after review;
8. run the complete acceptance checks;
9. move the production connector only after validation passes.

The package manager may change independently of CodexPro. Do not encode package-manager storage layout as part of the CodexPro architecture.

## Troubleshooting

### `codexpro` is not found

Check the package manager's global binary/shim directory and ensure it is on `PATH`:

```powershell
Get-Command codexpro -ErrorAction SilentlyContinue
```

### The patch script cannot find `dist`

The configured `<CODEXPRO_PACKAGE_DIR>` is wrong or the installed package layout changed. Resolve the actual package directory for the package manager in use; do not fall back to a hardcoded Bun path.

### Bash cannot start

Verify Git Bash independently, then confirm `CODEXPRO_BASH_EXECUTABLE` points to the detected `bash.exe`.

### Workspace escape succeeds

Treat this as a security failure. Stop the remote connector until workspace containment is restored and re-verified.

### Tunnel works locally but not publicly

Check DNS routing, named-tunnel status, hostname ownership, and authentication separately. Do not weaken MCP authentication to diagnose a tunnel problem.

### Tunnel connections flap or all edge connections drop together

Inspect VPN, TUN, proxy, and default-route changes before blaming the selected Cloudflare transport. A VPN/TUN interface can intercept `cloudflared` traffic and destabilize both QUIC and HTTP/2. If the problem disappears when the VPN is disabled or Cloudflare tunnel traffic is bypassed around the VPN, fix the routing policy rather than repeatedly switching protocols.

For the Windows reference launcher, keep `http2` as the default unless testing shows a concrete reason to use `auto` or `quic`.

### Host execution is too permissive

Set the host-execution mode to `on-request` or `off`, then restart and verify the effective configuration.

## Acceptance checklist

- [ ] The intended CodexPro version is installed and recorded.
- [ ] `codexpro` resolves from `PATH` regardless of package manager.
- [ ] No username, machine name, project name, public hostname, tunnel ID, or package-manager-specific global path is embedded in reusable scripts.
- [ ] The MCP listener is bound to loopback.
- [ ] The public tunnel hostname resolves correctly.
- [ ] The intended tunnel transport is explicit; the Windows reference default is `http2`.
- [ ] MCP authentication is enabled and its secret is not committed.
- [ ] The selected workspace root is explicit.
- [ ] `cwd=..` cannot escape the workspace.
- [ ] Git Bash executes inside the intended workspace sandbox.
- [ ] Broad host environment inheritance is disabled unless explicitly required and reviewed.
- [ ] Optional direct host execution uses the intended approval mode.
- [ ] ChatGPT connector permissions allow host actions only when that capability is intentionally required.
- [ ] VPN/TUN routing does not destabilize the public tunnel, or tunnel traffic is explicitly bypassed around it.
- [ ] A disposable end-to-end connector test passes.
- [ ] Version-specific patches, if any, were generated and validated for the exact installed build.

## Recommended operational rule

Public documentation should describe **contracts and placeholders**, not a developer's machine. Keep these values outside canonical docs:

```text
real Windows usernames
real home-directory paths
real customer/project names
real connector names tied to a person
real public hostnames used by a private deployment
real tunnel IDs
authentication tokens
package-manager-specific global directories presented as universal
```

That separation makes the CodexPro guide reusable across machines, teams, package managers, and repositories.
