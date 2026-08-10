#!/usr/bin/env python3
"""Read-only production diagnostics for the isolated Phase 2 runtime."""
from __future__ import annotations

import hashlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import platform
import stat
import subprocess
import sys
from typing import Any

CHECK_IDS = (
    "identity", "capabilities", "platform", "network", "workspace-read-only",
    "state-read-only", "resources-read-only", "graphify-output-read-only", "rootfs-read-only",
    "protected-symlink", "global-config", "project-config", "global-no-migration",
    "project-no-migration", "workspace-pre-registered", "external-state-resolution",
    "no-workspace-serena-fallback", "resource-manifest", "resource-entries", "versions",
    "runtime-paths", "ldd-closure", "provider-offline", "mcp-initialize", "mcp-allowlist",
    "mcp-construction", "mcp-process-start", "mcp-initialize-send",
    "mcp-initialize-receive", "mcp-initialize-validate",
    "powershell-semantic-smoke", "bash-semantic-smoke", "python-semantic-smoke",
    "no-edit-tools", "graphify-read-only-cli", "persistent-no-write",
)

SERENA_TOOLS = {
    "get_symbols_overview", "find_symbol", "find_referencing_symbols", "find_implementations",
    "find_declaration", "get_diagnostics_for_file", "get_diagnostics_for_symbol",
    "replace_symbol_body", "insert_after_symbol", "insert_before_symbol", "rename_symbol",
    "safe_delete_symbol",
}
GLOBAL_KEYS = {
    "language_backend", "line_ending", "gui_log_window", "web_dashboard",
    "web_dashboard_open_on_launch", "web_dashboard_interface", "web_dashboard_listen_address",
    "jetbrains_plugin_server_address", "log_level", "trace_lsp_communication",
    "ls_specific_settings", "ignored_paths", "read_only_memory_patterns", "ignored_memory_patterns",
    "tool_timeout", "excluded_tools", "included_optional_tools", "fixed_tools", "base_modes",
    "default_modes", "default_max_tool_answer_chars", "token_count_estimator", "symbol_info_budget",
    "project_serena_folder_location", "projects",
}
PROJECT_KEYS = {
    "project_name", "languages", "encoding", "line_ending", "language_backend",
    "ignore_all_files_in_gitignore", "ls_specific_settings", "additional_workspace_folders",
    "ignored_paths", "read_only", "excluded_tools", "included_optional_tools", "fixed_tools",
    "default_modes", "added_modes", "initial_prompt", "symbol_info_budget",
    "read_only_memory_patterns", "ignored_memory_patterns",
}
PERSISTENT_ROOTS = (Path("/workspace"), Path("/serena-state"), Path("/serena-resources"), Path("/graphify-output"))
SKIP_MOUNTS = {"/serena-state/logs", "/serena-state/projects/qbit-toolkit/cache", "/graphify-output"}


