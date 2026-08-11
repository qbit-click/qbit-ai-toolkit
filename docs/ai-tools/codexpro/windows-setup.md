---
id: windows-setup
title: CodexPro on Windows — Canonical Setup Runbook
sidebar_label: Windows setup
---

> **Imported reference:** This page preserves the supplied canonical runbook's technical content, version pins, exact patch blocks, deployment values, and reference hashes. The source itself names `qbit-click/qbit-platform-docs` as its intended repository; it is included here in Qbit AI Toolkit documentation without silently changing that source statement.

# CodexPro on Windows — Canonical Setup Runbook

> **Status:** Reference configuration captured on 2026-08-10<br/>
> **Purpose:** Rebuild CodexPro from zero and end with the same architecture and behavior as the current AminPC setup.<br/>
> **Intended repository:** `qbit-click/qbit-platform-docs`<br/>
> **Reference CodexPro build:** `0.29.0` — the custom patches in this runbook are version-specific.

---

## 1. Target state

Following this runbook must produce this architecture:

```text
ChatGPT
  |
  |  MCP connector: AminPC
  v
https://<PUBLIC_HOSTNAME>/mcp
  |
  |  Cloudflare named tunnel
  v
http://127.0.0.1:8787/mcp
  |
  v
CodexPro 0.29.0
  |
  +-- normal workspace tools
  |
  +-- bash
  |    |
  |    +-- codex sandbox -P :workspace
  |         |
  |         +-- workspace-bounded execution
  |         +-- Git Bash
  |         +-- restricted environment
  |
  +-- host_exec / open_app
       |
       +-- direct Windows-user execution
       +-- shell: false
       +-- default mode: full-access
       +-- optional modes: on-request / off
```

Reference behavior:

- MCP listens only on `127.0.0.1:8787`.
- Public access uses a **Cloudflare named tunnel** with a stable hostname.
- HTTP MCP authentication is enabled.
- ChatGPT connector name: `AminPC`.
- CodexPro mode: `Agent`.
- `tool-mode=full`.
- `write=workspace`.
- `bash=full`.
- Bash still runs through **Codex workspace sandbox**.
- Bash cannot escape the selected workspace root through `cwd=..`.
- `CODEXPRO_INHERIT_ENV` is **not** enabled.
- Windows restricted Bash environment adds only `USERPROFILE` and `TEMP` beyond the original restricted set.
- `host_exec` and `open_app` run outside Codex sandbox as the current Windows user.
- The launcher defaults host execution to `full-access`, so there is no approval dialog for every host operation.
- Full access does **not** bypass Windows UAC or Administrator boundaries.

---

## 2. Reference versions

| Component | Reference version |
|---|---:|
| Windows | Windows 11 |
| PowerShell | 7.6.4 |
| Bun | 1.3.14 |
| CodexPro | **0.29.0** |
| Codex CLI | 0.146.1 |
| Git for Windows | 2.55.0.windows.3 |
| cloudflared | 2026.7.3 |

**Pin CodexPro to `0.29.0` when reproducing this exact setup.** The custom patch anchors target this build. Codex CLI, Git, Bun and cloudflared may be updated later, but after an update re-run the verification section.

---

## 3. Fixed vs variable values

### 3.1 Current deployment values

| Item | Current value |
|---|---|
| Windows user | `aminn` |
| Default workspace used by the general PC connector | `C:\Users\aminn` |
| CodexPro directory | `C:\Users\aminn\.codexpro` |
| Installed package | `C:\Users\aminn\.bun\install\global\node_modules\codexpro` |
| Git Bash directory | `C:\Program Files\Git\bin` |
| Local MCP | `http://127.0.0.1:8787/mcp` |
| Public hostname | `codexpro.futech-co.ir` |
| Cloudflare tunnel name | `codexpro-local` |
| Current Cloudflare tunnel ID | `9b09b528-1281-46da-bf02-a6426aa9ff90` |
| PowerShell profile | `D:\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |
| Connector name in ChatGPT | `AminPC` |
| Host execution default | `full-access` |

### 3.2 Values that must be changed on another machine/account

- **Public hostname**: replace `codexpro.futech-co.ir` with the DNS hostname for the new deployment.
- **Tunnel name**: replace `codexpro-local` if the new Cloudflare named tunnel uses another name.
- **Tunnel ID**: Cloudflare generates this. Record it, but do not hardcode it into the launcher.
- **HTTP MCP token**: generate a fresh token for every installation. Never copy the current secret and never commit it.
- **User paths**: most supplied scripts derive user paths from `$HOME`; do not hardcode `C:\Users\aminn` on another account.
- **PowerShell profile**: always discover with `$PROFILE`.
- **Git Bash**: the launcher assumes `C:\Program Files\Git\bin\bash.exe`; change `$GitBashDir` only if Git is installed elsewhere.

---

## 4. Security boundary

There are two distinct execution paths.

### Bash

```text
ChatGPT -> CodexPro bash -> codex sandbox -P :workspace -> Git Bash
```

Even with `bashMode=full`, the process remains inside the Codex workspace sandbox.

### Host execution

```text
ChatGPT -> CodexPro host_exec/open_app -> direct Windows spawn
```

The custom host implementation:

- requires an absolute executable path;
- accepts argv rather than a shell command string;
- uses `shell: false`;
- filters environment variables whose names look secret-bearing;
- supports `off`, `on-request`, and `full-access`;
- defaults to `full-access` in the canonical launcher.

With `full-access`, possession of a valid MCP connector/token can result in direct execution as the Windows user. Protect the token and generated connector URL accordingly.

---

## 5. Prerequisites

Install and verify:

1. PowerShell 7
2. Bun
3. Git for Windows including Git Bash
4. Codex CLI, authenticated
5. A Cloudflare account controlling the target hostname

```powershell
pwsh --version
bun --version
git --version
codex --version
```

---

## 6. Install the pinned CodexPro build

```powershell
bun add -g codexpro@0.29.0
codexpro --version
```

Expected:

```text
0.29.0
```

Reference package directory:

```text
$HOME\.bun\install\global\node_modules\codexpro
```

---

## 7. Create the CodexPro state directory

```powershell
$CodexProDir = Join-Path $HOME '.codexpro'
New-Item -ItemType Directory -Path $CodexProDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'backups') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $CodexProDir 'bin') -Force | Out-Null
```

Expected core layout:

```text
~\.codexpro\
├── backups\
├── bin\
│   └── cloudflared.exe
├── http-token
├── Install-CodexProWorkspaceSandbox.ps1
└── Start-CodexPro.ps1
```

---

## 8. Generate the HTTP MCP token

The token is secret and must never be committed.

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

Do not print the token into logs.

---

## 9. Install cloudflared

Canonical binary location:

```text
$HOME\.codexpro\bin\cloudflared.exe
```

CodexPro supports the `--install-cloudflared` option; alternatively place the official binary there.

```powershell
& "$HOME\.codexpro\bin\cloudflared.exe" --version
```

Reference version: `2026.7.3`.

---

## 10. One-time Cloudflare named-tunnel setup

```powershell
$Cloudflared = "$HOME\.codexpro\bin\cloudflared.exe"
$TunnelName = 'codexpro-local'        # CHANGE if needed
$Hostname   = 'codexpro.futech-co.ir' # CHANGE for another deployment

