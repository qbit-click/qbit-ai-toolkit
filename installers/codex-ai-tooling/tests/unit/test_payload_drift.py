from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
INSTALLER = ROOT / "installers/codex-ai-tooling"
PAYLOAD = INSTALLER / "templates/common"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_sync_manifest_is_valid() -> None:
    value = json.loads((INSTALLER / "payload-sync.json").read_text(encoding="utf-8"))
    assert value["schema_version"] == "1.0"
    assert {entry["copy_mode"] for entry in value["mappings"]} == {
        "byte-identical",
        "normalized-text",
        "parameterized-template",
        "installer-specific-wrapper",
        "intentionally-excluded",
    }


def test_byte_identical_mappings_have_no_drift() -> None:
    value = json.loads((INSTALLER / "payload-sync.json").read_text(encoding="utf-8"))
    for entry in value["mappings"]:
        if entry["copy_mode"] != "byte-identical":
            continue
        source = ROOT / entry["source_path"]
        target = INSTALLER / entry["payload_path"]
        source_files = [source] if source.is_file() else sorted(p for p in source.rglob("*") if p.is_file())
        target_files = [target] if target.is_file() else sorted(p for p in target.rglob("*") if p.is_file())
        source_rel = [p.name if source.is_file() else p.relative_to(source).as_posix() for p in source_files]
        target_rel = [p.name if target.is_file() else p.relative_to(target).as_posix() for p in target_files]
        assert source_rel == target_rel
        assert [digest(p) for p in source_files] == [digest(p) for p in target_files]


def test_runtime_drift_is_limited_to_declared_parameters() -> None:
    source_root = ROOT / ".ai/tooling"
    target_root = PAYLOAD / ".ai/tooling"
    parameterized = {
        "compose.yaml",
        "doctor.py",
        "runtime-entrypoint.py",
        "serena_config.yml",
    }
    normalized = {"README.md"}
    excluded = {"__pycache__"}
    source_files = sorted(
        p for p in source_root.rglob("*") if p.is_file() and not any(part in excluded for part in p.parts)
    )
    assert [p.relative_to(source_root).as_posix() for p in source_files] == [
        p.relative_to(target_root).as_posix() for p in sorted(p for p in target_root.rglob("*") if p.is_file())
    ]
    for source in source_files:
        relative = source.relative_to(source_root).as_posix()
        target = target_root / relative
        if relative in normalized:
            assert "{" * 2 + "SERENA_PROJECT_NAME" + "}" * 2 in target.read_text(encoding="utf-8")
            continue
        if relative not in parameterized:
            assert digest(source) == digest(target), relative
            continue
        expected = source.read_text(encoding="utf-8")
        token = lambda name: "{" * 2 + name + "}" * 2
        expected = expected.replace("qbit-ai-toolkit-ai-runtime:phase2a", token("DOCKER_IMAGE_NAME"))
        expected = expected.replace("qbit-ai-toolkit-ai", token("COMPOSE_PROJECT_NAME"))
        expected = expected.replace("qbit-ai-toolkit", token("SERENA_PROJECT_NAME"))
        assert target.read_text(encoding="utf-8") == expected, relative


def test_security_and_capability_contract() -> None:
    config = (PAYLOAD / ".codex/config.toml").read_text(encoding="utf-8")
    compose = (PAYLOAD / ".ai/tooling/compose.yaml").read_text(encoding="utf-8")
    versions = (PAYLOAD / ".ai/tooling/versions.env").read_text(encoding="utf-8")
    requirements_in = PAYLOAD / ".ai/tooling/python/requirements.in"
    requirements_lock = PAYLOAD / ".ai/tooling/python/requirements.lock"
    allowlist = [
        "get_symbols_overview",
        "find_symbol",
        "find_referencing_symbols",
        "find_implementations",
        "find_declaration",
        "get_diagnostics_for_file",
        "get_diagnostics_for_symbol",
        "replace_symbol_body",
        "insert_after_symbol",
        "insert_before_symbol",
        "rename_symbol",
        "safe_delete_symbol",
    ]
    assert 'mcp_servers.graphify' not in config
    assert 'mcp_servers.playwright' not in config
    assert "sentry" not in config.lower()
    for tool in allowlist:
        assert config.count(f'"{tool}"') == 1
    assert "read_only: true" in compose
    assert "network_mode: none" in compose
    assert "cap_drop:\n      - ALL" in compose
    assert "source: .\n        target: /workspace\n        read_only: true" in compose
    assert "PYTHON_IMAGE=python:3.13.14-slim-trixie@sha256:afe189875f1d2f9b45e287834fb9f2c273a5d59d354ae4050ab9affbf0a6ba06" in versions
    assert "NODE_IMAGE=node:24.18.0-trixie-slim@sha256:5301bbf5e8046148348b1dea15436326f43c579031f8d76654a631225bdfe467" in versions
    assert digest(requirements_in) == "9cf619d2a81e2ff3cc59d211ed7fb2ae14b058ccb362914a08043352d30e5eb0"
    assert digest(requirements_lock) == "df2ef4ae7599178eddeb53f2e1f378dfecfb668411309c6a5a980e330e83bca1"


if __name__ == "__main__":
    tests = [
        test_sync_manifest_is_valid,
        test_byte_identical_mappings_have_no_drift,
        test_runtime_drift_is_limited_to_declared_parameters,
        test_security_and_capability_contract,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
    print(f"RESULT passed={len(tests)} failed=0 skipped=0")
