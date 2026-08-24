#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run_git(root: Path | None, args: list[str], allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    command = ["git"] + (["-C", str(root)] if root is not None else []) + args
    cp = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if cp.returncode and not allow_failure:
        raise RuntimeError(f"Git command failed: git {' '.join(args)}")
    return cp


def normalize_remote(value: str, repo_root: Path) -> str:
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://", value):
        return value.rstrip("/")
    path = Path(value)
    if not path.is_absolute():
        path = repo_root / path
    return str(path.resolve()).rstrip("/\\")


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "start"
    if action not in {"start", "status", "checkpoint"}:
        raise RuntimeError("Action must be start, status, or checkpoint.")
    if shutil.which("git") is None:
        raise RuntimeError("Git is required for AI context lifecycle.")

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent.resolve()
    config_path = script_dir / "config.json"
    if not config_path.is_file():
        raise RuntimeError("AI context config is missing.")
    config = json.loads(config_path.read_text(encoding="utf-8-sig"))
    if int(config.get("schemaVersion", 0)) != 1:
        raise RuntimeError("Unsupported AI context config schemaVersion.")

    context = config.get("context") or {}
    configured_remote = str(context.get("remote") or "")
    branch = str(context.get("branch") or "")
    cache_relative = str(context.get("cachePath") or "")
    if not configured_remote or not branch or not cache_relative:
        raise RuntimeError("AI context config is incomplete.")
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://[^/]*@", configured_remote):
        raise RuntimeError("AI context remote URL must not embed credentials.")

    remote = normalize_remote(configured_remote, repo_root)
    cache_path = Path(cache_relative)
    if cache_path.is_absolute():
        raise RuntimeError("AI context cachePath must be repository-relative.")
    cache_path = (repo_root / cache_path).resolve()
    try:
        relative_cache = cache_path.relative_to(repo_root)
    except ValueError as exc:
        raise RuntimeError("AI context cachePath must remain inside the member repository.") from exc
    if not relative_cache.parts:
        raise RuntimeError("AI context cachePath must remain inside the member repository.")

    if not (cache_path / ".git").exists():
        if cache_path.exists() and any(cache_path.iterdir()):
            raise RuntimeError("AI context cache path exists but is not a Git repository.")
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        clone = run_git(None, ["clone", "--branch", branch, "--single-branch", "--", remote, str(cache_path)], True)
        if clone.returncode:
            raise RuntimeError("Unable to clone central AI context. Check Git authentication/network access.")
    else:
        actual_remote_raw = run_git(cache_path, ["remote", "get-url", "origin"]).stdout.strip()
        actual_remote = normalize_remote(actual_remote_raw, repo_root)
        actual_branch = run_git(cache_path, ["rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
        if actual_branch != branch:
            raise RuntimeError(f"AI context cache must remain on configured branch '{branch}'.")
        dirty = bool(run_git(cache_path, ["status", "--porcelain"]).stdout.strip())
        if actual_remote != remote:
            if dirty:
                raise RuntimeError("AI context cache origin differs from the configured central remote and the cache is dirty; automatic origin migration was refused.")
            run_git(cache_path, ["remote", "set-url", "origin", remote])
            fetched = run_git(cache_path, ["fetch", "origin", branch], True)
            if fetched.returncode:
                run_git(cache_path, ["remote", "set-url", "origin", actual_remote_raw], True)
                raise RuntimeError("AI context cache origin migration failed; the previous origin was restored.")
        else:
            run_git(cache_path, ["fetch", "origin", branch])

        dirty = bool(run_git(cache_path, ["status", "--porcelain"]).stdout.strip())
        if dirty:
            if action == "checkpoint":
                raise RuntimeError("Automated checkpoint refused because the AI context cache has pre-existing uncommitted changes.")
            print("WARNING: AI context cache is dirty; refresh skipped and local context will be loaded read-only.", file=sys.stderr)
        else:
            ff = run_git(cache_path, ["merge", "--ff-only", f"origin/{branch}"], True)
            if ff.returncode:
                if action == "checkpoint":
                    raise RuntimeError("AI context cache diverged from origin; automated checkpoint cannot continue safely.")
                print("WARNING: AI context cache diverged from origin; destructive synchronization was refused. Local context will be loaded read-only.", file=sys.stderr)

    tool_path = cache_path / "tooling" / "context-lifecycle.py"
    if not tool_path.is_file():
        raise RuntimeError("Central AI context POSIX tooling is missing. Refresh the central context repository.")
    cp = subprocess.run([sys.executable, str(tool_path), "--action", action, "--repository-root", str(repo_root), "--config-path", str(config_path)])
    return cp.returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(12)
