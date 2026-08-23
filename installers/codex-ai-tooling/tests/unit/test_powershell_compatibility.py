from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
INSTALLER = ROOT / "installers/codex-ai-tooling"
ROOT_BOOTSTRAP = ROOT / ".ai/scripts/bootstrap.ps1"
ROOT_DOCTOR = ROOT / ".ai/scripts/doctor.ps1"
TEMPLATE_BOOTSTRAP = INSTALLER / "templates/common/.ai/scripts/bootstrap.ps1"
TEMPLATE_DOCTOR = INSTALLER / "templates/common/.ai/scripts/doctor.ps1"
INSTALLER_LIBRARY = INSTALLER / "lib/installer.ps1"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_powershell_hashing_uses_dotnet_sha256() -> None:
    for path in (ROOT_BOOTSTRAP, TEMPLATE_BOOTSTRAP, INSTALLER_LIBRARY):
        text = read(path)
        assert "Get-FileHash" not in text, path
        assert "System.Security.Cryptography.SHA256" in text, path


def test_powershell_doctor_fails_closed_on_container_failure() -> None:
    for path in (ROOT_DOCTOR, TEMPLATE_DOCTOR):
        text = read(path)
        assert "$LASTEXITCODE -ne 0" in text, path
        assert "AI tooling Doctor reported a failed runtime check." in text, path


if __name__ == "__main__":
    tests = [
        test_powershell_hashing_uses_dotnet_sha256,
        test_powershell_doctor_fails_closed_on_container_failure,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
    print(f"RESULT passed={len(tests)} failed=0 skipped=0")