& $Cloudflared tunnel login
& $Cloudflared tunnel create $TunnelName
& $Cloudflared tunnel route dns $TunnelName $Hostname
& $Cloudflared tunnel list
```

Current reference deployment:

```text
Tunnel name: codexpro-local
Tunnel ID:   9b09b528-1281-46da-bf02-a6426aa9ff90
Hostname:    codexpro.futech-co.ir
```

The launcher uses the **tunnel name**, not the tunnel ID.

---

# Part II — Canonical custom patches

## 11. Why the stock package is patched

### 11.1 Windows Bash/Codex sandbox

Required architecture:

```text
CodexPro -> codex sandbox -P :workspace -> Git Bash
```

Controlled testing established:

- missing `USERPROFILE` can make `codex sandbox` hang/time out;
- `HOME` does not substitute for `USERPROFILE`;
- missing `TEMP` can cause temp-directory behavior and warnings;
- `USERPROFILE + TEMP` is sufficient;
- `TMP`, `SystemRoot`, and full host environment inheritance are not required.

Therefore `CODEXPRO_INHERIT_ENV=1` remains disabled.

### 11.2 Host access

The package is extended with:

```text
host_exec
open_app
```

for operations that must run outside Codex sandbox, such as GUI launches.

## 12. Canonical sandbox/environment installer

Save the **exact following file** as:

```text
$HOME\.codexpro\Install-CodexProWorkspaceSandbox.ps1
```

```powershell
[CmdletBinding()]
param(
    [string]$PackageDir = (Join-Path $HOME '.bun\install\global\node_modules\codexpro')
)

$ErrorActionPreference = 'Stop'

$BashOpsFile = Join-Path $PackageDir 'dist\bashOps.js'
$ConfigFile = Join-Path $PackageDir 'dist\config.js'

foreach ($Path in @($BashOpsFile, $ConfigFile)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "CodexPro file not found: $Path"
    }
}

function Replace-ExactlyOnce {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$OldText,

        [Parameter(Mandatory)]
        [string]$NewText,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $First = $Text.IndexOf($OldText, [StringComparison]::Ordinal)

    if ($First -lt 0) {
        throw "Unsupported CodexPro build; expected block was not found: $Label"
    }

    $Second = $Text.IndexOf($OldText, $First + $OldText.Length, [StringComparison]::Ordinal)

    if ($Second -ge 0) {
        throw "Unsupported CodexPro build; expected block is not unique: $Label"
    }

    return $Text.Substring(0, $First) + $NewText + $Text.Substring($First + $OldText.Length)
}

$BashOps = [IO.File]::ReadAllText($BashOpsFile)
$Config = [IO.File]::ReadAllText($ConfigFile)

$BashPatched = $BashOps.Contains('function sandboxInvocation') -and
    $BashOps.Contains('CODEXPRO_BASH_EXECUTABLE')
$ConfigPatched = $Config.Contains('CODEXPRO_BASH_SANDBOX')
$LegacySandboxArgs = @"
            workspace.root,
            shell,
"@
$CurrentSandboxArgs = @"
            workspace.root,
            "--",
            shell,
"@
$OldMakeEnv = @"
function makeEnv(config) {
    if (config.inheritEnv) {
        return { ...process.env, NO_COLOR: "1", CI: process.env.CI ?? "1" };
    }
    return {
        PATH: process.env.PATH ?? "/usr/local/bin:/usr/bin:/bin",
        HOME: process.env.HOME ?? "",
        USER: process.env.USER ?? "",
        SHELL: process.env.SHELL ?? "/bin/bash",
        TMPDIR: process.env.TMPDIR ?? "/tmp",
        TERM: "dumb",
        NO_COLOR: "1",
        CI: "1"
    };
}
"@
$CurrentMakeEnv = @"
function makeEnv(config) {
    if (config.inheritEnv) {
        return { ...process.env, NO_COLOR: "1", CI: process.env.CI ?? "1" };
    }
    const env = {
        PATH: process.env.PATH ?? "/usr/local/bin:/usr/bin:/bin",
        HOME: process.env.HOME ?? "",
        USER: process.env.USER ?? "",
        SHELL: process.env.SHELL ?? "/bin/bash",
        TMPDIR: process.env.TMPDIR ?? "/tmp",
        TERM: "dumb",
        NO_COLOR: "1",
        CI: "1"
    };
    if (process.platform === "win32") {
        const userProfile = process.env.USERPROFILE;
        if (!userProfile || !userProfile.trim())
            throw new CodexProError("Required Windows environment variable is unavailable: USERPROFILE");
        const temp = process.env.TEMP;
        if (!temp || !temp.trim())
            throw new CodexProError("Required Windows environment variable is unavailable: TEMP");
        env.USERPROFILE = userProfile;
        env.TEMP = temp;
    }
    return env;
}
"@
$BashNewline = if ($BashOps.Contains("`r`n")) { "`r`n" } else { "`n" }
$LegacySandboxArgsForFile = $LegacySandboxArgs.Replace("`r`n", "`n").Replace("`n", $BashNewline)
$CurrentSandboxArgsForFile = $CurrentSandboxArgs.Replace("`r`n", "`n").Replace("`n", $BashNewline)
$OldMakeEnvForFile = $OldMakeEnv.Replace("`r`n", "`n").Replace("`n", $BashNewline)
$CurrentMakeEnvForFile = $CurrentMakeEnv.Replace("`r`n", "`n").Replace("`n", $BashNewline)
$BashPatchCurrent = $BashPatched -and $BashOps.Contains($CurrentSandboxArgsForFile)
$EnvironmentPatchOld = $BashOps.Contains($OldMakeEnvForFile)
$EnvironmentPatchCurrent = $BashOps.Contains($CurrentMakeEnvForFile)

if ($EnvironmentPatchOld -eq $EnvironmentPatchCurrent) {
    throw 'Unsupported CodexPro environment patch state; expected exactly one known makeEnv implementation.'
}

if ($BashPatchCurrent -and $ConfigPatched -and $EnvironmentPatchCurrent) {
    Write-Host 'CodexPro workspace sandbox/environment patch is already installed.'
    exit 0
}

if ($BashPatched -xor $ConfigPatched) {
    throw 'CodexPro workspace sandbox patch is only partially installed; refusing to modify an inconsistent package.'
}

if ($EnvironmentPatchCurrent -and -not ($BashPatchCurrent -and $ConfigPatched)) {
    throw 'CodexPro environment patch is installed without the complete current sandbox/config patch; refusing to modify an inconsistent package.'
}

