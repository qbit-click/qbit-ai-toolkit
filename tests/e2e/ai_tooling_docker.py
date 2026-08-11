#!/usr/bin/env python3
"""Authoritative, fixture-bounded Docker E2E for the Phase 2 runtime."""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import uuid
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = ROOT / ".ai/tooling/compose.yaml"
PROJECT = f"qbit-phase2-{uuid.uuid4().hex[:12]}"
EXPECTED_IMAGE = "qbit-ai-toolkit-ai-runtime:phase2a"
EXPECTED_INDEX_ENTRY = "100644 a748023e65eac08492156379097aadfdde8ea686 0\t.gitignore"
EXPECTED_TOOLS = {
    "get_symbols_overview", "find_symbol", "find_referencing_symbols", "find_implementations",
    "find_declaration", "get_diagnostics_for_file", "get_diagnostics_for_symbol", "replace_symbol_body",
    "insert_after_symbol", "insert_before_symbol", "rename_symbol", "safe_delete_symbol",
}

mcp_spec = importlib.util.spec_from_file_location("qbit_mcp_stdio_e2e", ROOT / ".ai/tooling/mcp_stdio.py")
MCP_STDIO = importlib.util.module_from_spec(mcp_spec)
assert mcp_spec.loader is not None
mcp_spec.loader.exec_module(MCP_STDIO)
ASSERTION_IDS = (
    "bootstrap-preflight", "workspace-bindings", "image-available", "image-platform", "exact-versions",
    "serena-first-state", "prompt-templates-state", "prompt-templates-idempotent",
    "prompt-templates-repair", "prompt-templates-attack-resistance",
    "serena-second-idempotent", "serena-concurrent-init", "corrupt-resource-recovery",
    "corrupt-project-recovery", "symlink-attack-resistance", "protected-global-config",
    "protected-language-servers-symlink", "serena-normal-startup", "exact-mcp-allowlist",
    "powershell-semantic-smoke", "bash-semantic-smoke", "python-semantic-smoke", "serena-workspace-write",
    "graphify-workspace-write-denial", "doctor-workspace-write-denial", "graphify-output-volume-write",
    "graphify-build", "graphify-query", "graphify-report", "graphify-clean", "network-denial",
    "zero-capabilities", "read-only-rootfs", "doctor-no-write-snapshot", "named-volume-cleanup",
    "repository-graphify-out-absence", "repository-node-modules-absence", "complete-index-preservation",
    "protected-gitignore-index",
)


def run(argv: list[str], *, check: bool = True, input_text: str | None = None, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, cwd=ROOT, text=True, input=input_text, capture_output=True, check=check, timeout=timeout)


def compose_args(*args: str, override: Path | None = None) -> list[str]:
    value = ["docker", "compose", "--project-name", PROJECT, "--project-directory", str(ROOT), "-f", str(COMPOSE)]
    if override is not None:
        value.extend(["-f", str(override)])
    value.extend(args)
    return value


