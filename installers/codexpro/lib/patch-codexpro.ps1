[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageDir,

    [string]$BackupRoot = (Join-Path $HOME '.codexpro\backups'),

    [string]$HostOpsSource = (Join-Path (Split-Path -Parent $PSScriptRoot) 'payload\hostOps.js'),

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ExpectedVersion = '0.29.0'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Normalize-BlockForFile {
    param(
        [Parameter(Mandatory)][string]$Block,
        [Parameter(Mandatory)][string]$FileText
    )
    $newline = if ($FileText.Contains("`r`n")) { "`r`n" } else { "`n" }
    return $Block.Replace("`r`n", "`n").Replace("`n", $newline)
}

function Replace-ExactlyOnce {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$OldText,
        [Parameter(Mandatory)][string]$NewText,
        [Parameter(Mandatory)][string]$Label
    )
    $first = $Text.IndexOf($OldText, [StringComparison]::Ordinal)
    if ($first -lt 0) {
        throw "Unsupported CodexPro build; expected block was not found: $Label"
    }
    $second = $Text.IndexOf($OldText, $first + $OldText.Length, [StringComparison]::Ordinal)
    if ($second -ge 0) {
        throw "Unsupported CodexPro build; expected block is not unique: $Label"
    }
    return $Text.Substring(0, $first) + $NewText + $Text.Substring($first + $OldText.Length)
}

function Replace-UnlessMarker {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Marker,
        [Parameter(Mandatory)][string]$OldText,
        [Parameter(Mandatory)][string]$NewText,
        [Parameter(Mandatory)][string]$Label
    )
    if ($Text.Contains($Marker)) {
        return $Text
    }
    $old = Normalize-BlockForFile $OldText $Text
    $new = Normalize-BlockForFile $NewText $Text
    return Replace-ExactlyOnce $Text $old $new $Label
}

$ResolvedPackageDir = (Resolve-Path -LiteralPath $PackageDir).Path
$PackageJsonPath = Join-Path $ResolvedPackageDir 'package.json'
if (-not (Test-Path -LiteralPath $PackageJsonPath -PathType Leaf)) {
    throw "CodexPro package.json not found: $PackageJsonPath"
}
$Package = Get-Content -LiteralPath $PackageJsonPath -Raw | ConvertFrom-Json
if ($Package.name -ne 'codexpro' -or $Package.version -ne $ExpectedVersion) {
    throw "This patch targets codexpro@$ExpectedVersion exactly. Found $($Package.name)@$($Package.version)."
}
if (-not (Test-Path -LiteralPath $HostOpsSource -PathType Leaf)) {
    throw "Host execution payload not found: $HostOpsSource"
}

$DistDir = Join-Path $ResolvedPackageDir 'dist'
$BashOpsFile = Join-Path $DistDir 'bashOps.js'
$ConfigFile = Join-Path $DistDir 'config.js'
$ServerFile = Join-Path $DistDir 'server.js'
$HostOpsFile = Join-Path $DistDir 'hostOps.js'
foreach ($Path in @($BashOpsFile, $ConfigFile, $ServerFile)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "CodexPro runtime file not found: $Path"
    }
}

$BashOps = [IO.File]::ReadAllText($BashOpsFile)
$Config = [IO.File]::ReadAllText($ConfigFile)
$Server = [IO.File]::ReadAllText($ServerFile)
$HostOpsPayload = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HostOpsSource).Path)