if ($BashPatched -and -not $BashPatchCurrent -and -not $BashOps.Contains($LegacySandboxArgsForFile)) {
    throw 'Unsupported CodexPro sandbox patch version; refusing to modify an unknown invocation.'
}

$OldBashExecutable = @'
function bashExecutable() {
    return fs.existsSync("/bin/bash") ? "/bin/bash" : "bash";
}
'@

$NewBashExecutable = @'
function bashExecutable() {
    const configured = process.env.CODEXPRO_BASH_EXECUTABLE?.trim();
    if (configured) {
        if (!fs.existsSync(configured))
            throw new CodexProError(`Configured Bash executable does not exist: ${configured}`);
        return configured;
    }
    return fs.existsSync("/bin/bash") ? "/bin/bash" : "bash";
}
function sandboxInvocation(config, workspace, cwd, command) {
    const shell = bashExecutable();
    if (config.bashSandbox !== "workspace") {
        return { command: shell, args: ["-lc", command], cwd };
    }
    const sandboxScript = 'cd -- "$1" && exec bash -lc "$2"';
    const bashCwd = cwd.replaceAll("\\", "/");
    return {
        command: "codex",
        args: [
            "sandbox",
            "-P",
            ":workspace",
            "-C",
            workspace.root,
            "--",
            shell,
            "-lc",
            sandboxScript,
            "codexpro-sandbox",
            bashCwd,
            command
        ],
        cwd: workspace.root
    };
}
'@