def compose(*args: str, override: Path | None = None, check: bool = True, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return run(compose_args(*args, override=override), check=check, timeout=timeout)


def protected_snapshot() -> dict[str, Any]:
    index = run(["git", "ls-files", "--stage"]).stdout.rstrip("\n")
    return {"index": index}


def render_compose_model(*, compose_runner: Any = compose) -> dict[str, Any]:
    rendered = compose_runner("config", "--format", "json")
    try:
        model = json.loads(rendered.stdout)
    except (json.JSONDecodeError, TypeError) as exc:
        raise AssertionError(f"invalid rendered Compose JSON: {exc}") from exc
    if not isinstance(model, dict):
        raise AssertionError("rendered Compose model is not an object")
    return model


def canonical_host_path(path: str | Path) -> str:
    return os.path.normcase(os.path.realpath(os.fspath(path)))


def validate_rendered_workspace_bindings(model: dict[str, Any], repository_root: Path = ROOT) -> None:
    services = model.get("services")
    if not isinstance(services, dict) or "serena" not in services:
        raise AssertionError("rendered Compose model has no serena service")
    expected_root = canonical_host_path(repository_root)
    expected_modes = {"serena": False, "graphify": True, "doctor": True}
    for name, read_only in expected_modes.items():
        service = services.get(name)
        if not isinstance(service, dict):
            raise AssertionError(f"rendered Compose model has no {name} service")
        mounts = service.get("volumes")
        workspace = [
            mount for mount in mounts if isinstance(mount, dict) and mount.get("target") == "/workspace"
        ] if isinstance(mounts, list) else []
        if len(workspace) != 1:
            raise AssertionError(f"{name} must have exactly one /workspace mount")
        mount = workspace[0]
        if mount.get("type") != "bind":
            raise AssertionError(f"{name} /workspace mount must be a bind")
        source = mount.get("source")
        if not isinstance(source, str) or canonical_host_path(source) != expected_root:
            raise AssertionError(f"{name} /workspace bind is outside repository root: {source}")
        if bool(mount.get("read_only", False)) is not read_only:
            raise AssertionError(f"{name} /workspace read-only mode mismatch")

    named_volumes = model.get("volumes")
    if not isinstance(named_volumes, dict) or set(named_volumes) != {
        "serena-state", "serena-resources", "graphify-output",
    }:
        raise AssertionError("rendered Compose named-volume contract mismatch")
    serena_mounts = services["serena"].get("volumes", [])
    for target, source in (
        ("/serena-state", "serena-state"),
        ("/serena-resources", "serena-resources"),
    ):
        matches = [
            mount for mount in serena_mounts
            if isinstance(mount, dict) and mount.get("target") == target
        ]
        if len(matches) != 1 or matches[0].get("type") != "volume" or matches[0].get("source") != source:
            raise AssertionError(f"rendered Serena named-volume mount mismatch: {target}")
    graphify_mounts = services["graphify"].get("volumes", [])
    graphify_output = [
        mount for mount in graphify_mounts
        if isinstance(mount, dict) and mount.get("target") == "/graphify-output"
    ]
    if (
        len(graphify_output) != 1
        or graphify_output[0].get("type") != "volume"
        or graphify_output[0].get("source") != "graphify-output"
        or bool(graphify_output[0].get("read_only", False))
    ):
        raise AssertionError("rendered Graphify output-volume mount mismatch")


def successful_mcp_tool_response(response: dict[str, Any]) -> bool:
    if response.get("isError", False):
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


def resolve_available_serena_image(
    *,
    model: dict[str, Any] | None = None,
    compose_runner: Any = compose,
    command_runner: Any = run,
) -> tuple[str, dict[str, Any]]:
    if model is None:
        model = render_compose_model(compose_runner=compose_runner)
    services = model.get("services") if isinstance(model, dict) else None
    if not isinstance(services, dict) or "serena" not in services:
        raise AssertionError("rendered Compose model has no serena service")
    serena = services["serena"]
    image = serena.get("image") if isinstance(serena, dict) else None
    if not isinstance(image, str) or not image.strip():
        raise AssertionError("rendered serena service has no image")
    image = image.strip()
    if image != EXPECTED_IMAGE:
        raise AssertionError(f"unexpected serena image: {image}")
    inspected_result = command_runner(["docker", "image", "inspect", image], check=False)
    if inspected_result.returncode != 0:
        detail = inspected_result.stderr.strip() or inspected_result.stdout.strip() or f"exit {inspected_result.returncode}"
        raise AssertionError(f"image unavailable: {image}: {detail}")
    try:
        inspected_values = json.loads(inspected_result.stdout)
        inspected = inspected_values[0]
    except (json.JSONDecodeError, IndexError, KeyError, TypeError) as exc:
        raise AssertionError(f"invalid image inspection result for {image}") from exc
    if not isinstance(inspected, dict) or not isinstance(inspected.get("Id"), str) or not inspected["Id"].strip():
        raise AssertionError(f"image inspection returned no ID for {image}")
    return image, inspected


def volume_for(service_volume: str) -> str:
    result = run(["docker", "volume", "ls", "--filter", f"label=com.docker.compose.project={PROJECT}",
                  "--filter", f"label=com.docker.compose.volume={service_volume}", "--format", "{{.Name}}"])
    names = [line for line in result.stdout.splitlines() if line]
    if len(names) != 1:
        raise AssertionError(f"expected one {service_volume} volume, found {names}")
    return names[0]


class DockerMCP(MCP_STDIO.MCPClient):
    def __init__(self) -> None:
        super().__init__(compose_args("run", "--rm", "-T", "serena"), cwd=str(ROOT))
        self.start()


def init_command() -> list[str]:
    script = (
        "from pathlib import Path; from serena.config.serena_config import ProjectConfig,SerenaConfig; "
        "g=Path('/serena-state/serena_config.yml'); p=Path('/serena-state/projects/qbit-ai-toolkit/project.yml'); "
        "before=[(x.read_bytes(),x.stat().st_mtime_ns,x.stat().st_ctime_ns) for x in (g,p)]; "
        "c=SerenaConfig.from_config_file(False); assert c.project_paths==['/workspace']; "
        "assert c.get_configured_project_serena_folder('/workspace')=='/serena-state/projects/qbit-ai-toolkit'; "
        "assert c.get_project_serena_folder('/workspace')=='/serena-state/projects/qbit-ai-toolkit'; "
        "assert ProjectConfig._load_yaml_dict(str(p))[1] is True; "
        "after=[(x.read_bytes(),x.stat().st_mtime_ns,x.stat().st_ctime_ns) for x in (g,p)]; assert before==after"
    )
    return ["run", "--rm", "-T", "serena", "python", "-I", "-c", script]


def root_volume_script(image: str, volume: str, mount: str, script: str) -> subprocess.CompletedProcess[str]:
    return run(["docker", "run", "--rm", "--platform", "linux/amd64", "--user", "0:0", "--entrypoint", "python",
                "-v", f"{volume}:{mount}", image, "-I", "-c", script], check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host-family", choices=("powershell", "posix"), required=True)
    args = parser.parse_args()
    results: dict[str, dict[str, Any]] = {}
    before = protected_snapshot()
    override_path: Path | None = None

    def assertion(assertion_id: str, condition: bool, detail: Any = "ok") -> None:
        if not condition:
            results[assertion_id] = {"passed": False, "detail": detail}
            raise AssertionError(f"{assertion_id}: {detail}")
        results[assertion_id] = {"passed": True, "detail": detail}

    try:
        info = run(["docker", "info", "--format", "{{.OSType}}/{{.Architecture}}"])
        config = compose("config", "--quiet")
        assertion("bootstrap-preflight", info.stdout.strip() in {"linux/amd64", "linux/x86_64"} and config.returncode == 0)
        assertion("repository-node-modules-absence", not (ROOT / "node_modules").exists() and not (TOOLING := ROOT / ".ai/tooling/language-servers/node_modules").exists())
        assertion("repository-graphify-out-absence", not (ROOT / "graphify-out").exists())

        model = render_compose_model()
        try:
            validate_rendered_workspace_bindings(model)
        except AssertionError as exc:
            assertion("workspace-bindings", False, str(exc))
        assertion("workspace-bindings", True)
        try:
            image, inspected = resolve_available_serena_image(model=model)
        except AssertionError as exc:
            assertion("image-available", False, str(exc))
        assertion("image-available", True, {"image": image, "id": inspected["Id"]})
        assertion("image-platform", inspected["Os"] == "linux" and inspected["Architecture"] == "amd64", {"image": inspected["Id"]})

        first_init = compose(*init_command(), timeout=300)
        assertion("serena-first-state", first_init.returncode == 0)
        state_volume = volume_for("serena-state"); resource_volume = volume_for("serena-resources")
        identity = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "import os; print(f'{os.getuid()}:{os.getgid()}')")
        runtime_uid, runtime_gid = map(int, identity.stdout.strip().splitlines()[-1].split(":"))
        prompt_meta = root_volume_script(
            image, state_volume, "/serena-state",
            "import json,stat; from pathlib import Path; p=Path('/serena-state/prompt_templates'); "
            "s=p.stat(follow_symlinks=False); print(json.dumps({'dir':stat.S_ISDIR(s.st_mode),'uid':s.st_uid,'gid':s.st_gid,'mode':stat.S_IMODE(s.st_mode)}))",
        )
        prompt_value = json.loads(prompt_meta.stdout.strip())
        assertion("prompt-templates-state", prompt_meta.returncode == 0 and prompt_value == {
            "dir": True, "uid": runtime_uid, "gid": runtime_gid, "mode": 0o700,
        }, prompt_value)
        marker = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; (Path('/serena-state/prompt_templates')/'e2e-marker').write_bytes(b'preserve')",
        )
        state_meta = root_volume_script(image, state_volume, "/serena-state", "import json,os,stat; from pathlib import Path; ps=[Path('/serena-state/serena_config.yml'),Path('/serena-state/projects/qbit-ai-toolkit/project.yml')]; print(json.dumps([(p.read_bytes().hex(),p.stat().st_mtime_ns,p.stat().st_ctime_ns) for p in ps]))")
        second_init = compose(*init_command(), timeout=300)
        state_meta_after = root_volume_script(image, state_volume, "/serena-state", "import json; from pathlib import Path; ps=[Path('/serena-state/serena_config.yml'),Path('/serena-state/projects/qbit-ai-toolkit/project.yml')]; print(json.dumps([(p.read_bytes().hex(),p.stat().st_mtime_ns,p.stat().st_ctime_ns) for p in ps]))")
        assertion("serena-second-idempotent", second_init.returncode == 0 and state_meta.stdout == state_meta_after.stdout)
        marker_after = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; print((Path('/serena-state/prompt_templates')/'e2e-marker').read_text())",
        )
        assertion("prompt-templates-idempotent", marker.returncode == 0 and marker_after.stdout.strip() == "preserve")
        damaged_prompt = root_volume_script(
            image, state_volume, "/serena-state",
            "import os; from pathlib import Path; p=Path('/serena-state/prompt_templates'); os.chown(p,0,0); p.chmod(0o555)",
        )
        repaired_prompt = compose(*init_command(), timeout=300)
        repair_check = root_volume_script(
            image, state_volume, "/serena-state",
            "import json,stat; from pathlib import Path; p=Path('/serena-state/prompt_templates'); s=p.stat(); "
            "print(json.dumps({'uid':s.st_uid,'gid':s.st_gid,'mode':stat.S_IMODE(s.st_mode),'marker':(p/'e2e-marker').read_text()}))",
        )
        repair_value = json.loads(repair_check.stdout.strip())
        assertion("prompt-templates-repair", damaged_prompt.returncode == 0 and repaired_prompt.returncode == 0
                  and repair_value == {"uid": runtime_uid, "gid": runtime_gid, "mode": 0o700, "marker": "preserve"}, repair_value)

        symlink_attack = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; r=Path('/serena-state'); p=r/'prompt_templates'; p.rename(r/'prompt_templates.saved'); "
            "e=r/'prompt-external'; e.write_text('external'); p.symlink_to(e)",
        )
        symlink_run = compose(*init_command(), check=False, timeout=300)
        symlink_check = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; r=Path('/serena-state'); print((r/'prompt-external').read_text(),(r/'prompt_templates').is_symlink())",
        )
        root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; r=Path('/serena-state'); (r/'prompt_templates').unlink(); "
            "(r/'prompt-external').unlink(); (r/'prompt_templates.saved').rename(r/'prompt_templates')",
        )
        file_attack = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; r=Path('/serena-state'); p=r/'prompt_templates'; p.rename(r/'prompt_templates.saved'); p.write_text('file')",
        )
        file_run = compose(*init_command(), check=False, timeout=300)
        file_check = root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; print(Path('/serena-state/prompt_templates').read_text())",
        )
        root_volume_script(
            image, state_volume, "/serena-state",
            "from pathlib import Path; r=Path('/serena-state'); (r/'prompt_templates').unlink(); "
            "(r/'prompt_templates.saved').rename(r/'prompt_templates')",
        )
        attack_recovery = compose(*init_command(), timeout=300)
        assertion("prompt-templates-attack-resistance", symlink_attack.returncode == 0 and symlink_run.returncode != 0
                  and "external True" in symlink_check.stdout and file_attack.returncode == 0
                  and file_run.returncode != 0 and file_check.stdout.strip() == "file"
                  and attack_recovery.returncode == 0)

        concurrent = [subprocess.Popen(compose_args(*init_command()), cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        concurrent_codes = [process.wait(timeout=300) for process in concurrent]
        assertion("serena-concurrent-init", concurrent_codes == [0, 0], concurrent_codes)

        corrupt = root_volume_script(image, resource_volume, "/serena-resources", "from pathlib import Path; p=next(Path('/serena-resources/sets').glob('*/language_servers/static/BashLanguageServer/bash-lsp/shellcheck/shellcheck-v0.10.0/shellcheck')); p.chmod(0o644); p.write_bytes(b'corrupt')")
        recovered = compose(*init_command(), timeout=300)
        assertion("corrupt-resource-recovery", corrupt.returncode == 0 and recovered.returncode == 0)
        corrupt_project = root_volume_script(image, state_volume, "/serena-state", "from pathlib import Path; p=Path('/serena-state/projects/qbit-ai-toolkit/project.yml'); p.chmod(0o644); p.write_text('bad: true\\n')")
        recovered_project = compose(*init_command(), timeout=300)
        assertion("corrupt-project-recovery", corrupt_project.returncode == 0 and recovered_project.returncode == 0)

        attack = root_volume_script(image, state_volume, "/serena-state", "from pathlib import Path; d=Path('/serena-state/projects/qbit-ai-toolkit'); p=d/'project.yml'; p.unlink(); t=d/'external-target'; t.write_text('external\\n'); t.chmod(0o444); p.symlink_to(t)")
        attacked_run = compose(*init_command(), check=False, timeout=300)
        attack_check = root_volume_script(image, state_volume, "/serena-state", "from pathlib import Path; d=Path('/serena-state/projects/qbit-ai-toolkit'); print((d/'external-target').read_text(), (d/'project.yml').is_symlink())")
        assertion("symlink-attack-resistance", attack.returncode == 0 and attacked_run.returncode != 0 and "external" in attack_check.stdout and "True" in attack_check.stdout)
        root_volume_script(image, state_volume, "/serena-state", "from pathlib import Path; d=Path('/serena-state/projects/qbit-ai-toolkit'); (d/'project.yml').unlink(); (d/'external-target').unlink()")
        assertion("corrupt-project-recovery", compose(*init_command(), timeout=300).returncode == 0)

        write_global = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "from pathlib import Path; Path('/serena-state/serena_config.yml').write_text('bad')", check=False)
        assertion("protected-global-config", write_global.returncode != 0)
        link_check = root_volume_script(image, state_volume, "/serena-state", "import os; print(os.readlink('/serena-state/language_servers'))")
        assertion("protected-language-servers-symlink", link_check.stdout.strip() == "/serena-resources/current/language_servers")

        client = DockerMCP()
        try:
            initialized = client.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "qbit-e2e", "version": "1"}}, 120)
            client.send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
            assertion("serena-normal-startup", "serverInfo" in initialized)
            tool_result = client.request("tools/list", {}, 120)
            tool_names = {tool["name"] for tool in tool_result["tools"]}
            assertion("exact-mcp-allowlist", tool_names == EXPECTED_TOOLS, sorted(tool_names))
            for assertion_id, relative in (("powershell-semantic-smoke", "tests/fixtures/ai-tooling/sample.ps1"),
                                           ("bash-semantic-smoke", "tests/fixtures/ai-tooling/sample.sh"),
                                           ("python-semantic-smoke", "tests/fixtures/ai-tooling/sample.py")):
                response = client.request("tools/call", {"name": "get_symbols_overview", "arguments": {"relative_path": relative, "depth": 1}}, 180)
                assertion(assertion_id, successful_mcp_tool_response(response), response)
        finally:
            client.close()

        serena_write = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "from pathlib import Path; p=Path('/workspace/.ai/cache/e2e-write'); p.parent.mkdir(exist_ok=True); p.write_text('ok'); p.unlink()")
        assertion("serena-workspace-write", serena_write.returncode == 0)
        graphify_denied = compose("run", "--rm", "-T", "graphify", "python", "-I", "-c", "from pathlib import Path; Path('/workspace/forbidden').write_text('bad')", check=False)
        assertion("graphify-workspace-write-denial", graphify_denied.returncode != 0)
        doctor_denied = compose("run", "--rm", "-T", "--entrypoint", "python", "doctor", "-I", "-c", "from pathlib import Path; Path('/workspace/forbidden').write_text('bad')", check=False)
        assertion("doctor-workspace-write-denial", doctor_denied.returncode != 0)
        graphify_volume_write = compose("run", "--rm", "-T", "graphify", "python", "-I", "-c", "from pathlib import Path; p=Path('/graphify-output/probe'); p.write_text('ok'); p.unlink()", check=False)
        assertion("graphify-output-volume-write", graphify_volume_write.returncode == 0)

        with tempfile.TemporaryDirectory(prefix="qbit-graphify-override-") as temporary:
            override_path = Path(temporary) / "compose.override.yaml"
            source = (ROOT / "tests/fixtures/ai-tooling").as_posix().replace('"', '\\"')
            override_path.write_text(f'services:\n  graphify:\n    volumes:\n      - type: bind\n        source: "{source}"\n        target: /workspace\n        read_only: true\n      - type: volume\n        source: graphify-output\n        target: /graphify-output\n        read_only: false\n', encoding="utf-8")
            built = compose("run", "--rm", "-T", "graphify", "python", "-I", "/usr/local/libexec/graphify-runtime.py", "build", override=override_path, check=False, timeout=600)
            assertion("graphify-build", built.returncode == 0, built.stderr[-3000:])
            queried = compose("run", "--rm", "-T", "graphify", "python", "-I", "/usr/local/libexec/graphify-runtime.py", "query", "What fixture functions exist?", override=override_path, check=False, timeout=300)
            assertion("graphify-query", queried.returncode == 0, queried.stderr[-3000:])
            report = compose("run", "--rm", "-T", "graphify", "python", "-I", "/usr/local/libexec/graphify-runtime.py", "report", override=override_path, check=False)
            assertion("graphify-report", report.returncode == 0 and bool(report.stdout.strip()), report.stderr[-3000:])
            cleaned = compose("run", "--rm", "-T", "graphify", "python", "-I", "/usr/local/libexec/graphify-runtime.py", "clean", override=override_path, check=False)
            assertion("graphify-clean", cleaned.returncode == 0, cleaned.stderr[-3000:])

        network = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "import socket; socket.create_connection(('1.1.1.1',443),2)", check=False)
        assertion("network-denial", network.returncode != 0)
        caps = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "from pathlib import Path; print(''.join(x for x in Path('/proc/self/status').read_text().splitlines(True) if x.startswith(('Cap','NoNewPrivs'))))")
        assertion("zero-capabilities", all(f"{name}:\t0000000000000000" in caps.stdout for name in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb")) and "NoNewPrivs:\t1" in caps.stdout)
        rootfs = compose("run", "--rm", "-T", "serena", "python", "-I", "-c", "from pathlib import Path; Path('/forbidden').write_text('bad')", check=False)
        assertion("read-only-rootfs", rootfs.returncode != 0)

        doctor = compose("run", "--rm", "-T", "doctor", check=False, timeout=600)
        doctor_json = json.loads(doctor.stdout.strip().splitlines()[-1]) if doctor.stdout.strip() else {}
        doctor_checks = doctor_json.get("checks", {})
        assertion("doctor-no-write-snapshot", doctor.returncode == 0 and doctor_checks.get("persistent-no-write", {}).get("passed") is True, doctor_json)
        versions_ok = doctor_checks.get("versions", {}).get("passed") is True
        assertion("exact-versions", versions_ok, doctor_checks.get("versions"))

        after = protected_snapshot()
        assertion("complete-index-preservation", before["index"] == after["index"])
        gitignore_entry = run(["git", "ls-files", "--stage", "--", ".gitignore"]).stdout.rstrip("\n")
        assertion("protected-gitignore-index", gitignore_entry == EXPECTED_INDEX_ENTRY, gitignore_entry)
        assertion("repository-node-modules-absence", not (ROOT / "node_modules").exists() and not (ROOT / ".ai/tooling/language-servers/node_modules").exists())
        assertion("repository-graphify-out-absence", not (ROOT / "graphify-out").exists())
    except BaseException as exc:  # noqa: BLE001
        failure = f"{type(exc).__name__}: {exc}"
    else:
        failure = None
    finally:
        cleanup = compose("down", "--volumes", "--remove-orphans", check=False, timeout=300)
        remaining = run(["docker", "volume", "ls", "--filter", f"label=com.docker.compose.project={PROJECT}", "--format", "{{.Name}}"], check=False).stdout.strip()
        results["named-volume-cleanup"] = {"passed": cleanup.returncode == 0 and not remaining, "detail": remaining or "removed"}

    for assertion_id in ASSERTION_IDS:
        results.setdefault(assertion_id, {"passed": False, "detail": "not reached after prior failure"})
    passed = sum(1 for item in results.values() if item["passed"])
    failed = len(results) - passed
    evidence = {"project": PROJECT, "hostFamily": args.host_family, "results": results,
                "totals": {"passed": passed, "failed": failed, "skipped": 0}, "failure": failure}
    print(json.dumps(evidence, sort_keys=True, separators=(",", ":")))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
