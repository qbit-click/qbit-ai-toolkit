from __future__ import annotations

import contextlib
import hashlib
import http.client
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tarfile
import tempfile
import threading
import time
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TOOLING = ROOT / ".ai/tooling"

validate_spec = importlib.util.spec_from_file_location("qbit_validate_ai", ROOT / "tools/validate.py")
validate = importlib.util.module_from_spec(validate_spec)
assert validate_spec.loader is not None
validate_spec.loader.exec_module(validate)

runtime_spec = importlib.util.spec_from_file_location("qbit_runtime_unit", TOOLING / "runtime-entrypoint.py")
runtime = importlib.util.module_from_spec(runtime_spec)
assert runtime_spec.loader is not None
runtime_spec.loader.exec_module(runtime)

download_spec = importlib.util.spec_from_file_location("qbit_build_download_unit", TOOLING / "build-download.py")
downloader = importlib.util.module_from_spec(download_spec)
assert download_spec.loader is not None
download_spec.loader.exec_module(downloader)

e2e_spec = importlib.util.spec_from_file_location("qbit_ai_tooling_e2e_unit", ROOT / "tests/e2e/ai_tooling_docker.py")
e2e = importlib.util.module_from_spec(e2e_spec)
assert e2e_spec.loader is not None
e2e_spec.loader.exec_module(e2e)

mcp_spec = importlib.util.spec_from_file_location("qbit_mcp_stdio_unit", TOOLING / "mcp_stdio.py")
mcp_stdio = importlib.util.module_from_spec(mcp_spec)
assert mcp_spec.loader is not None
mcp_spec.loader.exec_module(mcp_stdio)


class FakeResponse:
    def __init__(self, status: int, headers: dict[str, str], events: list[bytes | BaseException]) -> None:
        self.status = status
        self.headers = headers
        self.events = list(events)
        self.read_sizes: list[int] = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, size: int) -> bytes:
        self.read_sizes.append(size)
        if not self.events:
            return b""
        event = self.events.pop(0)
        if isinstance(event, BaseException):
            raise event
        return event


def parsed(path: Path):
    return validate.parse_simple_yaml(path.read_text(encoding="utf-8"))


