#!/usr/bin/env python3
"""Scoped, injection-resistant Graphify lifecycle adapter."""
from __future__ import annotations

import fcntl
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys

WORKSPACE = Path("/workspace")
OUTPUT_ROOT = Path("/graphify-output")
IGNORED_DIRECTORY_NAMES = {".git", "node_modules", "target", "dist", "coverage", "graphify-out"}
IGNORED_RELATIVE_PREFIXES = (".ai/cache", ".ai/state")


def mounted(path: Path) -> bool:
    return any(
        line.split()[4].replace("\\040", " ") == str(path)
        for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines()
    )


def normalize_scope(raw: str) -> tuple[str, Path]:
    if not raw or "\\" in raw or "\x00" in raw:
        raise ValueError("Graphify scope must be a repository-relative POSIX path")
    candidate = PurePosixPath(raw)
    if candidate.is_absolute() or any(part in {"..", ""} for part in candidate.parts):
        raise ValueError("Graphify scope must not escape the repository")
    normalized = "." if raw in {".", "./"} or not candidate.parts else candidate.as_posix().removeprefix("./")
    target = WORKSPACE if normalized == "." else WORKSPACE.joinpath(*PurePosixPath(normalized).parts)
    current = WORKSPACE
    if normalized != ".":
        for component in PurePosixPath(normalized).parts:
            current = current / component
            info = os.lstat(current)
            if stat.S_ISLNK(info.st_mode):
                raise ValueError(f"Graphify scope contains a symlink: {normalized}")
    if not target.is_dir():
        raise ValueError(f"Graphify scope is not a directory: {normalized}")
    return normalized, target


def scope_identifier(scope: str) -> str:
    return "root" if scope == "." else hashlib.sha256(scope.encode("utf-8")).hexdigest()[:20]


def scope_paths(scope: str) -> tuple[Path, Path, Path, Path]:
    root = OUTPUT_ROOT / scope_identifier(scope)
    return root, root / "graph.json", root / "metadata.json", root / ".qbit-runtime.lock"


def run(argv: list[str], output: Path) -> None:
    subprocess.run(
        argv,
        cwd=WORKSPACE,
        check=True,
        env={
            **os.environ,
            "GRAPHIFY_OUT": str(output),
            "GRAPHIFY_NO_BACKUP": "1",
            "GRAPHIFY_QUERY_LOG_DISABLE": "1",
        },
    )


def _delete_children(directory_fd: int, *, preserve_lock: bool = False) -> None:
    for name in os.listdir(directory_fd):
        if preserve_lock and name == ".qbit-runtime.lock":
            continue
        info = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        if stat.S_ISDIR(info.st_mode):
            child_fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory_fd)
            try:
                _delete_children(child_fd)
            finally:
                os.close(child_fd)
            os.rmdir(name, dir_fd=directory_fd)
        elif stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode):
            os.unlink(name, dir_fd=directory_fd)
        else:
            raise RuntimeError(f"unsafe Graphify output entry: {name}")


def clean_output(output: Path) -> None:
    if not output.exists():
        return
    if not output.is_dir() or output.is_symlink():
        raise RuntimeError("Graphify scope output must be a real directory")
    root_fd = os.open(output, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        _delete_children(root_fd, preserve_lock=True)
        os.fsync(root_fd)
    finally:
        os.close(root_fd)


def should_ignore(relative: str, path: Path) -> bool:
    parts = PurePosixPath(relative).parts
    if any(part in IGNORED_DIRECTORY_NAMES for part in parts):
        return True
    if any(relative == prefix or relative.startswith(prefix + "/") for prefix in IGNORED_RELATIVE_PREFIXES):
        return True
    return path.is_symlink()


def fingerprint(scope_target: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(scope_target.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        workspace_relative = path.relative_to(WORKSPACE).as_posix()
        if should_ignore(workspace_relative, path):
            continue
        digest.update(workspace_relative.encode("utf-8") + b"\0")
        with path.open("rb") as stream:
            while chunk := stream.read(1024 * 1024):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def build_graph(scope: str, target: Path, output: Path, graph: Path) -> str:
    clean_output(output)
    run(["graphify", "extract", str(target), "--code-only", "--no-cluster"], output)
    run(["graphify", "cluster-only", str(target), "--graph", str(graph), "--no-label", "--no-viz"], output)
    if not graph.is_file() or graph.is_symlink():
        raise RuntimeError("Graphify did not produce graph.json")
    return fingerprint(target)


def ensure(scope: str, target: Path, output: Path, graph: Path, metadata: Path) -> str:
    current = fingerprint(target)
    if graph.is_file() and metadata.is_file() and not metadata.is_symlink():
        try:
            value = json.loads(metadata.read_text(encoding="utf-8"))
            if value == {"schemaVersion": 1, "scope": scope, "fingerprint": current}:
                return "reused"
        except (OSError, json.JSONDecodeError):
            pass
    built = build_graph(scope, target, output, graph)
    value = {"schemaVersion": 1, "scope": scope, "fingerprint": built}
    metadata.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    return "rebuilt"


def parse_scope(default: str = ".") -> tuple[str, Path]:
    return normalize_scope(sys.argv[2] if len(sys.argv) >= 3 else default)


def main() -> None:
    if OUTPUT_ROOT.resolve() != OUTPUT_ROOT or not mounted(OUTPUT_ROOT):
        raise RuntimeError("graphify output must be the exact nested mount")
    verb = sys.argv[1] if len(sys.argv) > 1 else ""
    if verb == "version" and len(sys.argv) == 2:
        print(importlib.metadata.version("graphifyy"))
        return

    # Compatibility: low-level build/report/clean without a scope still target the
    # repository root. Repository policy and public wrappers require explicit scope.
    if verb in {"build", "ensure", "report", "clean"}:
        if len(sys.argv) not in {2, 3}:
            raise SystemExit(f"usage: graphify-runtime.py {verb} [SCOPE]")
        scope, target = parse_scope()
        question = None
    elif verb == "query":
        if len(sys.argv) == 3:
            scope, target = normalize_scope(".")
            question = sys.argv[2]
        elif len(sys.argv) == 4:
            scope, target = normalize_scope(sys.argv[2])
            question = sys.argv[3]
        else:
            raise SystemExit("usage: graphify-runtime.py query [SCOPE] QUESTION")
    else:
        raise SystemExit("usage: graphify-runtime.py build|ensure|query|report|clean|version")

    output, graph, metadata, lock = scope_paths(scope)
    output.mkdir(parents=True, exist_ok=True)
    lock.touch(exist_ok=True)
    shared = verb in {"query", "report"}
    with lock.open("r+b") as stream:
        fcntl.flock(stream, fcntl.LOCK_SH if shared else fcntl.LOCK_EX)
        if verb == "build":
            built = build_graph(scope, target, output, graph)
            metadata.write_text(
                json.dumps({"schemaVersion": 1, "scope": scope, "fingerprint": built}, sort_keys=True, separators=(",", ":")) + "\n",
                encoding="utf-8",
            )
        elif verb == "ensure":
            print(ensure(scope, target, output, graph, metadata))
        elif verb == "query":
            if not graph.is_file():
                raise RuntimeError("Graphify scope has no graph; run ensure first")
            assert question is not None
            run(["graphify", "query", question, "--graph", str(graph), "--budget", "2000"], output)
        elif verb == "report":
            report = output / "GRAPH_REPORT.md"
            if not report.is_file():
                raise RuntimeError("Graphify scope has no report; run ensure first")
            sys.stdout.buffer.write(report.read_bytes())
        elif verb == "clean":
            clean_output(output)


if __name__ == "__main__":
    main()