def load_runtime() -> Any:
    spec = importlib.util.spec_from_file_location("qbit_runtime", "/usr/local/libexec/runtime-entrypoint.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


RUNTIME = load_runtime()


def load_mcp_stdio() -> Any:
    spec = importlib.util.spec_from_file_location("qbit_mcp_stdio", "/usr/local/libexec/mcp_stdio.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


MCP_STDIO = load_mcp_stdio()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def file_record(path: Path) -> tuple[Any, ...]:
    info = os.lstat(path)
    kind = "link" if stat.S_ISLNK(info.st_mode) else "dir" if stat.S_ISDIR(info.st_mode) else "file" if stat.S_ISREG(info.st_mode) else "special"
    digest = None
    if kind == "file":
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except PermissionError:
            digest = "<permission-denied>"
    target = os.readlink(path) if kind == "link" else None
    return kind, info.st_uid, info.st_gid, stat.S_IMODE(info.st_mode), info.st_size, info.st_mtime_ns, info.st_ctime_ns, digest, target


def snapshot_tree(root: Path) -> dict[str, tuple[Any, ...]]:
    records = {str(root): file_record(root)}
    for current, dirs, files in os.walk(root, followlinks=False):
        current_path = Path(current)
        dirs[:] = [name for name in dirs if str(current_path / name) not in SKIP_MOUNTS]
        for name in sorted(dirs + files):
            path = current_path / name
            records[str(path)] = file_record(path)
    return records


def persistent_snapshot() -> dict[str, tuple[Any, ...]]:
    result: dict[str, tuple[Any, ...]] = {}
    for root in PERSISTENT_ROOTS:
        result.update(snapshot_tree(root))
    return result


def assert_write_denied(path: Path) -> None:
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except OSError:
        return
    else:
        os.close(fd)
        path.unlink(missing_ok=True)
        raise AssertionError(f"write unexpectedly succeeded: {path}")


def command_output(argv: list[str]) -> str:
    return subprocess.run(argv, check=True, text=True, capture_output=True, timeout=30).stdout.strip()


def ldd_output(path: str) -> str:
    result = subprocess.run(["ldd", path], check=False, text=True, capture_output=True, timeout=30)
    output = "\n".join(part.strip() for part in (result.stdout, result.stderr) if part.strip())
    if result.returncode == 0 or (result.returncode == 1 and "not a dynamic executable" in output):
        return output
    raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)


class MCPClient(MCP_STDIO.MCPClient):
    def __init__(self) -> None:
        super().__init__(
            ["serena", "start-mcp-server", "--transport", "stdio", "--project", "/workspace",
             "--context", "/workspace/.serena/codex-single-project.yml", "--tool-timeout", "45"],
            cwd="/workspace", env={**os.environ, "SERENA_HOME": "/serena-state"},
        )


def successful_mcp_tool_response(response: Any) -> bool:
    if not isinstance(response, dict) or response.get("isError", False):
        return False
    serialized = json.dumps(response, sort_keys=True).lower()
    return not any(
        marker in serialized
        for marker in (
            "error executing tool:",
            "language server manager is not initialized",
            "failed to start 1 language server",
        )
    )


def main() -> int:
    results: dict[str, dict[str, Any]] = {}

    def check(check_id: str, action: Any) -> Any:
        try:
            detail = action()
            results[check_id] = {"passed": True, "detail": detail if detail is not None else "ok"}
            return detail
        except BaseException as exc:  # noqa: BLE001
            results[check_id] = {"passed": False, "detail": f"{type(exc).__name__}: {exc}"}
            raise

    try:
        check("identity", lambda: require(os.geteuid() != 0 and os.getegid() != 0, "Doctor must be non-root"))
        status = RUNTIME.capability_status()
        check("capabilities", lambda: require(all(status.get(name) == 0 for name in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb")) and status.get("NoNewPrivs") == 1, f"unsafe process status: {status}"))
        check("platform", lambda: require(sys.platform == "linux" and platform.machine() in {"x86_64", "amd64"}, platform.platform()))
        check("network", lambda: require(set(os.listdir("/sys/class/net")) <= {"lo"}, f"network interfaces: {os.listdir('/sys/class/net')}"))
        mounts = RUNTIME.mount_table()
        for check_id, path in (("workspace-read-only", "/workspace"), ("state-read-only", "/serena-state"),
                               ("resources-read-only", "/serena-resources"), ("graphify-output-read-only", "/graphify-output")):
            check(check_id, lambda path=path: require("ro" in mounts[path]["options"], f"mount is not read-only: {path}"))
        check("rootfs-read-only", lambda: assert_write_denied(Path("/qbit-doctor-write-probe")))
        check("protected-symlink", lambda: require(Path("/serena-state/language_servers").is_symlink()
              and os.readlink("/serena-state/language_servers") == "/serena-resources/current/language_servers"
              and os.lstat("/serena-state/language_servers").st_uid == 0, "protected symlink mismatch"))

        before = persistent_snapshot()
        import yaml
        global_path = Path("/serena-state/serena_config.yml")
        project_path = Path("/serena-state/projects/qbit-toolkit/project.yml")
        global_source = Path("/opt/qbit/serena-config/serena_config.yml")
        project_source = Path("/opt/qbit/serena-config/project.yml")
        global_value = yaml.safe_load(global_path.read_text(encoding="utf-8"))
        project_value = yaml.safe_load(project_path.read_text(encoding="utf-8"))
        check("global-config", lambda: require(set(global_value) == GLOBAL_KEYS and global_path.read_bytes() == global_source.read_bytes()
              and global_path.stat().st_uid == 0 and stat.S_IMODE(global_path.stat().st_mode) == 0o444, "global config contract mismatch"))
        check("project-config", lambda: require(set(project_value) == PROJECT_KEYS and project_path.read_bytes() == project_source.read_bytes()
              and project_path.stat().st_uid == 0 and stat.S_IMODE(project_path.stat().st_mode) == 0o444, "project config contract mismatch"))

        from serena.config.serena_config import ProjectConfig, SerenaConfig
        config_before = [(path.read_bytes(), path.stat().st_mtime_ns, path.stat().st_ctime_ns) for path in (global_path, project_path)]
        config = SerenaConfig.from_config_file(generate_if_missing=False)
        check("global-no-migration", lambda: require(global_path.read_bytes() == config_before[0][0]
              and global_path.stat().st_mtime_ns == config_before[0][1] and global_path.stat().st_ctime_ns == config_before[0][2], "global config was rewritten"))
        check("project-no-migration", lambda: require(ProjectConfig._load_yaml_dict(str(project_path))[1] is True
              and project_path.read_bytes() == config_before[1][0] and project_path.stat().st_mtime_ns == config_before[1][1]
              and project_path.stat().st_ctime_ns == config_before[1][2], "project config was incomplete or rewritten"))
        check("workspace-pre-registered", lambda: require(config.project_paths == ["/workspace"] and config.get_registered_project("/workspace") is not None, str(config.project_paths)))
        check("external-state-resolution", lambda: require(config.get_configured_project_serena_folder("/workspace") == "/serena-state/projects/qbit-toolkit", "literal state resolution failed"))
        check("no-workspace-serena-fallback", lambda: require(config.get_project_serena_folder("/workspace") == "/serena-state/projects/qbit-toolkit", "workspace fallback selected"))

        manifest, raw_manifest, _ = RUNTIME.load_resource_manifest(Path("/serena-resources/current"))
        check("resource-manifest", lambda: require(raw_manifest == RUNTIME.canonical_json_bytes(manifest), "manifest is not canonical"))
        check("resource-entries", lambda: require(RUNTIME.verify_resource_tree(Path("/serena-resources/current"), manifest, include_manifest=True), "resource tree mismatch"))

        versions = {
            "serena": importlib.metadata.version("serena-agent"),
            "graphify": importlib.metadata.version("graphifyy"),
            "powershell": command_output(["pwsh", "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"]),
            "pses": next(item["version"] for item in manifest["sourceArtifacts"] if item["name"] == "powershell-editor-services"),
            "psscriptanalyzer": command_output(["pwsh", "-NoLogo", "-NoProfile", "-Command", "(Import-PowerShellDataFile '/serena-state/language_servers/static/PowerShellLanguageServer/powershell/PowerShellEditorServices/PSScriptAnalyzer/1.25.0/PSScriptAnalyzer.psd1').ModuleVersion.ToString()"]),
            "shellcheck": next(line.split()[-1] for line in command_output(["/serena-state/language_servers/static/BashLanguageServer/bash-lsp/shellcheck/shellcheck-v0.10.0/shellcheck", "--version"]).splitlines() if line.startswith("version:")),
            "pyright": command_output(["node", "-p", "require('/opt/serena-language-servers/node_modules/pyright/package.json').version"]),
            "bash-language-server": command_output(["node", "-p", "require('/opt/serena-language-servers/node_modules/bash-language-server/package.json').version"]),
        }
        expected_versions = {"serena": "1.5.3", "graphify": "0.9.12", "powershell": "7.6.4", "pses": "4.4.0", "psscriptanalyzer": "1.25.0", "shellcheck": "0.10.0", "pyright": "1.1.403", "bash-language-server": "5.6.0"}
        check("versions", lambda: require(versions == expected_versions, f"version mismatch: {versions}"))
        required_paths = [
            "/opt/microsoft/powershell/7/pwsh",
            "/serena-state/language_servers/static/PowerShellLanguageServer/powershell/PowerShellEditorServices/Start-EditorServices.ps1",
            "/serena-state/language_servers/static/PowerShellLanguageServer/powershell/PowerShellEditorServices/PSScriptAnalyzer/1.25.0/PSScriptAnalyzer.psm1",
            "/serena-state/language_servers/static/PowerShellLanguageServer/powershell/PowerShellEditorServices/PSScriptAnalyzer/1.25.0/PSv7/Microsoft.Windows.PowerShell.ScriptAnalyzer.dll",
            "/serena-state/language_servers/static/BashLanguageServer/bash-lsp/shellcheck/shellcheck-v0.10.0/shellcheck",
            "/opt/serena-language-servers/node_modules/.bin/pyright-langserver",
            "/opt/serena-language-servers/node_modules/.bin/bash-language-server",
        ]
        check("runtime-paths", lambda: require(all(Path(path).is_file() for path in required_paths), "required runtime path missing"))
        ldd_outputs = [ldd_output(path) for path in ("/opt/microsoft/powershell/7/pwsh", "/usr/local/bin/node", required_paths[4])]
        check("ldd-closure", lambda: require(all("not found" not in output for output in ldd_outputs), "unresolved ldd dependency"))
        installer_paths = ("/usr/local/bin/npm", "/usr/local/bin/npx", "/usr/local/bin/uvx", "/usr/local/bin/pip", "/usr/bin/apt", "/usr/bin/apt-get", "/usr/bin/dpkg")
        save_module = subprocess.run(["pwsh", "-NoLogo", "-NoProfile", "-Command", "if (Get-Command Save-Module -ErrorAction SilentlyContinue) { exit 1 }"], check=False).returncode
        check("provider-offline", lambda: require(not any(Path(path).exists() for path in installer_paths) and save_module == 0, "runtime installer command present"))

        client: MCPClient | None = None
        called_tools: list[str] = []
        try:
            def construct_client() -> str:
                nonlocal client
                client = MCPClient()
                return "ok"

            check("mcp-construction", construct_client)
            assert client is not None
            check("mcp-process-start", lambda: client.start())
            initialize_id = check(
                "mcp-initialize-send",
                lambda: client.send_request(
                    "initialize",
                    {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "qbit-doctor", "version": "1"}},
                ),
            )
            initialize = check("mcp-initialize-receive", lambda: client.receive(initialize_id, 90))
            check("mcp-initialize-validate", lambda: require(isinstance(initialize, dict) and "serverInfo" in initialize, "MCP initialize response incomplete"))
            check("mcp-initialize", lambda: require(isinstance(initialize, dict) and "serverInfo" in initialize, "MCP initialize response incomplete"))
            client.send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
            tools = client.request("tools/list", {}, 90)
            names = {item["name"] for item in tools["tools"]}
            check("mcp-allowlist", lambda: require(names == SERENA_TOOLS, f"MCP tool mismatch: {sorted(names)}"))
            for check_id, relative in (("powershell-semantic-smoke", "tests/fixtures/ai-tooling/sample.ps1"),
                                       ("bash-semantic-smoke", "tests/fixtures/ai-tooling/sample.sh"),
                                       ("python-semantic-smoke", "tests/fixtures/ai-tooling/sample.py")):
                called_tools.append("get_symbols_overview")
                response = client.request("tools/call", {"name": "get_symbols_overview", "arguments": {"relative_path": relative, "depth": 1}}, 120)
                check(check_id, lambda response=response: require(successful_mcp_tool_response(response), f"semantic smoke failed: {response}"))
        except BaseException as exc:  # noqa: BLE001
            results.setdefault(
                "mcp-initialize",
                {"passed": False, "detail": f"{type(exc).__name__}: {exc}"},
            )
            raise
        finally:
            if client is not None:
                client.close()
        check("no-edit-tools", lambda: require(set(called_tools) <= {"get_symbols_overview", "get_diagnostics_for_file", "get_diagnostics_for_symbol"}, str(called_tools)))
        graphify_version = importlib.metadata.version("graphifyy")
        graphify_help = subprocess.run(["graphify", "--help"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30).returncode
        check("graphify-read-only-cli", lambda: require(graphify_version == "0.9.12" and graphify_help == 0, "Graphify diagnostic failed"))
        after = persistent_snapshot()
        check("persistent-no-write", lambda: require(before == after, "Doctor changed persistent bytes or metadata"))
    except BaseException:  # noqa: BLE001
        pass

    missing = set(CHECK_IDS) - set(results)
    for check_id in sorted(missing):
        results[check_id] = {"passed": False, "detail": "not reached after prior failure"}
    print(json.dumps({"checks": results}, sort_keys=True, separators=(",", ":")))
    return 0 if all(result["passed"] for result in results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
