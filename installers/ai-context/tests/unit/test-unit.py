#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ai_context_installer", ROOT / "lib" / "installer.py")
assert SPEC and SPEC.loader
installer = importlib.util.module_from_spec(SPEC)
import sys
sys.modules[SPEC.name] = installer
SPEC.loader.exec_module(installer)


class AiContextPosixUnitTests(unittest.TestCase):
    def test_safe_id_and_branch_validation(self) -> None:
        self.assertEqual(installer.safe_id("demo-api", "RepositoryId"), "demo-api")
        with self.assertRaises(installer.InstallerError):
            installer.safe_id("../bad", "RepositoryId")
        self.assertEqual(installer.safe_branch("feature/demo-1",), "feature/demo-1")
        with self.assertRaises(installer.InstallerError):
            installer.safe_branch("../main")

    def test_remote_rejects_credentials_and_unsupported_url_scheme(self) -> None:
        self.assertEqual(installer.safe_remote("https://github.com/example/context.git"), "https://github.com/example/context.git")
        with self.assertRaises(installer.InstallerError):
            installer.safe_remote("https://token@github.com/example/context.git")
        with self.assertRaises(installer.InstallerError):
            installer.safe_remote("ssh://git@example.com/context.git")

    def test_safe_path_rejects_traversal_and_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            with self.assertRaises(installer.InstallerError):
                installer.safe_path(root, "../escape")
            target = root / "outside"
            target.mkdir()
            link = root / "link"
            try:
                link.symlink_to(target, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("symlink creation unavailable on this host")
            with self.assertRaises(installer.InstallerError):
                installer.safe_path(root, "link/file.txt")

    def test_managed_block_round_trip_preserves_outside_content(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "AGENTS.md"
            path.write_bytes(b"# User rules\n")
            block = installer.Block(installer.BLOCK_BEGIN, installer.BLOCK_END, "## Managed\n\nRule.\n")
            installer.set_block(path, block)
            info = installer.block_info(path, block)
            self.assertEqual(info["status"], "present")
            self.assertEqual(info["hash"], installer.text_hash("## Managed\n\nRule."))
            installer.remove_block(path, block)
            self.assertEqual(path.read_bytes(), b"# User rules\n")

    def test_managed_file_hash_normalizes_utf8_bom_and_line_endings(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lf = root / "lf.txt"
            crlf = root / "crlf.txt"
            bom = root / "bom.txt"
            lf.write_bytes(b"alpha\nbeta\n")
            crlf.write_bytes(b"alpha\r\nbeta\r\n")
            bom.write_bytes(b"\xef\xbb\xbfalpha\r\nbeta\r\n")
            expected = installer.text_hash("alpha\nbeta\n")
            self.assertEqual(installer.file_hash(lf), expected)
            self.assertEqual(installer.file_hash(crlf), expected)
            self.assertEqual(installer.file_hash(bom), expected)

    def test_state_identity_is_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            state_path = root / installer.STATE_PATH
            state_path.parent.mkdir(parents=True)
            state_path.write_text(json.dumps({"schemaVersion": "1.0", "installerId": "wrong"}), encoding="utf-8")
            with self.assertRaises(installer.InstallerError) as caught:
                installer.read_state(root)
            self.assertEqual(caught.exception.code, 5)

    def test_member_spec_contains_both_platform_launchers(self) -> None:
        values = installer.values("demo", "Demo", "demo-api", "demo-ai-context", "https://example.invalid/context.git", "main")
        spec = installer.new_spec("member", values)
        self.assertIn(".ai/context/context.ps1", spec.files)
        self.assertIn(".ai/context/context.sh", spec.files)
        self.assertIn(".ai/context/context.py", spec.files)
        self.assertIn("AGENTS.md", spec.blocks)

    def test_central_spec_contains_both_platform_lifecycle_tooling(self) -> None:
        values = installer.values("demo", "Demo", "demo-ai-context", "demo-ai-context", "https://example.invalid/context.git", "main")
        spec = installer.new_spec("central", values)
        self.assertIn("tooling/context-lifecycle.ps1", spec.files)
        self.assertIn("tooling/context-lifecycle.py", spec.files)
        self.assertIn("tests/context-lifecycle.tests.ps1", spec.files)
        self.assertIn("tests/context-lifecycle.tests.sh", spec.files)


if __name__ == "__main__":
    unittest.main(verbosity=2)
