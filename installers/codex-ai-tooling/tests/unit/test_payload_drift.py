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
    installer_variants = {
        "Dockerfile",
        "README.md",
        "compose.yaml",
        "doctor.py",
        "graphify-runtime.py",
        "language-servers/package-lock.json",
        "language-servers/package.json",
        "runtime-entrypoint.py",
        "serena_config.yml",
        "versions.env",
    }
    excluded = {"__pycache__"}
    source_files = sorted(
        p for p in source_root.rglob("*") if p.is_file() and not any(part in excluded for part in p.parts)
    )
    target_files = sorted(p for p in target_root.rglob("*") if p.is_file())
    assert [p.relative_to(source_root).as_posix() for p in source_files] == [
        p.relative_to(target_root).as_posix() for p in target_files
    ]
    for source in source_files:
        relative = source.relative_to(source_root).as_posix()
        target = target_root / relative
        if relative not in installer_variants:
            assert digest(source) == digest(target), relative

    compose = (target_root / "compose.yaml").read_text(encoding="utf-8")
    doctor = (target_root / "doctor.py").read_text(encoding="utf-8")
    graphify = (target_root / "graphify-runtime.py").read_text(encoding="utf-8")
    versions = (target_root / "versions.env").read_text(encoding="utf-8")
    template = lambda name: "{" * 2 + name + "}" * 2
    assert template("DOCKER_IMAGE_NAME") in compose and template("COMPOSE_PROJECT_NAME") in compose
    assert "ai-tooling:" in compose and 'user: "10001:10001"' in compose
    assert '"typescript": "5.9.3"' in doctor and 'rustc 1.85.0 ' in doctor
    assert "normalize_scope" in graphify and 'verb == "ensure"' in graphify
    assert "TYPESCRIPT_VERSION=5.9.3" in versions
    assert "RUST_TOOLCHAIN_VERSION=1.85.0" in versions


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
    assert '[mcp_servers.sentry]' in config
    for sentry_tool in ("find_organizations", "find_projects", "get_sentry_resource", "search_events", "search_issues"):
        assert config.count(f'"{sentry_tool}"') == 1
    for tool in allowlist:
        assert config.count(f'"{tool}"') >= 1
    assert "read_only: true" in compose
    assert "network_mode: none" in compose
    assert "cap_drop:\n      - ALL" in compose
    assert "source: .\n        target: /workspace\n        read_only: true" in compose
    assert "PYTHON_IMAGE=python:3.13.14-slim-trixie@sha256:afe189875f1d2f9b45e287834fb9f2c273a5d59d354ae4050ab9affbf0a6ba06" in versions
    assert "NODE_IMAGE=node:24.18.0-trixie-slim@sha256:5301bbf5e8046148348b1dea15436326f43c579031f8d76654a631225bdfe467" in versions
    assert "TYPESCRIPT_VERSION=5.9.3" in versions
    assert "TYPESCRIPT_LANGUAGE_SERVER_VERSION=5.1.3" in versions
    assert "RUST_TOOLCHAIN_VERSION=1.85.0" in versions
    assert "RUST_BASE_IMAGE=rust:1.85.0-slim-bookworm@sha256:c842cc0357b91bb15ad2bb89934513d0d226f711fac7f7fedb176d3311714d47" in versions
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