def make_resource_source(root: Path) -> tuple[dict, bytes]:
    directory = root / "language_servers/static/example"
    directory.mkdir(parents=True)
    payload = directory / "server"
    payload.write_bytes(b"fixture\n")
    os.chmod(root / "language_servers", 0o555)
    os.chmod(root / "language_servers/static", 0o555)
    os.chmod(directory, 0o555)
    os.chmod(payload, 0o444)
    entries = []
    for path in sorted(root.rglob("*")):
        if path.name == "manifest.json":
            continue
        info = path.stat()
        item = {"path": path.relative_to(root).as_posix(), "type": "directory" if path.is_dir() else "file",
                "mode": f"{stat.S_IMODE(info.st_mode):04o}", "size": 0 if path.is_dir() else info.st_size}
        if path.is_file():
            item["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        entries.append(item)
    manifest = {"schemaVersion": 1, "serenaVersion": "1.5.3", "sourceArtifacts": [], "entries": entries}
    raw = runtime.canonical_json_bytes(manifest)
    (root / "manifest.json").write_bytes(raw)
    os.chmod(root / "manifest.json", 0o444)
    return manifest, raw


class AiToolingContractTests(unittest.TestCase):
    @staticmethod
    def completed(*, stdout: str = "", stderr: str = "", returncode: int = 0) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess([], returncode, stdout, stderr)

    @staticmethod
    def rendered_compose_model(root: Path = ROOT) -> dict:
        source = str(root.resolve())
        return {
            "services": {
                "serena": {"volumes": [
                    {"type": "bind", "source": source, "target": "/workspace"},
                    {"type": "volume", "source": "serena-state", "target": "/serena-state"},
                    {"type": "volume", "source": "serena-resources", "target": "/serena-resources"},
                ]},
                "graphify": {"volumes": [
                    {"type": "bind", "source": source, "target": "/workspace", "read_only": True},
                    {"type": "volume", "source": "graphify-output", "target": "/graphify-output"},
                ]},
                "doctor": {"volumes": [
                    {"type": "bind", "source": source, "target": "/workspace", "read_only": True},
                ]},
            },
            "volumes": {
                "serena-state": {}, "serena-resources": {}, "graphify-output": {},
            },
        }

    def test_e2e_rendered_workspace_bindings_resolve_to_repository_root(self) -> None:
        e2e.validate_rendered_workspace_bindings(self.rendered_compose_model())

    def test_e2e_rendered_workspace_bindings_reject_parent_source(self) -> None:
        model = self.rendered_compose_model()
        model["services"]["serena"]["volumes"][0]["source"] = str(ROOT.parent.parent)
        with self.assertRaisesRegex(AssertionError, "outside repository root"):
            e2e.validate_rendered_workspace_bindings(model)

    def test_e2e_rendered_workspace_bindings_reject_missing_mount(self) -> None:
        model = self.rendered_compose_model()
        model["services"]["serena"]["volumes"].pop(0)
        with self.assertRaisesRegex(AssertionError, "exactly one /workspace mount"):
            e2e.validate_rendered_workspace_bindings(model)

    def test_e2e_rendered_workspace_bindings_reject_multiple_conflicting_mounts(self) -> None:
        model = self.rendered_compose_model()
        model["services"]["serena"]["volumes"].insert(
            1,
            {"type": "bind", "source": str(ROOT.parent), "target": "/workspace"},
        )
        with self.assertRaisesRegex(AssertionError, "exactly one /workspace mount"):
            e2e.validate_rendered_workspace_bindings(model)

    def test_e2e_rendered_workspace_bindings_reject_unrelated_absolute_source(self) -> None:
        model = self.rendered_compose_model()
        model["services"]["doctor"]["volumes"][0]["source"] = str(ROOT.parent / "unrelated")
        with self.assertRaisesRegex(AssertionError, "outside repository root"):
            e2e.validate_rendered_workspace_bindings(model)

    def test_e2e_rendered_workspace_bindings_preserve_serena_named_volumes(self) -> None:
        model = self.rendered_compose_model()
        model["services"]["serena"]["volumes"][1]["source"] = "wrong-state"
        with self.assertRaisesRegex(AssertionError, "named-volume mount mismatch"):
            e2e.validate_rendered_workspace_bindings(model)

    def test_e2e_resolves_existing_configured_image_without_compose_containers(self) -> None:
        calls: list[tuple[str, ...]] = []

        def compose_runner(*args: str):
            calls.append(("compose", *args))
            return self.completed(stdout=json.dumps({"services": {"serena": {"image": e2e.EXPECTED_IMAGE}}}))

        def command_runner(args: list[str], *, check: bool):
            calls.append(tuple(args))
            self.assertFalse(check)
            return self.completed(stdout=json.dumps([{"Id": "sha256:existing", "Os": "linux", "Architecture": "amd64"}]))

        image, inspected = e2e.resolve_available_serena_image(
            compose_runner=compose_runner,
            command_runner=command_runner,
        )
        self.assertEqual(e2e.EXPECTED_IMAGE, image)
        self.assertEqual("sha256:existing", inspected["Id"])
        self.assertEqual(("compose", "config", "--format", "json"), calls[0])
        self.assertEqual(("docker", "image", "inspect", e2e.EXPECTED_IMAGE), calls[1])
        self.assertFalse(any("images" in call for call in calls))

    def test_e2e_image_resolution_rejects_absent_serena_service(self) -> None:
        with self.assertRaisesRegex(AssertionError, "no serena service"):
            e2e.resolve_available_serena_image(
                compose_runner=lambda *_args: self.completed(stdout='{"services":{"doctor":{"image":"example"}}}'),
                command_runner=mock.Mock(),
            )

    def test_e2e_image_resolution_rejects_missing_or_empty_image(self) -> None:
        for service in ({}, {"image": ""}, {"image": "   "}):
            with self.subTest(service=service), self.assertRaisesRegex(AssertionError, "has no image"):
                e2e.resolve_available_serena_image(
                    compose_runner=lambda *_args, service=service: self.completed(
                        stdout=json.dumps({"services": {"serena": service}})
                    ),
                    command_runner=mock.Mock(),
                )

    def test_e2e_image_resolution_reports_inspect_failure_as_unavailable(self) -> None:
        with self.assertRaisesRegex(AssertionError, r"image unavailable: qbit-ai-toolkit-ai-runtime:phase2a"):
            e2e.resolve_available_serena_image(
                compose_runner=lambda *_args: self.completed(
                    stdout=json.dumps({"services": {"serena": {"image": e2e.EXPECTED_IMAGE}}})
                ),
                command_runner=lambda *_args, **_kwargs: self.completed(returncode=1, stderr="No such image"),
            )

    def test_e2e_has_no_compose_images_dependency(self) -> None:
        text = (ROOT / "tests/e2e/ai_tooling_docker.py").read_text(encoding="utf-8")
        self.assertNotIn('compose("images"', text)
        self.assertNotIn('"images", "-q"', text)

    def test_e2e_mcp_process_uses_binary_unbuffered_streams(self) -> None:
        process = mock.Mock()
        process.stdin = io.BytesIO()
        process.stdout = io.BytesIO()
        process.stderr = io.BytesIO()
        process.poll.return_value = 0
        with mock.patch.object(e2e.MCP_STDIO.subprocess, "Popen", return_value=process) as popen:
            e2e.DockerMCP()
        self.assertNotIn("text", popen.call_args.kwargs)
        self.assertNotIn("encoding", popen.call_args.kwargs)
        self.assertEqual(0, popen.call_args.kwargs["bufsize"])

    def test_mcp_stdio_parses_utf8_content_length_in_bytes(self) -> None:
        payload = json.dumps(
            {"jsonrpc": "2.0", "id": 1, "result": {"value": "سلام"}},
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        stream = io.BytesIO(
            b"Serena startup diagnostic\n"
            + f"Content-Length: {len(payload)}\r\nContent-Type: application/json\r\n\r\n".encode("ascii")
            + payload
        )
        self.assertEqual("سلام", mcp_stdio.read_mcp_message(stream)["result"]["value"])

    def test_mcp_stdio_rejects_malformed_and_truncated_frames(self) -> None:
        with self.assertRaisesRegex(mcp_stdio.MCPProtocolError, "Content-Length"):
            mcp_stdio.read_mcp_message(io.BytesIO(b"Content-Length: nope\r\n\r\n{}"))
        with self.assertRaisesRegex(mcp_stdio.MCPProtocolError, "truncated MCP frame"):
            mcp_stdio.read_mcp_message(io.BytesIO(b"Content-Length: 10\r\n\r\n{}"))
        with self.assertRaisesRegex(mcp_stdio.MCPProtocolError, "JSON-RPC"):
            mcp_stdio.read_mcp_message(io.BytesIO(b'{"id":1,"result":{}}\n'))

    def test_mcp_stdio_rejects_error_responses_and_bounds_receive(self) -> None:
        client = mcp_stdio.MCPClient(["unused"], cwd="/workspace")
        client._events.put((
            "message",
            {"jsonrpc": "2.0", "id": 1, "error": {"code": -32603, "message": "embedded"}},
        ))
        with self.assertRaisesRegex(RuntimeError, "embedded"):
            client.receive(1, 0.1)
        with self.assertRaises(TimeoutError):
            client.receive(2, 0.01)

    def test_e2e_semantic_response_rejects_embedded_serena_errors(self) -> None:
        self.assertTrue(e2e.successful_mcp_tool_response({
            "isError": False,
            "structuredContent": {"result": "[]"},
        }))
        self.assertFalse(e2e.successful_mcp_tool_response({
            "isError": False,
            "structuredContent": {"result": "Error executing tool: language server manager is not initialized"},
        }))

    def test_image_seeds_required_pyright_resource_directory(self) -> None:
        dockerfile = (TOOLING / "Dockerfile").read_text(encoding="utf-8")
        self.assertIn('pyright = static / "PyrightServer"', dockerfile)
        self.assertIn("pyright.mkdir(parents=True, mode=0o755)", dockerfile)
        self.assertIn("required Pyright resource directory missing or unsafe", dockerfile)

    def test_graphify_output_is_external_to_read_only_workspace(self) -> None:
        for relative in (
            ".ai/tooling/compose.yaml",
            ".ai/tooling/runtime-entrypoint.py",
            ".ai/tooling/graphify-runtime.py",
            ".ai/tooling/doctor.py",
        ):
            text = (ROOT / relative).read_text(encoding="utf-8")
            self.assertIn("/graphify-output", text, relative)
            self.assertNotIn("/workspace/graphify-out", text, relative)

    def test_doctor_uses_only_ephemeral_home_and_cache(self) -> None:
        compose = parsed(TOOLING / "compose.yaml")
        environment = compose["services"]["doctor"]["environment"]
        self.assertEqual("/tmp", environment["HOME"])
        self.assertEqual("/tmp/cache", environment["XDG_CACHE_HOME"])

    def test_doctor_private_serena_tmpfs_is_owned_by_runtime_user(self) -> None:
        compose = parsed(TOOLING / "compose.yaml")
        tmpfs = set(compose["services"]["doctor"]["tmpfs"])
        self.assertIn(
            "/serena-state/logs:rw,nosuid,nodev,noexec,mode=0700,uid=10001,gid=10001,size=32m",
            tmpfs,
        )
        self.assertIn(
            "/serena-state/projects/qbit-ai-toolkit/cache:rw,nosuid,nodev,noexec,mode=0700,uid=10001,gid=10001,size=64m",
            tmpfs,
        )

    def test_doctor_handles_root_only_metadata_without_gaining_access(self) -> None:
        doctor = (TOOLING / "doctor.py").read_text(encoding="utf-8")
        self.assertIn("except PermissionError:", doctor)
        self.assertIn('digest = "<permission-denied>"', doctor)
        self.assertIn("successful_mcp_tool_response(response)", doctor)
        self.assertIn('.decode("utf-8", errors="replace")', (TOOLING / "mcp_stdio.py").read_text())

    def test_doctor_accepts_only_the_expected_static_ldd_result(self) -> None:
        doctor = (TOOLING / "doctor.py").read_text(encoding="utf-8")
        self.assertIn("def ldd_output(path: str)", doctor)
        self.assertIn('result.returncode == 1 and "not a dynamic executable" in output', doctor)
        self.assertIn("raise subprocess.CalledProcessError", doctor)

    def test_doctor_records_each_mcp_initialization_stage(self) -> None:
        doctor = (TOOLING / "doctor.py").read_text(encoding="utf-8")
        for check_id in (
            "mcp-construction",
            "mcp-process-start",
            "mcp-initialize-send",
            "mcp-initialize-receive",
            "mcp-initialize-validate",
            "mcp-initialize",
        ):
            self.assertIn(f'"{check_id}"', doctor)
        self.assertIn('cwd="/workspace"', doctor)
        self.assertIn('results.setdefault(\n                "mcp-initialize"', doctor)

    def test_exact_global_yaml_key_set_and_values(self) -> None:
        value = parsed(TOOLING / "serena_config.yml")
        self.assertEqual(validate.AI_GLOBAL_KEYS, set(value))
        self.assertEqual("/serena-state/projects/qbit-ai-toolkit", value["project_serena_folder_location"])
        self.assertEqual(["/workspace"], value["projects"])
        self.assertNotIn("$projectFolderName", (TOOLING / "serena_config.yml").read_text())

    def test_exact_project_yaml_key_set_and_language_paths(self) -> None:
        value = parsed(ROOT / ".serena/project.yml")
        self.assertEqual(validate.AI_PROJECT_KEYS, set(value))
        self.assertEqual(["powershell", "bash", "python"], value["languages"])
        self.assertEqual("/opt/serena-language-servers/node_modules/.bin/pyright-langserver", value["ls_specific_settings"]["python"]["ls_path"])
        self.assertEqual("/opt/serena-language-servers/node_modules/.bin/bash-language-server", value["ls_specific_settings"]["bash"]["ls_path"])

    def test_exact_serena_tool_allowlist(self) -> None:
        context = parsed(ROOT / ".serena/codex-single-project.yml")
        codex = __import__("tomllib").loads((ROOT / ".codex/config.toml").read_text())
        self.assertEqual(set(validate.SERENA_TOOLS), set(context["fixed_tools"]))
        self.assertEqual(validate.SERENA_TOOLS, codex["mcp_servers"]["serena"]["enabled_tools"])

    def test_no_save_and_no_workspace_fallback_static_contract(self) -> None:
        global_value = parsed(TOOLING / "serena_config.yml")
        project_value = parsed(ROOT / ".serena/project.yml")
        self.assertEqual(validate.AI_GLOBAL_KEYS, set(global_value))
        self.assertEqual(validate.AI_PROJECT_KEYS, set(project_value))
        self.assertEqual("/serena-state/projects/qbit-ai-toolkit", global_value["project_serena_folder_location"])
        self.assertFalse((TOOLING / "serena-runtime.py").exists())

    def test_immutable_locks_and_npm_integrity(self) -> None:
        expected = {"python/requirements.in": "9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0",
                    "python/requirements.lock": "df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1"}
        for relative, digest in expected.items():
            self.assertEqual(digest, hashlib.sha256((TOOLING / relative).read_bytes()).hexdigest())
        lock = json.loads((TOOLING / "language-servers/package-lock.json").read_text())
        self.assertEqual(3, lock["lockfileVersion"])
        self.assertEqual({"bash-language-server": "5.6.0", "pyright": "1.1.403"}, lock["packages"][""]["dependencies"])
        self.assertTrue(all("integrity" in item for path, item in lock["packages"].items() if path))
        dockerfile = (TOOLING / "Dockerfile").read_text()
        self.assertIn("python -m pip --retries 10 --timeout 120 install", dockerfile)
        self.assertIn("--require-hashes --no-deps", dockerfile)

    def test_artifact_downloader_streams_retries_resumes_and_verifies(self) -> None:
        payload = b"abcdef"
        first = FakeResponse(
            200,
            {"Content-Length": "6"},
            [b"abc", http.client.IncompleteRead(b"", 3)],
        )
        second = FakeResponse(
            206,
            {"Content-Length": "3", "Content-Range": "bytes 3-5/6"},
            [b"def", b""],
        )
        responses = iter((first, second))
        requests = []

        def open_response(request, *, timeout):
            requests.append((request, timeout))
            return next(responses)

        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "artifact"
            result = downloader.download_verified_artifact(
                "https://example.invalid/artifact",
                hashlib.sha256(payload).hexdigest(),
                destination,
                attempts=3,
                timeout=17,
                chunk_size=2,
                backoff_base=0,
                opener=open_response,
                sleeper=lambda _delay: None,
            )
            self.assertEqual(destination, result)
            self.assertEqual(payload, destination.read_bytes())
            self.assertFalse(destination.with_name("artifact.part").exists())
        self.assertIsNone(requests[0][0].get_header("Range"))
        self.assertEqual("bytes=3-", requests[1][0].get_header("Range"))
        self.assertEqual([2, 2], first.read_sizes)
        self.assertEqual([2, 2], second.read_sizes)
        self.assertEqual([17, 17], [item[1] for item in requests])
        self.assertEqual(6, downloader.MAX_ATTEMPTS)

    def test_artifact_downloader_restarts_when_range_is_ignored(self) -> None:
        response = FakeResponse(200, {"Content-Length": "5"}, [b"fresh", b""])
        requests = []

        def open_response(request, *, timeout):
            requests.append(request)
            return response

        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "artifact"
            destination.with_name("artifact.part").write_bytes(b"old")
            downloader.download_verified_artifact(
                "https://example.invalid/artifact",
                hashlib.sha256(b"fresh").hexdigest(),
                destination,
                attempts=1,
                opener=open_response,
            )
            self.assertEqual(b"fresh", destination.read_bytes())
        self.assertEqual("bytes=3-", requests[0].get_header("Range"))

    def test_artifact_downloader_never_publishes_hash_invalid_data(self) -> None:
        responses = iter((
            FakeResponse(200, {"Content-Length": "3"}, [b"bad", b""]),
            FakeResponse(200, {"Content-Length": "3"}, [b"bad", b""]),
        ))
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "artifact"
            with self.assertRaises(downloader.DownloadError):
                downloader.download_verified_artifact(
                    "https://example.invalid/artifact",
                    hashlib.sha256(b"good").hexdigest(),
                    destination,
                    attempts=2,
                    backoff_base=0,
                    opener=lambda _request, *, timeout: next(responses),
                    sleeper=lambda _delay: None,
                )
            self.assertFalse(destination.exists())
            self.assertFalse(destination.with_name("artifact.part").exists())
        dockerfile = (TOOLING / "Dockerfile").read_text()
        self.assertLess(
            dockerfile.index("download_verified_artifact("),
            dockerfile.index("runtime.extract_tar_safely("),
        )

    def test_non_posix_parent_fsync_is_noop_and_verified_download_is_published(self) -> None:
        response = FakeResponse(200, {"Content-Length": "4"}, [b"good", b""])
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "artifact"
            with (
                mock.patch.object(downloader.os, "name", "nt"),
                mock.patch.object(downloader.os, "open") as open_mock,
            ):
                downloader.download_verified_artifact(
                    "https://example.invalid/artifact",
                    hashlib.sha256(b"good").hexdigest(),
                    destination,
                    attempts=1,
                    opener=lambda _request, *, timeout: response,
                )
            open_mock.assert_not_called()
            self.assertEqual(b"good", destination.read_bytes())

    def test_posix_parent_fsync_opens_syncs_and_closes(self) -> None:
        destination = Path("root") / "artifact"
        expected_flags = downloader.os.O_RDONLY
        if hasattr(downloader.os, "O_DIRECTORY"):
            expected_flags |= downloader.os.O_DIRECTORY
        with (
            mock.patch.object(downloader.os, "name", "posix"),
            mock.patch.object(downloader.os, "open", return_value=41) as open_mock,
            mock.patch.object(downloader.os, "fsync") as fsync_mock,
            mock.patch.object(downloader.os, "close") as close_mock,
        ):
            downloader.fsync_parent_directory(destination)
        open_mock.assert_called_once_with(destination.parent, expected_flags)
        fsync_mock.assert_called_once_with(41)
        close_mock.assert_called_once_with(41)

    def test_posix_parent_fsync_failure_propagates_and_closes(self) -> None:
        destination = Path("root") / "artifact"
        failure = OSError("fsync failed")
        with (
            mock.patch.object(downloader.os, "name", "posix"),
            mock.patch.object(downloader.os, "open", return_value=42),
            mock.patch.object(downloader.os, "fsync", side_effect=failure),
            mock.patch.object(downloader.os, "close") as close_mock,
            self.assertRaisesRegex(OSError, "fsync failed"),
        ):
            downloader.fsync_parent_directory(destination)
        close_mock.assert_called_once_with(42)

    def test_pses_and_psscriptanalyzer_layout_contract(self) -> None:
        dockerfile = (TOOLING / "Dockerfile").read_text()
        self.assertIn('ps_root = static / "PowerShellLanguageServer/powershell"', dockerfile)
        self.assertNotIn('unzip(archives["powershell-editor-services"], pses)', dockerfile)
        self.assertIn("duplicated PSES extraction layout", dockerfile)
        for relative in ("PSScriptAnalyzer.psd1", "PSScriptAnalyzer.psm1", "PSv7/Microsoft.Windows.PowerShell.ScriptAnalyzer.dll"):
            self.assertIn(relative, dockerfile)

    def test_archive_member_rejects_traversal_windows_and_backslash(self) -> None:
        for value in ("../escape", "/etc/passwd", "C:/Windows/file", "dir\\file", "a/../b", "bad\x00name"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                runtime.validate_archive_member_name(value)

    def test_zip_symlink_and_unknown_special_type_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            data = io.BytesIO()
            with zipfile.ZipFile(data, "w") as archive:
                info = zipfile.ZipInfo("link")
                info.create_system = 3; info.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(info, "target")
            with self.assertRaises(ValueError):
                runtime.extract_zip_safely(data.getvalue(), destination)

    def test_tar_symlink_fifo_device_and_unknown_types_are_rejected(self) -> None:
        for member_type in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE, tarfile.BLKTYPE):
            data = io.BytesIO()
            with tarfile.open(fileobj=data, mode="w") as archive:
                info = tarfile.TarInfo("unsafe")
                info.type = member_type; info.size = 0
                archive.addfile(info)
            with tempfile.TemporaryDirectory() as temporary, self.subTest(member_type=member_type), self.assertRaises(ValueError):
                runtime.extract_tar_safely(data.getvalue(), Path(temporary), "r:")

    @unittest.skipUnless(os.name == "posix", "descriptor-relative canonical installer is Linux-only")
    def test_matching_canonical_file_is_timestamp_stable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary); target = parent / "project.yml"; target.write_bytes(b"same\n")
            os.chmod(target, 0o444); before = target.stat()
            changed = runtime.install_canonical_file(parent, target.name, b"same\n", os.getuid(), os.getgid(), 0o444)
            after = target.stat()
            self.assertFalse(changed); self.assertEqual((before.st_mtime_ns, before.st_ctime_ns), (after.st_mtime_ns, after.st_ctime_ns))

    @unittest.skipUnless(os.name == "posix", "descriptor-relative canonical installer is Linux-only")
    def test_differing_canonical_file_is_atomically_replaced(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary); target = parent / "project.yml"; target.write_bytes(b"old\n")
            inode = target.stat().st_ino
            self.assertTrue(runtime.install_canonical_file(parent, target.name, b"new\n", os.getuid(), os.getgid(), 0o444))
            self.assertEqual(b"new\n", target.read_bytes()); self.assertNotEqual(inode, target.stat().st_ino)

    @unittest.skipUnless(os.name == "posix", "symlink/FIFO regression is Linux-only")
    def test_target_symlink_fifo_and_directory_are_rejected_without_external_change(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); external = root / "external"; external.write_bytes(b"external\n"); os.chmod(external, 0o444)
            before = (external.read_bytes(), external.stat().st_uid, external.stat().st_gid, stat.S_IMODE(external.stat().st_mode), external.stat().st_mtime_ns, external.stat().st_ctime_ns)
            for kind in ("symlink", "fifo", "directory"):
                parent = root / kind; parent.mkdir(); target = parent / "project.yml"
                if kind == "symlink": target.symlink_to(external)
                elif kind == "fifo": os.mkfifo(target)
                else: target.mkdir()
                with self.subTest(kind=kind), self.assertRaises(ValueError):
                    runtime.install_canonical_file(parent, target.name, b"new\n", os.getuid(), os.getgid(), 0o444)
            after = (external.read_bytes(), external.stat().st_uid, external.stat().st_gid, stat.S_IMODE(external.stat().st_mode), external.stat().st_mtime_ns, external.stat().st_ctime_ns)
            self.assertEqual(before, after)

    def test_resource_manifest_exactness_and_corruption_detection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); manifest, raw = make_resource_source(root)
            self.assertEqual(raw, runtime.canonical_json_bytes(json.loads(raw)))
            self.assertTrue(runtime.verify_resource_tree(root, manifest, include_manifest=True))
            payload = root / "language_servers/static/example/server"
            os.chmod(payload, 0o666)
            payload.write_bytes(b"corrupt\n")
            self.assertFalse(runtime.verify_resource_tree(root, manifest, include_manifest=True))

    def test_prompt_templates_fresh_initialization_uses_private_descriptor_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            directory_info = mock.Mock(st_mode=stat.S_IFDIR | 0o700)
            with contextlib.ExitStack() as stack:
                stack.enter_context(mock.patch.object(runtime.os, "lstat", side_effect=[state.stat(), directory_info]))
                mkdir_mock = stack.enter_context(mock.patch.object(runtime.os, "mkdir"))
                open_mock = stack.enter_context(mock.patch.object(runtime.os, "open", return_value=51))
                stack.enter_context(mock.patch.object(runtime.os, "fstat", return_value=directory_info))
                chown_mock = stack.enter_context(mock.patch.object(runtime.os, "fchown", create=True))
                chmod_mock = stack.enter_context(mock.patch.object(runtime.os, "fchmod", create=True))
                close_mock = stack.enter_context(mock.patch.object(runtime.os, "close"))
                stack.enter_context(mock.patch.object(runtime.os, "O_DIRECTORY", 0x10000, create=True))
                stack.enter_context(mock.patch.object(runtime, "O_NOFOLLOW", 0x20000))
                runtime.ensure_prompt_templates(state, 12001, 12002)
            target = state / "prompt_templates"
            mkdir_mock.assert_called_once_with(target, 0o700)
            self.assertEqual(0x30000, open_mock.call_args.args[1] & 0x30000)
            chown_mock.assert_called_once_with(51, 12001, 12002)
            chmod_mock.assert_called_once_with(51, 0o700)
            close_mock.assert_called_once_with(51)

    def test_prompt_templates_idempotence_preserves_contents_and_repairs_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            target = state / "prompt_templates"
            target.mkdir()
            marker = target / "keep"
            marker.write_bytes(b"preserve")
            directory_info = mock.Mock(st_mode=stat.S_IFDIR | 0o755)
            with contextlib.ExitStack() as stack:
                stack.enter_context(mock.patch.object(runtime.os, "mkdir", side_effect=FileExistsError))
                stack.enter_context(mock.patch.object(runtime.os, "open", return_value=52))
                stack.enter_context(mock.patch.object(runtime.os, "fstat", return_value=directory_info))
                chown_mock = stack.enter_context(mock.patch.object(runtime.os, "fchown", create=True))
                chmod_mock = stack.enter_context(mock.patch.object(runtime.os, "fchmod", create=True))
                stack.enter_context(mock.patch.object(runtime.os, "close"))
                stack.enter_context(mock.patch.object(runtime.os, "O_DIRECTORY", 0x10000, create=True))
                stack.enter_context(mock.patch.object(runtime, "O_NOFOLLOW", 0x20000))
                runtime.ensure_prompt_templates(state, 13001, 13002)
            self.assertEqual(b"preserve", marker.read_bytes())
            chown_mock.assert_called_once_with(52, 13001, 13002)
            chmod_mock.assert_called_once_with(52, 0o700)

    def test_prompt_templates_posix_failures_propagate_and_close_descriptor(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            directory_info = mock.Mock(st_mode=stat.S_IFDIR | 0o700)
            for operation in ("open", "fchown", "fchmod"):
                with self.subTest(operation=operation), contextlib.ExitStack() as stack:
                    stack.enter_context(mock.patch.object(runtime.os, "lstat", side_effect=[state.stat(), directory_info]))
                    stack.enter_context(mock.patch.object(runtime.os, "mkdir", side_effect=FileExistsError))
                    open_mock = stack.enter_context(mock.patch.object(runtime.os, "open", return_value=53))
                    stack.enter_context(mock.patch.object(runtime.os, "fstat", return_value=directory_info))
                    chown_mock = stack.enter_context(mock.patch.object(runtime.os, "fchown", create=True))
                    chmod_mock = stack.enter_context(mock.patch.object(runtime.os, "fchmod", create=True))
                    close_mock = stack.enter_context(mock.patch.object(runtime.os, "close"))
                    stack.enter_context(mock.patch.object(runtime.os, "O_DIRECTORY", 0x10000, create=True))
                    stack.enter_context(mock.patch.object(runtime, "O_NOFOLLOW", 0x20000))
                    failure = OSError(f"{operation} failed")
                    if operation == "open":
                        open_mock.side_effect = failure
                        expected_error = RuntimeError
                        expected_message = "cannot safely open"
                    elif operation == "fchown":
                        chown_mock.side_effect = failure
                        expected_error = OSError
                        expected_message = "fchown failed"
                    else:
                        chmod_mock.side_effect = failure
                        expected_error = OSError
                        expected_message = "fchmod failed"
                    with self.assertRaisesRegex(expected_error, expected_message):
                        runtime.ensure_prompt_templates(state, 13501, 13502)
                    if operation == "open":
                        close_mock.assert_not_called()
                    else:
                        close_mock.assert_called_once_with(53)

    def test_prompt_templates_rejects_symlink_and_regular_file_without_external_change(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            state = Path(temporary)
            external = state.parent / f"{state.name}-external"
            external.write_bytes(b"outside")
            root_info = state.stat()
            for kind, unsafe_mode in (("symlink", stat.S_IFLNK | 0o777), ("file", stat.S_IFREG | 0o600)):
                with (
                    self.subTest(kind=kind),
                    mock.patch.object(runtime.os, "lstat", side_effect=[root_info, mock.Mock(st_mode=unsafe_mode)]),
                    mock.patch.object(runtime.os, "mkdir", side_effect=FileExistsError),
                    mock.patch.object(runtime.os, "open") as open_mock,
                    self.assertRaisesRegex(RuntimeError, "unsafe type"),
                ):
                    runtime.ensure_prompt_templates(state, 14001, 14002)
                open_mock.assert_not_called()
                self.assertEqual(b"outside", external.read_bytes())
            external.unlink()

    def test_serena_state_preparation_precedes_privilege_drop(self) -> None:
        order: list[str] = []
        with (
            mock.patch.object(runtime, "require_exact_mount"),
            mock.patch.object(runtime, "resolve_runtime_identity", return_value=(15001, 15002)),
            mock.patch.object(runtime, "prepare_serena", side_effect=lambda *_: order.append("prepare")),
            mock.patch.object(runtime, "drop_privileges", side_effect=lambda *_: order.append("drop")),
            mock.patch.object(runtime.os, "execvp", side_effect=lambda *_: order.append("exec")),
            mock.patch.object(runtime.sys, "argv", ["entrypoint", "serena", "--", "command"]),
        ):
            runtime.main()
        self.assertEqual(["prepare", "drop", "exec"], order)
        self.assertIn("ensure_prompt_templates(STATE, uid, gid)", __import__("inspect").getsource(runtime.prepare_serena))

    @unittest.skipUnless(os.name == "posix", "fcntl resource seeding is Linux-only")
    def test_resource_corruption_recovery_and_concurrent_seeding(self) -> None:
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(runtime.os, "chown", lambda *_: None), mock.patch.object(runtime.os, "fchown", lambda *_: None):
            base = Path(temporary); source = base / "source"; target = base / "target"; source.mkdir(); target.mkdir()
            manifest, raw = make_resource_source(source); identifier = hashlib.sha256(raw).hexdigest()
            errors: list[BaseException] = []
            def seed() -> None:
                try: runtime.seed_resources(source, target)
                except BaseException as exc: errors.append(exc)
            threads = [threading.Thread(target=seed) for _ in range(2)]
            [thread.start() for thread in threads]; [thread.join() for thread in threads]
            self.assertEqual([], errors)
            payload = target / "sets" / identifier / "language_servers/static/example/server"
            os.chmod(payload.parent, 0o755); os.chmod(payload, 0o644); payload.write_bytes(b"bad\n")
            runtime.seed_resources(source, target)
            self.assertTrue(runtime.verify_resource_tree(target / "sets" / identifier, manifest, include_manifest=True))

    def test_compose_named_volume_platform_mounts_and_capabilities(self) -> None:
        compose = parsed(TOOLING / "compose.yaml")
        self.assertEqual({"serena-state", "serena-resources", "graphify-output"}, set(compose["volumes"]))
        for service in compose["services"].values():
            self.assertEqual("linux/amd64", service["platform"])
            self.assertEqual(["ALL"], service["cap_drop"])
            self.assertEqual(".", service["build"]["context"])
            workspace = [mount for mount in service["volumes"] if mount.get("target") == "/workspace"]
            self.assertEqual(1, len(workspace))
            self.assertEqual(".", workspace[0]["source"])
        graphify_mount = next(item for item in compose["services"]["graphify"]["volumes"] if item["target"] == "/graphify-output")
        self.assertEqual({"type": "volume", "source": "graphify-output", "target": "/graphify-output", "read_only": False, "volume": {"nocopy": True}}, graphify_mount)
        self.assertNotIn("../../graphify-out", (TOOLING / "compose.yaml").read_text())
        runtime_text = (TOOLING / "runtime-entrypoint.py").read_text()
        for token in ("cap_last_cap", "PR_CAPBSET_DROP", "CAP_SETPCAP", "os.setgroups([])", "NoNewPrivs"):
            self.assertIn(token, runtime_text)

    def test_doctor_inventory_and_wrapper_parity(self) -> None:
        doctor = (TOOLING / "doctor.py").read_text()
        for check_id in ("network", "resource-manifest", "mcp-initialize", "mcp-allowlist", "persistent-no-write",
                         "powershell-semantic-smoke", "bash-semantic-smoke", "python-semantic-smoke"):
            self.assertIn(f'"{check_id}"', doctor)
        for family in ("bootstrap", "doctor", "graphify-build", "graphify-query", "graphify-report", "graphify-clean"):
            self.assertTrue((ROOT / f".ai/scripts/{family}.ps1").is_file())
            self.assertTrue((ROOT / f".ai/scripts/{family}.sh").is_file())
        self.assertIn("python3", (ROOT / "tests/e2e/test_ai_tooling_docker.sh").read_text())
        self.assertIn("--host-family powershell", (ROOT / "tests/e2e/test_ai_tooling_docker.ps1").read_text())

    def test_project_local_bootstrap_has_no_installer_dependency_and_preserves_index(self) -> None:
        for name in ("bootstrap.ps1", "bootstrap.sh"):
            text = (ROOT / ".ai/scripts" / name).read_text(encoding="utf-8").lower()
            for token in ("installers/", "installers\\", "codex-ai-tooling", "qbit-cli", "installer aggregate"):
                self.assertNotIn(token, text)
            self.assertIn("ls-files --stage", text)
        index = subprocess.run(["git", "ls-files", "--stage", "--", ".gitignore"], cwd=ROOT, check=True, text=True, capture_output=True).stdout.rstrip("\n")
        self.assertEqual(validate.AI_INDEX_ENTRY, index)


if __name__ == "__main__":
    unittest.main(verbosity=2)
