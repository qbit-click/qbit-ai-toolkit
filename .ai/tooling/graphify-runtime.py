#!/usr/bin/env python3
"""Fixed, injection-resistant Graphify command adapter."""
from __future__ import annotations
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import stat

WORKSPACE = Path("/workspace")
OUTPUT = Path("/graphify-output")
GRAPH = OUTPUT / "graph.json"
LOCK = OUTPUT / ".qbit-runtime.lock"


def mounted(path: Path) -> bool:
    return any(line.split()[4].replace("\\040", " ") == str(path)
               for line in Path("/proc/self/mountinfo").read_text().splitlines())


def run(argv: list[str]) -> None:
    subprocess.run(argv, cwd=WORKSPACE, check=True, env={**os.environ,
        "GRAPHIFY_OUT": str(OUTPUT), "GRAPHIFY_NO_BACKUP": "1", "GRAPHIFY_QUERY_LOG_DISABLE": "1"})


def _delete_children(directory_fd: int, *, preserve_lock: bool = False) -> None:
    for name in os.listdir(directory_fd):
        if preserve_lock and name == LOCK.name:
            continue
        info = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
        if stat.S_ISDIR(info.st_mode):
            child_fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory_fd)
            try:
                _delete_children(child_fd)
            finally:
                os.close(child_fd)
            os.rmdir(name, dir_fd=directory_fd)
        else:
            os.unlink(name, dir_fd=directory_fd)


def clean() -> None:
    if OUTPUT.resolve() != OUTPUT or not mounted(OUTPUT):
        raise RuntimeError("graphify output must be the exact nested mount")
    root_fd = os.open(OUTPUT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        opened = os.fstat(root_fd)
        expected = os.stat(OUTPUT, follow_symlinks=False)
        if not os.path.samestat(opened, expected):
            raise RuntimeError("graphify output changed while opening")
        _delete_children(root_fd, preserve_lock=True)
        os.fsync(root_fd)
    finally:
        os.close(root_fd)


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    LOCK.touch(exist_ok=True)
    verb = sys.argv[1] if len(sys.argv) > 1 else ""
    shared = verb in {"query", "report"}
    with LOCK.open("r+b") as stream:
        fcntl.flock(stream, fcntl.LOCK_SH if shared else fcntl.LOCK_EX)
        if verb == "build" and len(sys.argv) == 2:
            run(["graphify", "extract", str(WORKSPACE), "--code-only", "--no-cluster"])
            run(["graphify", "cluster-only", str(WORKSPACE), "--graph", str(GRAPH), "--no-label", "--no-viz"])
        elif verb == "query" and len(sys.argv) == 3:
            run(["graphify", "query", sys.argv[2], "--graph", str(GRAPH), "--budget", "2000"])
        elif verb == "report" and len(sys.argv) == 2:
            sys.stdout.buffer.write((OUTPUT / "GRAPH_REPORT.md").read_bytes())
        elif verb == "clean" and len(sys.argv) == 2:
            clean()
        else:
            raise SystemExit("usage: graphify-runtime.py build|query QUESTION|report|clean")


if __name__ == "__main__":
    main()
