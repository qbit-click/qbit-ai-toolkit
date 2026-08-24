#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=str(cwd) if cwd else None, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def new_repo(root: Path, name: str) -> Path:
    repo = root / name
    cp = run(["git", "init", "-b", "main", str(repo)])
    if cp.returncode:
        raise RuntimeError(cp.stdout)
    run(["git", "-C", str(repo), "config", "user.name", "Test"])
    run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"])
    (repo / "README.md").write_bytes(f"# {name}\n".encode())
    run(["git", "-C", str(repo), "add", "README.md"])
    cp = run(["git", "-C", str(repo), "commit", "-m", "init"])
    if cp.returncode:
        raise RuntimeError(cp.stdout)
    return repo


def normalized_state(path: Path) -> dict:
    state = json.loads(path.read_text(encoding="utf-8-sig"))
    state.pop("installedAtUtc", None)
    return state


class CrossPlatformParityTests(unittest.TestCase):
    def test_windows_and_posix_member_ownership_state_match(self) -> None:
        powershell = shutil.which("powershell") or shutil.which("pwsh")
        bash = shutil.which("bash")
        if not powershell or not bash:
            self.skipTest("PowerShell and Bash are both required for cross-platform parity validation")
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            win_repo = new_repo(root, "member-win")
            posix_repo = new_repo(root, "member-posix")
            common_ps = [
                "-Operation", "install", "-Mode", "member", "-ProjectId", "demo", "-ProjectDisplayName", "Demo",
                "-RepositoryId", "demo-api", "-ContextRemote", "https://example.invalid/demo-ai-context.git", "-ContextBranch", "main", "-Format", "json",
            ]
            cp = run([powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "install.ps1"), "-Target", str(win_repo), *common_ps])
            self.assertEqual(cp.returncode, 0, cp.stdout)
            cp = run([
                bash, str(ROOT / "install.sh"), "--operation", "install", "--mode", "member", "--target", str(posix_repo),
                "--project-id", "demo", "--project-display-name", "Demo", "--repository-id", "demo-api",
                "--context-remote", "https://example.invalid/demo-ai-context.git", "--context-branch", "main", "--format", "json",
            ])
            self.assertEqual(cp.returncode, 0, cp.stdout)
            win_state = normalized_state(win_repo / ".qbit/toolkit/installed/ai-context.json")
            posix_state = normalized_state(posix_repo / ".qbit/toolkit/installed/ai-context.json")
            self.assertEqual(win_state, posix_state)


if __name__ == "__main__":
    unittest.main(verbosity=2)