$OldSpawn = @'
        const child = spawn(bashExecutable(), ["-lc", command], {
            cwd,
            env: makeEnv(config),
'@

$NewSpawn = @'
        const invocation = sandboxInvocation(config, workspace, cwd, command);
        const child = spawn(invocation.command, invocation.args, {
            cwd: invocation.cwd,
            env: makeEnv(config),
'@

$OldConfigFunction = @'
function codexSessionsFrom(value) {
'@

$NewConfigFunction = @'
function bashSandboxFrom(value) {
    if (!value || value === "off")
        return "off";
    if (value === "workspace")
        return value;
    throw new Error("CODEXPRO_BASH_SANDBOX must be off or workspace.");
}
function codexSessionsFrom(value) {
'@

$OldConfigProperty = @'
        bashMode: bashModeFrom(bashArg ?? process.env.CODEXPRO_BASH_MODE),
        bashTranscript: bashTranscriptFrom(bashTranscriptArg ?? process.env.CODEXPRO_BASH_TRANSCRIPT),
'@

$NewConfigProperty = @'
        bashMode: bashModeFrom(bashArg ?? process.env.CODEXPRO_BASH_MODE),
        bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX),
        bashTranscript: bashTranscriptFrom(bashTranscriptArg ?? process.env.CODEXPRO_BASH_TRANSCRIPT),
'@

if ($BashPatched) {
    if ($BashPatchCurrent) {
        $PatchedBashOps = $BashOps
    }
    else {
        $PatchedBashOps = Replace-ExactlyOnce $BashOps $LegacySandboxArgsForFile $CurrentSandboxArgsForFile 'sandbox command separator'
    }

    $PatchedConfig = $Config
}
else {
    $PatchedBashOps = Replace-ExactlyOnce $BashOps $OldBashExecutable $NewBashExecutable 'bash executable'
    $PatchedBashOps = Replace-ExactlyOnce $PatchedBashOps $OldSpawn $NewSpawn 'bash spawn'
    $PatchedConfig = Replace-ExactlyOnce $Config $OldConfigFunction $NewConfigFunction 'sandbox config parser'
    $PatchedConfig = Replace-ExactlyOnce $PatchedConfig $OldConfigProperty $NewConfigProperty 'sandbox config property'
}

$PatchedBashOps = Replace-ExactlyOnce $PatchedBashOps $OldMakeEnvForFile $CurrentMakeEnvForFile 'Windows environment allowlist'

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path (Join-Path $HOME '.codexpro\backups') "codexpro-sandbox-$Timestamp"
$TempBashOps = "$BashOpsFile.codexpro-sandbox.tmp"
$TempConfig = "$ConfigFile.codexpro-sandbox.tmp"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath $BashOpsFile -Destination (Join-Path $BackupDir 'bashOps.js')
Copy-Item -LiteralPath $ConfigFile -Destination (Join-Path $BackupDir 'config.js')

try {
    [IO.File]::WriteAllText($TempBashOps, $PatchedBashOps)
    [IO.File]::WriteAllText($TempConfig, $PatchedConfig)
    Move-Item -LiteralPath $TempBashOps -Destination $BashOpsFile -Force
    Move-Item -LiteralPath $TempConfig -Destination $ConfigFile -Force
}
catch {
    Copy-Item -LiteralPath (Join-Path $BackupDir 'bashOps.js') -Destination $BashOpsFile -Force
    Copy-Item -LiteralPath (Join-Path $BackupDir 'config.js') -Destination $ConfigFile -Force
    throw
}
finally {
    Remove-Item -LiteralPath $TempBashOps -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $TempConfig -Force -ErrorAction SilentlyContinue
}

Write-Host "Installed CodexPro workspace sandbox/environment patch. Backup: $BackupDir"
```

Reference SHA-256:

```text
97C3BADBA08818BF9CA92BB56158542092F128710A5953664DB3334D13CBF38F
```

Apply it:

```powershell
& "$HOME\.codexpro\Install-CodexProWorkspaceSandbox.ps1"
```

Repeat-run expected output:

```text
CodexPro workspace sandbox/environment patch is already installed.
```

---

## 13. Canonical `hostOps.js`

Create:

```text
$HOME\.bun\install\global\node_modules\codexpro\dist\hostOps.js
```

with the **exact following content**:

```javascript
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { CodexProError } from "./guard.js";
import { redactSensitiveText } from "./redact.js";

const MAX_EXECUTABLE_CHARS = 1_024;
const MAX_CWD_CHARS = 2_048;
const MAX_ARG_CHARS = 1_024;
const MAX_ARG_COUNT = 64;
const MAX_TOTAL_ARG_CHARS = 8_192;
const APPROVAL_TIMEOUT_MS = 120_000;
const SECRET_ENV_NAME = /(token|secret|password|passwd|api[_-]?key|private[_-]?key|credential|authorization)/i;

function trimOutput(value, maxBytes) {
    const buffer = Buffer.from(value, "utf8");
    if (buffer.byteLength <= maxBytes)
        return { value, truncated: false };
    const sliced = buffer.subarray(0, maxBytes).toString("utf8");
    return { value: `${sliced}\n...[output truncated to ${maxBytes} bytes]`, truncated: true };
}

function assertHostMode(config) {
    if (config.hostExecMode === "off") {
        throw new CodexProError("Host execution is disabled. Start CodexPro with CODEXPRO_HOST_EXEC_MODE=on-request or full-access to enable it.");
    }
}

function normalizeExecutable(value) {
    const executable = String(value ?? "").trim();
    if (!executable)
        throw new CodexProError("executable is required.");
    if (executable.length > MAX_EXECUTABLE_CHARS)
        throw new CodexProError(`executable exceeds ${MAX_EXECUTABLE_CHARS} characters.`);
    if (executable.includes("\0"))
        throw new CodexProError("executable contains a NUL byte.");
    if (!path.isAbsolute(executable) && !path.win32.isAbsolute(executable)) {
        throw new CodexProError("host execution requires an absolute executable path. Resolve the program first, then retry with its full path.");
    }
    const resolved = path.resolve(executable);
    if (!fs.existsSync(resolved))
        throw new CodexProError(`Host executable does not exist: ${resolved}`);
    const stat = fs.statSync(resolved);
    if (!stat.isFile())
        throw new CodexProError(`Host executable is not a file: ${resolved}`);
    return resolved;
}

function normalizeArgs(value) {
    const args = Array.isArray(value) ? value.map((item) => String(item)) : [];
    if (args.length > MAX_ARG_COUNT)
        throw new CodexProError(`host execution accepts at most ${MAX_ARG_COUNT} arguments.`);
    let total = 0;
    for (const arg of args) {
        if (arg.includes("\0"))
            throw new CodexProError("host execution arguments may not contain NUL bytes.");
        if (arg.length > MAX_ARG_CHARS)
            throw new CodexProError(`one host execution argument exceeds ${MAX_ARG_CHARS} characters.`);
        total += arg.length;
    }
    if (total > MAX_TOTAL_ARG_CHARS)
        throw new CodexProError(`host execution arguments exceed ${MAX_TOTAL_ARG_CHARS} total characters.`);
    return args;
}

function normalizeCwd(workspace, value) {
    const raw = String(value ?? "").trim();
    if (raw.length > MAX_CWD_CHARS)
        throw new CodexProError(`cwd exceeds ${MAX_CWD_CHARS} characters.`);
    const resolved = raw ? path.resolve(workspace.root, raw) : workspace.root;
    if (!fs.existsSync(resolved))
        throw new CodexProError(`Host working directory does not exist: ${resolved}`);
    if (!fs.statSync(resolved).isDirectory())
        throw new CodexProError(`Host working directory is not a directory: ${resolved}`);
    return resolved;
}

function filteredHostEnv() {
    const env = {};
    for (const [key, value] of Object.entries(process.env)) {
        if (value === undefined || SECRET_ENV_NAME.test(key))
            continue;
        env[key] = value;
    }
    return env;
}

function requestDigest(request) {
    return createHash("sha256").update(JSON.stringify(request)).digest("hex");
}

function approvalMessage(request, digest) {
    const argsJson = JSON.stringify(request.args, null, 2);
    return [
        "CodexPro requests execution outside the Codex workspace sandbox.",
        "",
        `Action: ${request.kind}`,
        `Executable: ${request.executable}`,
        `Arguments: ${argsJson}`,
        `Working directory: ${request.cwd}`,
        "Environment: inherited with secret-like variable names removed",
        "",
        `Request SHA-256: ${digest}`,
        "",
        "Approve this exact request once?"
    ].join("\n");
}

function powershellApprovalInvocation(message) {
    if (process.platform !== "win32") {
        throw new CodexProError("Local host-execution approval is currently implemented only for Windows.");
    }
    const systemRoot = process.env.SystemRoot || process.env.WINDIR || "C:\\Windows";
    const powershell = path.join(systemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
    if (!fs.existsSync(powershell))
        throw new CodexProError(`Windows PowerShell is unavailable for local approval: ${powershell}`);
    const messageBase64 = Buffer.from(message, "utf8").toString("base64");
    const script = [
        "$ErrorActionPreference='Stop'",
        "Add-Type -AssemblyName PresentationFramework",
        `$m=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${messageBase64}'))`,
        "$r=[System.Windows.MessageBox]::Show($m,'CodexPro Full Access Request',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)",
        "if ($r -eq [System.Windows.MessageBoxResult]::Yes) { exit 0 }",
        "exit 13"
    ].join("; ");
    const encoded = Buffer.from(script, "utf16le").toString("base64");
    return { executable: powershell, args: ["-NoLogo", "-NoProfile", "-STA", "-EncodedCommand", encoded] };
}

function requestLocalApproval(request) {
    const digest = requestDigest(request);
    if (request.mode === "full-access")
        return Promise.resolve({ approved: true, digest, approval: "full-access" });
    const message = approvalMessage(request, digest);
    const invocation = powershellApprovalInvocation(message);
    return new Promise((resolve, reject) => {
        const child = spawn(invocation.executable, invocation.args, {
            stdio: "ignore",
            windowsHide: false,
            env: filteredHostEnv()
        });
        let settled = false;
        const finish = (value) => {
            if (settled)
                return;
            settled = true;
            clearTimeout(timer);
            resolve(value);
        };
        const timer = setTimeout(() => {
            try {
                child.kill();
            }
            catch {
                // Best effort only.
            }
            finish({ approved: false, digest, approval: "timeout" });
        }, APPROVAL_TIMEOUT_MS);
        timer.unref();
        child.once("error", (error) => {
            if (settled)
                return;
            settled = true;
            clearTimeout(timer);
            reject(new CodexProError(`Could not display local host-execution approval: ${error instanceof Error ? error.message : String(error)}`));
        });
        child.once("close", (code) => {
            finish({
                approved: code === 0,
                digest,
                approval: code === 0 ? "approved-once" : "denied"
            });
        });
    });
}

function normalizedRequest(config, workspace, kind, executable, args, cwd) {
    assertHostMode(config);
    return {
        kind,
        mode: config.hostExecMode,
        executable: normalizeExecutable(executable),
        args: normalizeArgs(args),
        cwd: normalizeCwd(workspace, cwd)
    };
}

async function approveOrThrow(request) {
    const approval = await requestLocalApproval(request);
    if (!approval.approved) {
        throw new CodexProError(`Host execution was not approved locally (${approval.approval}). Request SHA-256: ${approval.digest}`);
    }
    return approval;
}

export async function runHostExec(config, workspace, executable, args = [], options = {}) {
    const request = normalizedRequest(config, workspace, "host_exec", executable, args, options.cwd);
    const approval = await approveOrThrow(request);
    const timeoutMs = Math.max(1_000, Math.min(options.timeoutMs ?? 30_000, 180_000));
    const started = Date.now();
    return new Promise((resolve, reject) => {
        const child = spawn(request.executable, request.args, {
            cwd: request.cwd,
            env: filteredHostEnv(),
            stdio: ["ignore", "pipe", "pipe"],
            shell: false,
            windowsHide: false
        });
        let stdout = "";
        let stderr = "";
        let killedByTimeout = false;
        const timer = setTimeout(() => {
            killedByTimeout = true;
            try {
                child.kill();
            }
            catch {
                // Best effort only.
            }
        }, timeoutMs);
        timer.unref();
        child.stdout.on("data", (chunk) => {
            stdout += String(chunk);
            if (Buffer.byteLength(stdout, "utf8") > config.maxOutputBytes * 2)
                child.kill();
        });
        child.stderr.on("data", (chunk) => {
            stderr += String(chunk);
            if (Buffer.byteLength(stderr, "utf8") > config.maxOutputBytes * 2)
                child.kill();
        });
        child.once("error", reject);
        child.once("close", (exitCode, signal) => {
            clearTimeout(timer);
            if (killedByTimeout)
                stderr += `\n[codexpro] Host command timed out after ${timeoutMs} ms.`;
            const out = trimOutput(redactSensitiveText(stdout), config.maxOutputBytes);
            const err = trimOutput(redactSensitiveText(stderr), config.maxOutputBytes);
            resolve({
                executable: request.executable,
                args: request.args,
                cwd: request.cwd,
                exitCode,
                signal,
                durationMs: Date.now() - started,
                stdout: out.value,
                stderr: err.value,
                truncated: out.truncated || err.truncated,
                approval: approval.approval,
                requestSha256: approval.digest
            });
        });
    });
}

export async function openHostApp(config, workspace, executable, args = [], options = {}) {
    const request = normalizedRequest(config, workspace, "open_app", executable, args, options.cwd);
    const approval = await approveOrThrow(request);
    return new Promise((resolve, reject) => {
        const child = spawn(request.executable, request.args, {
            cwd: request.cwd,
            env: filteredHostEnv(),
            stdio: "ignore",
            shell: false,
            detached: true,
            windowsHide: false
        });
        child.once("error", reject);
        child.once("spawn", () => {
            const pid = child.pid ?? null;
            child.unref();
            resolve({
                executable: request.executable,
                args: request.args,
                cwd: request.cwd,
                launched: true,
                pid,
                approval: approval.approval,
                requestSha256: approval.digest
            });
        });
    });
}
```

Reference SHA-256:

```text
E95D7A02D55C2A0DD7CF9427B030C95D15B0E794A6F92E2A9B764C7C265E005F
```

---

## 14. Patch `dist/config.js` for host execution

These edits target **CodexPro 0.29.0**. If an anchor is missing or appears more than once, stop instead of guessing against another build.

### 14.1 Add the mode parser

Immediately after `bashSandboxFrom(...)`, add:

```javascript
function hostExecModeFrom(value) {
    if (!value || value === "off")
        return "off";
    if (value === "on-request" || value === "full-access")
        return value;
    throw new Error("CODEXPRO_HOST_EXEC_MODE must be off, on-request, or full-access.");
}
```

### 14.2 Parse `--host-exec`

Immediately after:

```javascript
const bashArg = typeof args.bash === "string" ? args.bash : undefined;
```

add:

```javascript
const hostExecArg = typeof args["host-exec"] === "string" ? args["host-exec"] : undefined;
```

### 14.3 Expose the runtime value

Immediately after:

```javascript
bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX),
```

add:

```javascript
hostExecMode: hostExecModeFrom(hostExecArg ?? process.env.CODEXPRO_HOST_EXEC_MODE),
```

Reference final `config.js` SHA-256:

```text
28A70D25251954159E6028090845ABA518C49515B0778894D63CBF68E74058BD
```

---

## 15. Patch `dist/server.js` for `host_exec` and `open_app`

These edits also target CodexPro `0.29.0`.

### 15.1 Import host operations

Immediately after:

```javascript
import { runBash } from "./bashOps.js";
```

add:

```javascript
import { runHostExec, openHostApp } from "./hostOps.js";
```

### 15.2 Add tools to `FULL_TOOL_NAMES`

After `"bash",` add:

```javascript
"host_exec",
"open_app",
```

### 15.3 Hide host tools in connection-test mode

In `CONNECTION_TEST_HIDDEN_TOOLS`, after `"bash",` add:

```javascript
"host_exec",
"open_app",
```

### 15.4 Remove host tools when host mode is off

Immediately after the `config.bashMode === "off"` handling inside `toolNamesForMode(config)`, add:

```javascript
if (config.hostExecMode === "off") {
    for (const hostTool of ["host_exec", "open_app"]) {
        const toolIndex = names.indexOf(hostTool);
        if (toolIndex !== -1)
            names.splice(toolIndex, 1);
    }
}
```

### 15.5 Guard registration

Immediately after:

```javascript
if (name === "bash" && config.bashMode === "off")
    return false;
```

add:

```javascript
if ((name === "host_exec" || name === "open_app") && config.hostExecMode === "off")
    return false;
```

### 15.6 Expose the host mode through the supertool

In the `list_actions` structured response add:

```javascript
host_exec_mode: config.hostExecMode,
```

between `bash_mode` and `write_mode`.

### 15.7 Expose the host mode through `server_config`

In `safeConfig`, add:

```javascript
hostExecMode: config.hostExecMode,
```

### 15.8 Add the self-test check

After the Bash-mode check add:

```javascript
check("host exec mode", config.hostExecMode === "full-access" ? "warn" : "pass", config.hostExecMode);
```

The warning in full-access mode is intentional because this is a security-sensitive mode.

### 15.9 Register the two tools

Insert this exact block **after the existing `bash` registration and before `git_status`**:

```javascript
    registerCodexTool(config, server, "host_exec", {
        title: "Host Exec",
        description: "Run one executable directly as the local Windows user, outside the Codex workspace sandbox. Requires an absolute executable path. In on-request mode, the exact executable, argv, cwd, and request hash must be approved in a local Windows dialog before execution. No shell command string or shell expansion is used.",
        inputSchema: {
            workspace_id: z.string().optional().describe("Workspace id from open_workspace. Omit to use default workspace."),
            executable: z.string().min(1).max(1024).describe("Absolute path to the executable to run."),
            args: z.array(z.string().max(1024)).max(64).optional().describe("Argument vector passed directly to the executable. No shell parsing is performed."),
            cwd: z.string().max(2048).optional().describe("Working directory. Relative paths resolve from the workspace root; absolute paths are allowed and are shown in the local approval dialog."),
            timeout_ms: z.number().int().min(1000).max(180000).optional().describe("Timeout in milliseconds. Default: 30000.")
        },
        annotations: BASH_ANNOTATIONS,
        _meta: {
            "openai/toolInvocation/invoking": "Waiting for local host-execution approval...",
            "openai/toolInvocation/invoked": "Host command finished"
        }
    }, async (args) => {
        const workspace = workspaces.getWorkspace(args.workspace_id);
        const result = await runHostExec(config, workspace, String(args.executable ?? ""), args.args ?? [], {
            cwd: args.cwd,
            timeoutMs: args.timeout_ms
        });
        const text = [
            "# Host Exec",
            "",
            `Executable: ${result.executable}`,
            `CWD: ${result.cwd}`,
            `Approval: ${result.approval}`,
            `Request SHA-256: ${result.requestSha256}`,
            `Exit: ${result.exitCode}${result.signal ? ` (${result.signal})` : ""}`,
            `Duration: ${result.durationMs} ms`,
            "",
            "## stdout",
            "",
            result.stdout || "",
            "",
            "## stderr",
            "",
            result.stderr || ""
        ].join("\n");
        return textResult(text, { workspace_id: workspace.id, root: workspace.root, ...result });
    });
    registerCodexTool(config, server, "open_app", {
        title: "Open App",
        description: "Launch one local GUI application directly as the Windows user, outside the Codex workspace sandbox. Requires an absolute executable path. In on-request mode, the exact launch request must be approved in a local Windows dialog. The application is detached after a successful spawn.",
        inputSchema: {
            workspace_id: z.string().optional().describe("Workspace id from open_workspace. Omit to use default workspace."),
            executable: z.string().min(1).max(1024).describe("Absolute path to the application executable."),
            args: z.array(z.string().max(1024)).max(64).optional().describe("Argument vector passed directly to the application. No shell parsing is performed."),
            cwd: z.string().max(2048).optional().describe("Working directory. Relative paths resolve from the workspace root; absolute paths are allowed and are shown in the local approval dialog.")
        },
        annotations: BASH_ANNOTATIONS,
        _meta: {
            "openai/toolInvocation/invoking": "Waiting for local app-launch approval...",
            "openai/toolInvocation/invoked": "Application launch requested"
        }
    }, async (args) => {
        const workspace = workspaces.getWorkspace(args.workspace_id);
        const result = await openHostApp(config, workspace, String(args.executable ?? ""), args.args ?? [], {
            cwd: args.cwd
        });
        const text = [
            "# Open App",
            "",
            `Executable: ${result.executable}`,
            `CWD: ${result.cwd}`,
            `Approval: ${result.approval}`,
            `Request SHA-256: ${result.requestSha256}`,
            `Launched: ${result.launched}`,
            `PID: ${result.pid ?? "unknown"}`
        ].join("\n");
        return textResult(text, { workspace_id: workspace.id, root: workspace.root, ...result });
    });
```

Reference final `server.js` SHA-256:

```text
6549371A044C58C45EE02FE2508D0CBD4D6A80E8E2F95BD3AAFD060FAD1B67BD
```

---

## 16. Canonical launcher

Save the following **verbatim** as:

```text
$HOME\.codexpro\Start-CodexPro.ps1
```

```powershell
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = (Get-Location).Path,

    [ValidateSet('off', 'on-request', 'full-access')]
    [string]$HostExecMode = 'full-access'
)

$ErrorActionPreference = 'Stop'

$GitBashDir = 'C:\Program Files\Git\bin'
$CodexProDir = Join-Path $HOME '.codexpro'
$TokenFile = Join-Path $CodexProDir 'http-token'
$InstalledCodexProDir = Join-Path $HOME '.bun\install\global\node_modules\codexpro'
$BashOpsFile = Join-Path $InstalledCodexProDir 'dist\bashOps.js'
$ConfigFile = Join-Path $InstalledCodexProDir 'dist\config.js'
$ServerFile = Join-Path $InstalledCodexProDir 'dist\server.js'
$HostOpsFile = Join-Path $InstalledCodexProDir 'dist\hostOps.js'
$PatchInstaller = Join-Path $CodexProDir 'Install-CodexProWorkspaceSandbox.ps1'

$Hostname = 'codexpro.futech-co.ir'
$TunnelName = 'codexpro-local'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Workspace does not exist: $Root"
}

$GitBash = Join-Path $GitBashDir 'bash.exe'

if (-not (Test-Path -LiteralPath $GitBash -PathType Leaf)) {
    throw "Git Bash not found: $GitBash"
}

if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "CodexPro token file not found: $TokenFile"
}

if (-not (Test-Path -LiteralPath $PatchInstaller -PathType Leaf)) {
    throw "CodexPro sandbox patch installer not found: $PatchInstaller"
}

& $PatchInstaller -PackageDir $InstalledCodexProDir

$PatchedFiles = @(
    @{ Path = $BashOpsFile; Marker = 'function sandboxInvocation' }
    @{ Path = $BashOpsFile; Marker = 'workspace.root,' + [Environment]::NewLine + '            "--",' }
    @{ Path = $BashOpsFile; Marker = 'CODEXPRO_BASH_EXECUTABLE' }
    @{ Path = $ConfigFile; Marker = 'CODEXPRO_BASH_SANDBOX' }
    @{ Path = $ConfigFile; Marker = 'CODEXPRO_HOST_EXEC_MODE' }
    @{ Path = $ServerFile; Marker = 'registerCodexTool(config, server, "host_exec"' }
    @{ Path = $HostOpsFile; Marker = 'function requestLocalApproval' }
)

foreach ($PatchedFile in $PatchedFiles) {
    if (-not (Test-Path -LiteralPath $PatchedFile.Path -PathType Leaf)) {
        throw "Patched CodexPro file not found: $($PatchedFile.Path)"
    }

    if (-not [IO.File]::ReadAllText($PatchedFile.Path).Contains($PatchedFile.Marker)) {
        throw "Required CodexPro sandbox/host patch is missing. Refusing to start: $($PatchedFile.Path)"
    }
}

$CurrentPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
$PreviousBashSandbox = [Environment]::GetEnvironmentVariable('CODEXPRO_BASH_SANDBOX', 'Process')
$PreviousBashExecutable = [Environment]::GetEnvironmentVariable('CODEXPRO_BASH_EXECUTABLE', 'Process')
$PreviousHostExecMode = [Environment]::GetEnvironmentVariable('CODEXPRO_HOST_EXEC_MODE', 'Process')
[Environment]::SetEnvironmentVariable(
    'Path',
    "$GitBashDir;$CurrentPath",
    'Process'
)
[Environment]::SetEnvironmentVariable('CODEXPRO_BASH_SANDBOX', 'workspace', 'Process')
[Environment]::SetEnvironmentVariable('CODEXPRO_BASH_EXECUTABLE', $GitBash, 'Process')
[Environment]::SetEnvironmentVariable('CODEXPRO_HOST_EXEC_MODE', $HostExecMode, 'Process')

$ResolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$ResolvedBash = (Get-Command bash -ErrorAction Stop).Source
$ResolvedCodex = (Get-Command codex -ErrorAction Stop).Source
$HostExecDescription = switch ($HostExecMode) {
    'full-access' { 'full-access (no per-request approval)' }
    'on-request' { 'on-request (local approval)' }
    default { 'off' }
}

Write-Host "CodexPro workspace: $ResolvedRoot"
Write-Host "MCP hostname:       $Hostname"
Write-Host "Bash:               $ResolvedBash"
Write-Host "Codex sandbox:      $ResolvedCodex"
Write-Host "Permission profile: :workspace"
Write-Host "Host execution:     $HostExecDescription"

$McpToken = [IO.File]::ReadAllText($TokenFile).Trim()

if ([string]::IsNullOrWhiteSpace($McpToken) -or $McpToken -match '\s') {
    throw "CodexPro token file is empty or invalid: $TokenFile"
}
$CodexProArgs = @(
    'stable'
    '--root'
    $ResolvedRoot
    '--hostname'
    $Hostname
    '--tunnel-name'
    $TunnelName
    '--token'
    $McpToken
    '--agent'
    '--tool-mode'
    'full'
    '--write'
    'workspace'
    '--bash'
    'full'
    '--log-requests'
)

try {
    & codexpro @CodexProArgs
}
finally {
    [Environment]::SetEnvironmentVariable(
        'CODEXPRO_BASH_EXECUTABLE',
        $PreviousBashExecutable,
        'Process'
    )
    [Environment]::SetEnvironmentVariable(
        'CODEXPRO_BASH_SANDBOX',
        $PreviousBashSandbox,
        'Process'
    )
    [Environment]::SetEnvironmentVariable(
        'CODEXPRO_HOST_EXEC_MODE',
        $PreviousHostExecMode,
        'Process'
    )
    [Environment]::SetEnvironmentVariable(
        'Path',
        $CurrentPath,
        'Process'
    )
}
```

Reference SHA-256:

```text
34E495DCA2E3147633C191E95FD997EE8E211959D46EFA1DAB3A7DA2ED89A0DB
```

### Deployment-specific changes in the launcher

Normally change only:

```powershell
$Hostname = '<PUBLIC_HOSTNAME>'
$TunnelName = '<CLOUDFLARE_TUNNEL_NAME>'
```

If Git Bash is not installed at the standard location, also change `$GitBashDir`.

Default host mode is intentionally:

```powershell
[string]$HostExecMode = 'full-access'
```

One-off safer session:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -Root <PATH> -HostExecMode on-request
```

Disable host execution:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -Root <PATH> -HostExecMode off
```

---
## 17. Add `cpx` to the PowerShell 7 profile

Discover the actual profile file:

```powershell
$PROFILE
```

The current machine resolves it to:

```text
D:\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Add this exact function:

```powershell
function cpx {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Root = (Get-Location).Path
    )

    $Launcher = Join-Path (Join-Path $HOME '.codexpro') 'Start-CodexPro.ps1'
    & $Launcher -Root $Root
}
```

Reload the profile or open a new PowerShell 7 session:

```powershell
. $PROFILE
```

Usage:

```powershell
cpx
```

uses the current directory as the workspace.

```powershell
cpx C:\Users\aminn
```

opens `C:\Users\aminn` as the workspace.

For an alternate host mode, call the launcher directly because the current `cpx` wrapper intentionally only exposes the root parameter:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -Root C:\Users\aminn -HostExecMode on-request
```

---

# Part III — Start and connect ChatGPT

## 18. Start the canonical server

For the PC-wide reference workspace:

```powershell
cpx C:\Users\aminn
```

For project-specific work, prefer a narrower root:

```powershell
cpx D:\Projects\ExampleProject
```

Expected launcher output includes:

```text
CodexPro workspace: <resolved root>
MCP hostname:       <hostname>
Bash:               C:\Program Files\Git\bin\bash.exe
Codex sandbox:      <resolved codex.exe>
Permission profile: :workspace
Host execution:     full-access (no per-request approval)
```

The local MCP should report:

```text
HTTP MCP listening on http://127.0.0.1:8787/mcp
```

The control panel should report the equivalent of:

```text
Mode       Agent  tools=full  write=workspace  bash=full
Connector  public HTTPS
```

---

## 19. Create the ChatGPT connector

Create a ChatGPT developer/plugin connector with:

| Field | Canonical value |
|---|---|
| Name | `AminPC` |
| Server URL | Use the **exact URL copied by CodexPro at runtime** |
| Authentication | `None` |
| Permissions | Allow the actions required for the agent workflow |

The generated CodexPro server URL contains the MCP token in the URL. Therefore:

- treat the entire generated URL as a secret;
- never commit it;
- never paste it into this runbook;
- do not put the token value in Git.

---

# Part IV — Verification

## 20. Canonical hash verification

```powershell
$Base = "$HOME\.bun\install\global\node_modules\codexpro\dist"

Get-FileHash "$HOME\.codexpro\Install-CodexProWorkspaceSandbox.ps1" -Algorithm SHA256
Get-FileHash "$HOME\.codexpro\Start-CodexPro.ps1" -Algorithm SHA256
Get-FileHash "$Base\bashOps.js" -Algorithm SHA256
Get-FileHash "$Base\config.js" -Algorithm SHA256
Get-FileHash "$Base\server.js" -Algorithm SHA256
Get-FileHash "$Base\hostOps.js" -Algorithm SHA256
```

Reference hashes for the **current byte-for-byte snapshot**:

> Line-ending note: the three files embedded verbatim in this runbook (`Install-CodexProWorkspaceSandbox.ps1`, `Start-CodexPro.ps1`, and `hostOps.js`) are LF-only and their hashes should match exactly when copied as shown. The upstream/generated `bashOps.js` and `config.js` are CRLF in the current package, while `server.js` is currently mixed-line-ending because targeted edits were applied in place. For a future rebuild, use the `dist` hashes as forensic references; semantic verification and tool behavior are authoritative if an editor normalizes line endings.

| File | SHA-256 |
|---|---|
| `Install-CodexProWorkspaceSandbox.ps1` | `97C3BADBA08818BF9CA92BB56158542092F128710A5953664DB3334D13CBF38F` |
| `Start-CodexPro.ps1` | `34E495DCA2E3147633C191E95FD997EE8E211959D46EFA1DAB3A7DA2ED89A0DB` |
| `bashOps.js` | `3EB700D4C37A6B7470D29C9B2DC486D39DC69D7B9617154C244362381C2039AF` |
| `config.js` | `28A70D25251954159E6028090845ABA518C49515B0778894D63CBF68E74058BD` |
| `server.js` | `6549371A044C58C45EE02FE2508D0CBD4D6A80E8E2F95BD3AAFD060FAD1B67BD` |
| `hostOps.js` | `E95D7A02D55C2A0DD7CF9427B030C95D15B0E794A6F92E2A9B764C7C265E005F` |

These hashes are valid only for the exact reference build and exact text serialization in this runbook.

---

## 21. Verify `server_config`

After restarting with the canonical launcher, important values should be:

```text
host                 = 127.0.0.1
port                 = 8787
authEnabled          = true
bashMode             = full
bashTranscript       = compact
hostExecMode         = full-access
writeMode            = workspace
toolMode             = full
inheritEnv           = false
registeredToolCount  = 28
```

Expected custom tools:

```text
host_exec
open_app
```

Note: a process that was started before the launcher was switched from `on-request` to `full-access` will continue reporting `on-request` until it is restarted.

---

## 22. Verify workspace containment

With workspace root:

```text
C:\Users\aminn
```

attempting a Bash/tool request with:

```text
cwd = ..
```

must be rejected with an equivalent of:

```text
Path escapes workspace root: ..
```

This proves that normal workspace execution cannot escape the configured root.

---

## 23. Verify sandbox Bash

A normal:

```text
pwd
```

from the reference workspace should resolve to:

```text
/c/Users/aminn
```

The Bash path must use:

```text
codex sandbox -P :workspace
```

with the configured Git Bash executable.

---

## 24. Verify restricted Windows environment

The sandboxed Bash environment should retain the restricted base environment and add:

```text
USERPROFILE
TEMP
```

It must not require:

```text
CODEXPRO_INHERIT_ENV=1
```

The environment patch intentionally fails closed if `USERPROFILE` or `TEMP` is unavailable.

---

## 25. Verify Full Access host execution

After starting the final launcher with default `full-access`, invoke `host_exec` with:

```text
C:\Windows\System32\whoami.exe
```

Expected:

- execution succeeds;
- the output identifies the actual Windows user;
- result `approval` is `full-access`;
- **no per-request approval popup appears**.

Reference user output:

```text
amin-legion\aminn
```

Then verify `open_app` using a harmless GUI executable.

---

## 26. Verify the Cloudflare tunnel

Local health endpoint:

```text
http://127.0.0.1:8787/healthz
```

must return HTTP 200.

The configured public hostname must route to the same service.

The validated deployment can run Cloudflare Tunnel over HTTP/2 when UDP/QUIC is unavailable. QUIC failure alone is not a blocker if HTTP/2 tunnel connections register successfully.

---

# Part V — Updates and recovery

## 27. CodexPro update policy

Do **not** blindly update the globally installed CodexPro package. This setup modifies package files under:

```text
~\.bun\install\global\node_modules\codexpro\dist
```

A package reinstall/update can overwrite those modifications.

Before an update:

1. record the current CodexPro version;
2. back up `~\.codexpro`;
3. back up the patched `dist` files;
4. install the target upstream version;
5. compare its implementation with the patch anchors in this document;
6. re-implement/revalidate the custom changes;
7. run every acceptance test in this runbook;
8. only then switch the production connector to the updated process.

For an emergency deterministic rebuild:

```powershell
bun add -g codexpro@0.29.0
```

then reapply this runbook.

---

## 28. Backups

The sandbox installer creates transactional backups under:

```text
$HOME\.codexpro\backups\codexpro-sandbox-<timestamp>
```

The current machine also has launcher-history backups such as:

```text
Start-CodexPro.ps1.pre-host-exec.bak
Start-CodexPro.ps1.pre-full-access.bak
```

Those historical files are recovery artifacts, not required on a clean installation.

---

## 29. Change or disable host access without deleting the patch

Per-request approval:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -HostExecMode on-request
```

Disable host execution:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -HostExecMode off
```

Canonical current behavior:

```powershell
& "$HOME\.codexpro\Start-CodexPro.ps1" -HostExecMode full-access
```

---

## 30. Remove custom host tools completely

If the host extension must be removed:

1. stop CodexPro;
2. restore/reinstall the pinned upstream package;
3. reapply only the sandbox/environment installer if that behavior is still wanted;
4. keep host execution disabled;
5. restart and verify `host_exec`/`open_app` are absent.

Do not delete only `hostOps.js` while leaving registration markers in `server.js`; the canonical launcher intentionally refuses to start an inconsistent installation.

---

# Part VI — Operational notes

## 31. Workspace-root policy

The general PC connector currently uses:

```text
C:\Users\aminn
```

For project work, a narrower root is safer and avoids unnecessary scans:

```powershell
cpx D:\Projects\MyProject
```

The `bash` path is workspace-bounded. `host_exec` is deliberately a separate privilege path and is not constrained by the Bash workspace sandbox.

---

## 32. Avoid recursive scans of the whole user profile

A recursive scan of `C:\Users\aminn` can touch phone/cloud-backed placeholder folders and trigger automatic downloads. This was observed with Windows CrossDevice content.

Operational rule:

- avoid recursive scans of the full home directory unless necessary;
- open the exact project/application directory;
- prefer targeted `tree`, `search`, and `read` calls.

---

## 33. Security model summary

```text
Bash:
  full command policy
  +
  Codex workspace sandbox
  +
  restricted environment

Host execution:
  direct executable + argv
  shell: false
  filtered environment
  default full-access
  no UAC bypass

Remote exposure:
  localhost MCP
  +
  bearer token
  +
  Cloudflare named tunnel
```

The most sensitive artifact in full-access mode is the MCP token / token-bearing connector URL.

---

# Appendix A — Canonical hashes

```text
CodexPro package: 0.29.0

Install-CodexProWorkspaceSandbox.ps1
97C3BADBA08818BF9CA92BB56158542092F128710A5953664DB3334D13CBF38F

Start-CodexPro.ps1
34E495DCA2E3147633C191E95FD997EE8E211959D46EFA1DAB3A7DA2ED89A0DB

dist/bashOps.js
3EB700D4C37A6B7470D29C9B2DC486D39DC69D7B9617154C244362381C2039AF

dist/config.js
28A70D25251954159E6028090845ABA518C49515B0778894D63CBF68E74058BD

dist/server.js
6549371A044C58C45EE02FE2508D0CBD4D6A80E8E2F95BD3AAFD060FAD1B67BD

dist/hostOps.js
E95D7A02D55C2A0DD7CF9427B030C95D15B0E794A6F92E2A9B764C7C265E005F
```

# Appendix B — Acceptance checklist

A rebuilt installation is accepted only when all are true:

- [ ] `codexpro --version` reports `0.29.0`.
- [ ] the named Cloudflare tunnel resolves the configured hostname.
- [ ] local `/healthz` returns HTTP 200.
- [ ] MCP token exists and is not committed.
- [ ] sandbox installer is idempotent.
- [ ] the three verbatim canonical files (sandbox installer, launcher, `hostOps.js`) match their hashes; `dist` semantic markers/behavior match even if editor line endings alter forensic hashes.
- [ ] `server_config` reports `toolMode=full`.
- [ ] `server_config` reports `writeMode=workspace`.
- [ ] `server_config` reports `bashMode=full`.
- [ ] `server_config` reports `hostExecMode=full-access` after restart.
- [ ] `server_config` reports `inheritEnv=false`.
- [ ] 28 tools are registered in full mode.
- [ ] `host_exec` and `open_app` are registered.
- [ ] `cwd=..` is rejected by the workspace boundary.
- [ ] `pwd` resolves to the selected workspace.
- [ ] sandbox works without full host environment inheritance.
- [ ] `USERPROFILE` and `TEMP` are available to sandboxed Windows Codex execution.
- [ ] `whoami.exe` succeeds through `host_exec` without an approval popup in full-access mode.
- [ ] a harmless GUI application launches through `open_app`.
- [ ] ChatGPT connector `AminPC` can perform a read -> edit/write -> verification multi-step loop.
- [ ] no connector token or token-bearing URL is stored in the repository.

---

## Final canonical launch

```powershell
cpx C:\Users\aminn
```

The resulting configuration is the reference AminPC/CodexPro setup documented here.
