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