$OldMakeEnv = @'
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
'@
$NewMakeEnv = @'
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
'@
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
$OldBashSpawn = @'
        const child = spawn(bashExecutable(), ["-lc", command], {
            cwd,
            env: makeEnv(config),
'@
$NewBashSpawn = @'
        const invocation = sandboxInvocation(config, workspace, cwd, command);
        const child = spawn(invocation.command, invocation.args, {
            cwd: invocation.cwd,
            env: makeEnv(config),
'@

$PatchedBash = Replace-UnlessMarker $BashOps 'env.USERPROFILE = userProfile;' $OldMakeEnv $NewMakeEnv 'Windows environment allowlist'
$PatchedBash = Replace-UnlessMarker $PatchedBash 'function sandboxInvocation(config, workspace, cwd, command)' $OldBashExecutable $NewBashExecutable 'workspace sandbox invocation'
$PatchedBash = Replace-UnlessMarker $PatchedBash 'const invocation = sandboxInvocation(config, workspace, cwd, command);' $OldBashSpawn $NewBashSpawn 'Bash sandbox spawn'

$BashSandboxFunction = @'
function bashSandboxFrom(value) {
    if (!value || value === "off")
        return "off";
    if (value === "workspace")
        return value;
    throw new Error("CODEXPRO_BASH_SANDBOX must be off or workspace.");
}
'@
$HostExecFunction = @'
function hostExecModeFrom(value) {
    if (!value || value === "off")
        return "off";
    if (value === "on-request" || value === "full-access")
        return value;
    throw new Error("CODEXPRO_HOST_EXEC_MODE must be off, on-request, or full-access.");
}
'@
$ConfigNewline = if ($Config.Contains("`r`n")) { "`r`n" } else { "`n" }
if (-not $Config.Contains('function bashSandboxFrom(value)')) {
    $Old = Normalize-BlockForFile "function codexSessionsFrom(value) {" $Config
    $New = Normalize-BlockForFile ($BashSandboxFunction + $ConfigNewline + $HostExecFunction + $ConfigNewline + "function codexSessionsFrom(value) {") $Config
    $PatchedConfig = Replace-ExactlyOnce $Config $Old $New 'sandbox/host configuration parsers'
}
elseif (-not $Config.Contains('function hostExecModeFrom(value)')) {
    $Old = Normalize-BlockForFile "function codexSessionsFrom(value) {" $Config
    $New = Normalize-BlockForFile ($HostExecFunction + $ConfigNewline + "function codexSessionsFrom(value) {") $Config
    $PatchedConfig = Replace-ExactlyOnce $Config $Old $New 'host execution configuration parser'
}
else {
    $PatchedConfig = $Config
}

$OldConfigArg = @'
    const bashArg = typeof args.bash === "string" ? args.bash : undefined;
    const bashTranscriptArg = typeof args["bash-transcript"] === "string" ? args["bash-transcript"] : undefined;
'@
$NewConfigArg = @'
    const bashArg = typeof args.bash === "string" ? args.bash : undefined;
    const hostExecArg = typeof args["host-exec"] === "string" ? args["host-exec"] : undefined;
    const bashTranscriptArg = typeof args["bash-transcript"] === "string" ? args["bash-transcript"] : undefined;
'@
$PatchedConfig = Replace-UnlessMarker $PatchedConfig 'const hostExecArg = typeof args["host-exec"]' $OldConfigArg $NewConfigArg 'host-exec CLI argument'

if (-not $PatchedConfig.Contains('bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX)')) {
    $Old = Normalize-BlockForFile '        bashMode: bashModeFrom(bashArg ?? process.env.CODEXPRO_BASH_MODE),' $PatchedConfig
    $New = Normalize-BlockForFile @'
        bashMode: bashModeFrom(bashArg ?? process.env.CODEXPRO_BASH_MODE),
        bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX),
'@ $PatchedConfig
    $PatchedConfig = Replace-ExactlyOnce $PatchedConfig $Old $New 'bash sandbox config property'
}
if (-not $PatchedConfig.Contains('hostExecMode: hostExecModeFrom(hostExecArg ?? process.env.CODEXPRO_HOST_EXEC_MODE)')) {
    $Old = Normalize-BlockForFile '        bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX),' $PatchedConfig
    $New = Normalize-BlockForFile @'
        bashSandbox: bashSandboxFrom(process.env.CODEXPRO_BASH_SANDBOX),
        hostExecMode: hostExecModeFrom(hostExecArg ?? process.env.CODEXPRO_HOST_EXEC_MODE),
'@ $PatchedConfig
    $PatchedConfig = Replace-ExactlyOnce $PatchedConfig $Old $New 'host execution config property'
}

$ServerImportOld = 'import { runBash } from "./bashOps.js";'
$ServerImportNew = @'
import { runBash } from "./bashOps.js";
import { runHostExec, openHostApp } from "./hostOps.js";
'@
$PatchedServer = Replace-UnlessMarker $Server 'from "./hostOps.js"' $ServerImportOld $ServerImportNew 'hostOps import'

# Add host tools at the Bash boundary using declaration-scoped blocks so partially
# patched files cannot satisfy a broad marker that happens to occur elsewhere.
$FullToolsOld = Normalize-BlockForFile @'
const FULL_TOOL_NAMES = [
    SUPERTOOL_NAME,
    "server_config",
    "codexpro_self_test",
    "codexpro_inventory",
    "load_skill",
    "list_workspaces",
    "open_current_workspace",
    "open_workspace",
    "workspace_snapshot",
    "inspect_workspace",
    "tree",
    "search",
    "read",
    "write",
    "edit",
    "apply_patch",
    "bash",
    "git_status",
'@ $PatchedServer
$FullToolsCurrent = Normalize-BlockForFile @'
const FULL_TOOL_NAMES = [
    SUPERTOOL_NAME,
    "server_config",
    "codexpro_self_test",
    "codexpro_inventory",
    "load_skill",
    "list_workspaces",
    "open_current_workspace",
    "open_workspace",
    "workspace_snapshot",
    "inspect_workspace",
    "tree",
    "search",
    "read",
    "write",
    "edit",
    "apply_patch",
    "bash",
    "host_exec",
    "open_app",
    "git_status",
'@ $PatchedServer
if (-not $PatchedServer.Contains($FullToolsCurrent)) {
    $PatchedServer = Replace-ExactlyOnce $PatchedServer $FullToolsOld $FullToolsCurrent 'full tool names'
}

$ConnectionHiddenOld = Normalize-BlockForFile @'
const CONNECTION_TEST_HIDDEN_TOOLS = new Set([
    SUPERTOOL_NAME,
    "codexpro_self_test",
    "write",
    "edit",
    "apply_patch",
    "bash",
    "export_pro_context",
'@ $PatchedServer
$ConnectionHiddenCurrent = Normalize-BlockForFile @'
const CONNECTION_TEST_HIDDEN_TOOLS = new Set([
    SUPERTOOL_NAME,
    "codexpro_self_test",
    "write",
    "edit",
    "apply_patch",
    "bash",
    "host_exec",
    "open_app",
    "export_pro_context",
'@ $PatchedServer
if (-not $PatchedServer.Contains($ConnectionHiddenCurrent)) {
    $PatchedServer = Replace-ExactlyOnce $PatchedServer $ConnectionHiddenOld $ConnectionHiddenCurrent 'connection-test hidden host tools'
}

$ToolNamesOld = @'
    if (config.bashMode === "off") {
        const bashIndex = names.indexOf("bash");
        if (bashIndex !== -1)
            names.splice(bashIndex, 1);
    }
    if (config.writeMode !== "workspace") {
'@
$ToolNamesNew = @'
    if (config.bashMode === "off") {
        const bashIndex = names.indexOf("bash");
        if (bashIndex !== -1)
            names.splice(bashIndex, 1);
    }
    if (config.hostExecMode === "off") {
        for (const hostTool of ["host_exec", "open_app"]) {
            const toolIndex = names.indexOf(hostTool);
            if (toolIndex !== -1)
                names.splice(toolIndex, 1);
        }
    }
    if (config.writeMode !== "workspace") {
'@
$PatchedServer = Replace-UnlessMarker $PatchedServer 'for (const hostTool of ["host_exec", "open_app"])' $ToolNamesOld $ToolNamesNew 'host tool mode filter'

$ShouldRegisterOld = @'
    if (name === "bash" && config.bashMode === "off")
        return false;
    if ((name === "write" || name === "edit" || name === "apply_patch") && config.writeMode !== "workspace")
'@
$ShouldRegisterNew = @'
    if (name === "bash" && config.bashMode === "off")
        return false;
    if ((name === "host_exec" || name === "open_app") && config.hostExecMode === "off")
        return false;
    if ((name === "write" || name === "edit" || name === "apply_patch") && config.writeMode !== "workspace")
'@
$PatchedServer = Replace-UnlessMarker $PatchedServer 'name === "host_exec" || name === "open_app"' $ShouldRegisterOld $ShouldRegisterNew 'host tool registration filter'

$SupertoolOld = @'
                tool_mode: config.toolMode,
                bash_mode: config.bashMode,
                write_mode: config.writeMode
'@
$SupertoolNew = @'
                tool_mode: config.toolMode,
                bash_mode: config.bashMode,
                host_exec_mode: config.hostExecMode,
                write_mode: config.writeMode
'@
$PatchedServer = Replace-UnlessMarker $PatchedServer 'host_exec_mode: config.hostExecMode' $SupertoolOld $SupertoolNew 'supertool host mode report'

$ServerConfigOld = @'
            bashMode: config.bashMode,
            bashTranscript: config.bashTranscript,
'@
$ServerConfigNew = @'
            bashMode: config.bashMode,
            bashTranscript: config.bashTranscript,
            hostExecMode: config.hostExecMode,
'@
$PatchedServer = Replace-UnlessMarker $PatchedServer 'hostExecMode: config.hostExecMode' $ServerConfigOld $ServerConfigNew 'server config host mode report'

$SelfTestOld = @'
        check("bash mode", config.bashMode === "full" ? "warn" : "pass", config.bashMode);
        check("http auth", "pass", config.authToken
'@
$SelfTestNew = @'
        check("bash mode", config.bashMode === "full" ? "warn" : "pass", config.bashMode);
        check("host exec mode", config.hostExecMode === "full-access" ? "warn" : "pass", config.hostExecMode);
        check("http auth", "pass", config.authToken
'@
$PatchedServer = Replace-UnlessMarker $PatchedServer 'check("host exec mode"' $SelfTestOld $SelfTestNew 'self-test host mode check'

$HostToolBlock = @'
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
'@
if (-not $PatchedServer.Contains('registerCodexTool(config, server, "host_exec"')) {
    $GitStatusAnchor = Normalize-BlockForFile '    registerCodexTool(config, server, "git_status", {' $PatchedServer
    $ServerNewline = if ($PatchedServer.Contains("`r`n")) { "`r`n" } else { "`n" }
    $Replacement = (Normalize-BlockForFile $HostToolBlock $PatchedServer) + $ServerNewline + $GitStatusAnchor
    $PatchedServer = Replace-ExactlyOnce $PatchedServer $GitStatusAnchor $Replacement 'host tool registrations'
}

$CurrentHostOps = if (Test-Path -LiteralPath $HostOpsFile -PathType Leaf) { [IO.File]::ReadAllText($HostOpsFile) } else { $null }
$HostOpsMatches = $null -ne $CurrentHostOps -and $CurrentHostOps.Replace("`r`n", "`n") -eq $HostOpsPayload.Replace("`r`n", "`n")
if ($null -ne $CurrentHostOps -and -not $HostOpsMatches -and -not $Force) {
    throw "An unrecognized hostOps.js already exists. Re-run with -Force only after reviewing it: $HostOpsFile"
}

$Changed = ($PatchedBash -ne $BashOps) -or ($PatchedConfig -ne $Config) -or ($PatchedServer -ne $Server) -or (-not $HostOpsMatches)
$BackupDir = $null
if ($Changed) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupDir = Join-Path $BackupRoot "codexpro-full-$Timestamp"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Copy-Item -LiteralPath $BashOpsFile -Destination (Join-Path $BackupDir 'bashOps.js')
    Copy-Item -LiteralPath $ConfigFile -Destination (Join-Path $BackupDir 'config.js')
    Copy-Item -LiteralPath $ServerFile -Destination (Join-Path $BackupDir 'server.js')
    $HostOpsExisted = Test-Path -LiteralPath $HostOpsFile -PathType Leaf
    if ($HostOpsExisted) {
        Copy-Item -LiteralPath $HostOpsFile -Destination (Join-Path $BackupDir 'hostOps.js')
    }
    $BackupJson = @{
        packageDir = $ResolvedPackageDir
        packageVersion = $ExpectedVersion
        hostOpsExisted = $HostOpsExisted
    } | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $BackupDir 'backup.json'), $BackupJson, $Utf8NoBom)

    $TempFiles = @()
    try {
        foreach ($item in @(
            @{ Path = $BashOpsFile; Text = $PatchedBash },
            @{ Path = $ConfigFile; Text = $PatchedConfig },
            @{ Path = $ServerFile; Text = $PatchedServer },
            @{ Path = $HostOpsFile; Text = $HostOpsPayload }
        )) {
            $temp = "$($item.Path).qbit-codexpro.tmp"
            [IO.File]::WriteAllText($temp, $item.Text, $Utf8NoBom)
            $TempFiles += $temp
            Move-Item -LiteralPath $temp -Destination $item.Path -Force
        }
    }
    catch {
        Copy-Item -LiteralPath (Join-Path $BackupDir 'bashOps.js') -Destination $BashOpsFile -Force
        Copy-Item -LiteralPath (Join-Path $BackupDir 'config.js') -Destination $ConfigFile -Force
        Copy-Item -LiteralPath (Join-Path $BackupDir 'server.js') -Destination $ServerFile -Force
        $BackupMetadata = Get-Content -LiteralPath (Join-Path $BackupDir 'backup.json') -Raw | ConvertFrom-Json
        if ($BackupMetadata.hostOpsExisted) {
            Copy-Item -LiteralPath (Join-Path $BackupDir 'hostOps.js') -Destination $HostOpsFile -Force
        }
        else {
            Remove-Item -LiteralPath $HostOpsFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        foreach ($temp in $TempFiles) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

$FinalBash = [IO.File]::ReadAllText($BashOpsFile)
$FinalConfig = [IO.File]::ReadAllText($ConfigFile)
$FinalServer = [IO.File]::ReadAllText($ServerFile)
$FinalHost = [IO.File]::ReadAllText($HostOpsFile)
$RequiredMarkers = @(
    @{ Text = $FinalBash; Marker = 'function sandboxInvocation(config, workspace, cwd, command)' },
    @{ Text = $FinalBash; Marker = 'env.USERPROFILE = userProfile;' },
    @{ Text = $FinalConfig; Marker = 'CODEXPRO_BASH_SANDBOX' },
    @{ Text = $FinalConfig; Marker = 'CODEXPRO_HOST_EXEC_MODE' },
    @{ Text = $FinalServer; Marker = 'registerCodexTool(config, server, "host_exec"' },
    @{ Text = $FinalServer; Marker = 'registerCodexTool(config, server, "open_app"' },
    @{ Text = $FinalHost; Marker = 'function requestLocalApproval(request)' }
)
foreach ($Required in $RequiredMarkers) {
    if (-not $Required.Text.Contains($Required.Marker)) {
        throw "CodexPro patch verification failed; missing marker: $($Required.Marker)"
    }
}

[pscustomobject]@{
    changed = $Changed
    packageDir = $ResolvedPackageDir
    packageVersion = $ExpectedVersion
    backupDir = $BackupDir
} | ConvertTo-Json -Compress
