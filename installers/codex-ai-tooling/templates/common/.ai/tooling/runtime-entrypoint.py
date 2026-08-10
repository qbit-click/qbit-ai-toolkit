#!/usr/bin/env python3
"""Security primitives and the sole root bootstrap for Serena and Graphify."""
from __future__ import annotations

import ctypes
import errno
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import uuid
import zipfile

try:  # Imported by Windows unit tests; runtime execution is Linux-only.
    import fcntl
except ImportError:  # pragma: no cover - Windows import path
    fcntl = None  # type: ignore[assignment]

WORKSPACE = Path("/workspace")
STATE = Path("/serena-state")
RESOURCES = Path("/serena-resources")
SOURCE = Path("/opt/qbit/serena-resources")
GLOBAL_SOURCE = Path("/opt/qbit/serena-config/serena_config.yml")
PROJECT_SOURCE = Path("/opt/qbit/serena-config/project.yml")
PROJECT_STATE = STATE / "projects/{{SERENA_PROJECT_NAME}}"
GRAPHIFY_OUTPUT = Path("/graphify-output")
RESOURCE_LINK_TARGET = "/serena-resources/current/language_servers"
CAP_SETPCAP = 8
PR_CAPBSET_DROP = 24
PR_SET_NO_NEW_PRIVS = 38
PR_CAP_AMBIENT = 47
PR_CAP_AMBIENT_CLEAR_ALL = 4
O_DIRECTORY = getattr(os, "O_DIRECTORY", 0)
O_NOFOLLOW = getattr(os, "O_NOFOLLOW", 0)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8") + b"\n"


def validate_archive_member_name(name: str) -> tuple[str, ...]:
    if not isinstance(name, str) or not name or "\x00" in name or "\\" in name:
        raise ValueError(f"unsafe archive member name: {name!r}")
    if re.match(r"^[A-Za-z]:", name) or name.startswith("/"):
        raise ValueError(f"absolute archive member rejected: {name!r}")
    path = PurePosixPath(name)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise ValueError(f"unsafe archive member path: {name!r}")
    return path.parts


def _open_dir(path: Path) -> int:
    return os.open(path, os.O_RDONLY | O_DIRECTORY | O_NOFOLLOW)


def _ensure_dir_chain(root_fd: int, parts: tuple[str, ...], mode: int = 0o755) -> int:
    current = os.dup(root_fd)
    try:
        for part in parts:
            try:
                os.mkdir(part, mode, dir_fd=current)
            except FileExistsError:
                info = os.stat(part, dir_fd=current, follow_symlinks=False)
                if not stat.S_ISDIR(info.st_mode):
                    raise ValueError(f"archive parent is not a directory: {part}")
            next_fd = os.open(part, os.O_RDONLY | O_DIRECTORY | O_NOFOLLOW, dir_fd=current)
            os.close(current)
            current = next_fd
        return current
    except BaseException:
        os.close(current)
        raise


def _write_archive_file(root_fd: int, parts: tuple[str, ...], source: io.BufferedIOBase) -> None:
    parent_fd = _ensure_dir_chain(root_fd, parts[:-1])
    try:
        fd = os.open(parts[-1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        try:
            while chunk := source.read(1024 * 1024):
                os.write(fd, chunk)
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)


def extract_zip_safely(data: bytes, destination: Path) -> None:
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        members: list[tuple[zipfile.ZipInfo, tuple[str, ...]]] = []
        for item in archive.infolist():
            parts = validate_archive_member_name(item.filename.rstrip("/") if item.is_dir() else item.filename)
            unix_mode = item.external_attr >> 16
            file_type = stat.S_IFMT(unix_mode)
            if item.is_dir() and file_type not in (0, stat.S_IFDIR):
                raise ValueError(f"unknown ZIP directory type: {item.filename}")
            if not item.is_dir() and file_type not in (0, stat.S_IFREG):
                raise ValueError(f"ZIP link or special file rejected: {item.filename}")
            members.append((item, parts))
        root_fd = _open_dir(destination)
        try:
            for item, parts in members:
                if item.is_dir():
                    fd = _ensure_dir_chain(root_fd, parts)
                    os.close(fd)
                else:
                    with archive.open(item, "r") as source:
                        _write_archive_file(root_fd, parts, source)
        finally:
            os.close(root_fd)


def extract_tar_safely(data: bytes, destination: Path, mode: str, strip_components: int = 0) -> None:
    with tarfile.open(fileobj=io.BytesIO(data), mode=mode) as archive:
        members: list[tuple[tarfile.TarInfo, tuple[str, ...]]] = []
        for item in archive:
            parts = validate_archive_member_name(item.name)
            if not (item.isdir() or item.isreg()):
                raise ValueError(f"TAR link or special file rejected: {item.name}")
            if len(parts) > strip_components:
                members.append((item, parts[strip_components:]))
        root_fd = _open_dir(destination)
        try:
            for item, parts in members:
                if item.isdir():
                    fd = _ensure_dir_chain(root_fd, parts)
                    os.close(fd)
                else:
                    source = archive.extractfile(item)
                    if source is None:
                        raise ValueError(f"TAR regular file has no content: {item.name}")
                    with source:
                        _write_archive_file(root_fd, parts, source)
        finally:
            os.close(root_fd)


def _write_all(fd: int, data: bytes) -> None:
    offset = 0
    while offset < len(data):
        offset += os.write(fd, data[offset:])


def install_canonical_file(parent: Path, name: str, data: bytes, uid: int, gid: int, mode: int) -> bool:
    """Install a protected regular file without following attacker-controlled entries.

    Returns True when replacement or metadata repair occurred, False only when the
    existing file already matched bytes, ownership, mode, and type exactly.
    """
    if not name or name in {".", ".."} or "/" in name or "\\" in name:
        raise ValueError("target must be one fixed basename")
    parent_lstat = os.lstat(parent)
    if not stat.S_ISDIR(parent_lstat.st_mode):
        raise ValueError(f"canonical parent is not a directory: {parent}")
    parent_fd = _open_dir(parent)
    temp_name: str | None = None
    try:
        opened_parent = os.fstat(parent_fd)
        if (opened_parent.st_dev, opened_parent.st_ino) != (parent_lstat.st_dev, parent_lstat.st_ino):
            raise ValueError("canonical parent changed while opening")
        try:
            existing = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            existing = None
        if existing is not None:
            if not stat.S_ISREG(existing.st_mode):
                raise ValueError(f"canonical target is not a regular file: {name}")
            fd = os.open(name, os.O_RDONLY | O_NOFOLLOW, dir_fd=parent_fd)
            try:
                opened = os.fstat(fd)
                if (opened.st_dev, opened.st_ino) != (existing.st_dev, existing.st_ino):
                    raise ValueError("canonical target changed while opening")
                current = bytearray()
                while chunk := os.read(fd, 1024 * 1024):
                    current.extend(chunk)
                exact = (bytes(current) == data and opened.st_uid == uid and opened.st_gid == gid
                         and stat.S_IMODE(opened.st_mode) == mode)
                if exact:
                    return False
            finally:
                os.close(fd)
        temp_name = f".{name}.tmp-{os.getpid()}-{uuid.uuid4().hex}"
        fd = os.open(temp_name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        try:
            _write_all(fd, data)
            os.fchmod(fd, mode)
            if hasattr(os, "fchown"):
                os.fchown(fd, uid, gid)
            os.fsync(fd)
        finally:
            os.close(fd)
        os.replace(temp_name, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        temp_name = None
        os.fsync(parent_fd)
        return True
    finally:
        if temp_name is not None:
            try:
                os.unlink(temp_name, dir_fd=parent_fd)
            except FileNotFoundError:
                pass
        os.close(parent_fd)


def _decode_mount_path(value: str) -> str:
    return re.sub(r"\\([0-7]{3})", lambda match: chr(int(match.group(1), 8)), value)


def mount_table() -> dict[str, dict[str, object]]:
    table: dict[str, dict[str, object]] = {}
    for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
        fields = line.split()
        separator = fields.index("-")
        path = _decode_mount_path(fields[4])
        options = set(fields[5].split(",")) | set(fields[separator + 3].split(","))
        table[path] = {"options": options, "fs_type": fields[separator + 1], "source": fields[separator + 2]}
    return table


def require_exact_mount(path: Path, *, read_only: bool | None = None) -> dict[str, object]:
    if stat.S_ISLNK(os.lstat(path).st_mode):
        raise RuntimeError(f"mountpoint must not be a symlink: {path}")
    record = mount_table().get(str(path))
    if record is None:
        raise RuntimeError(f"required exact mount is absent: {path}")
    options = record["options"]
    assert isinstance(options, set)
    if read_only is True and "ro" not in options:
        raise RuntimeError(f"mount must be read-only: {path}")
    if read_only is False and "rw" not in options:
        raise RuntimeError(f"mount must be read-write: {path}")
    return record


def load_resource_manifest(source: Path = SOURCE) -> tuple[dict[str, object], bytes, str]:
    raw = (source / "manifest.json").read_bytes()
    value = json.loads(raw)
    canonical = canonical_json_bytes(value)
    if raw != canonical:
        raise RuntimeError("resource manifest is not canonical JSON")
    if value.get("schemaVersion") != 1 or value.get("serenaVersion") != "1.5.3":
        raise RuntimeError("resource manifest version mismatch")
    return value, raw, sha256_bytes(raw)


def _entry_map(manifest: dict[str, object]) -> dict[str, dict[str, object]]:
    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise RuntimeError("resource manifest entries must be a list")
    result: dict[str, dict[str, object]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise RuntimeError("invalid resource manifest entry")
        path = str(entry["path"])
        validate_archive_member_name(path)
        if path in result:
            raise RuntimeError(f"duplicate resource manifest path: {path}")
        result[path] = entry
    return result


def verify_resource_tree(root: Path, manifest: dict[str, object], *, include_manifest: bool) -> bool:
    try:
        expected = _entry_map(manifest)
        actual_paths: set[str] = set()
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root).as_posix()
            if include_manifest and relative == "manifest.json":
                continue
            info = os.lstat(path)
            if stat.S_ISLNK(info.st_mode) or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
                return False
            actual_paths.add(relative)
            entry = expected.get(relative)
            if entry is None:
                return False
            kind = "directory" if stat.S_ISDIR(info.st_mode) else "file"
            if entry.get("type") != kind or entry.get("mode") != f"{stat.S_IMODE(info.st_mode):04o}":
                return False
            if kind == "directory":
                if entry.get("size") != 0 or entry.get("sha256") is not None:
                    return False
            else:
                data = path.read_bytes()
                if entry.get("size") != len(data) or entry.get("sha256") != sha256_bytes(data):
                    return False
        return actual_paths == set(expected)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError):
        return False


def _remove_dir_contents(fd: int) -> None:
    for name in os.listdir(fd):
        info = os.stat(name, dir_fd=fd, follow_symlinks=False)
        if stat.S_ISDIR(info.st_mode):
            child = os.open(name, os.O_RDONLY | O_DIRECTORY | O_NOFOLLOW, dir_fd=fd)
            try:
                _remove_dir_contents(child)
            finally:
                os.close(child)
            os.rmdir(name, dir_fd=fd)
        elif stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode):
            os.unlink(name, dir_fd=fd)
        else:
            raise RuntimeError(f"unsafe special entry while deleting: {name}")


def _delete_child_tree(parent: Path, name: str) -> None:
    parent_fd = _open_dir(parent)
    try:
        info = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        if not stat.S_ISDIR(info.st_mode):
            raise RuntimeError(f"refusing to recurse into unsafe resource set: {name}")
        child = os.open(name, os.O_RDONLY | O_DIRECTORY | O_NOFOLLOW, dir_fd=parent_fd)
        try:
            _remove_dir_contents(child)
        finally:
            os.close(child)
        os.rmdir(name, dir_fd=parent_fd)
        os.fsync(parent_fd)
    finally:
        os.close(parent_fd)


def _copy_manifest_resources(source: Path, destination: Path, manifest: dict[str, object], manifest_bytes: bytes) -> None:
    destination.mkdir(mode=0o755)
    for relative, entry in sorted(_entry_map(manifest).items()):
        target = destination / relative
        kind = entry["type"]
        if kind == "directory":
            target.mkdir(parents=True, exist_ok=True)
            os.chmod(target, int(str(entry["mode"]), 8))
        elif kind == "file":
            source_path = source / relative
            if stat.S_ISLNK(os.lstat(source_path).st_mode):
                raise RuntimeError(f"immutable source symlink rejected: {relative}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with source_path.open("rb") as src, target.open("xb") as dst:
                shutil.copyfileobj(src, dst)
                dst.flush(); os.fsync(dst.fileno())
            os.chmod(target, int(str(entry["mode"]), 8))
        else:
            raise RuntimeError(f"unsupported manifest type: {kind}")
    (destination / "manifest.json").write_bytes(manifest_bytes)
    os.chmod(destination / "manifest.json", 0o444)
    os.chmod(destination, 0o555)


def seed_resources(source: Path = SOURCE, target: Path = RESOURCES) -> str:
    if fcntl is None:
        raise RuntimeError("resource seeding requires POSIX fcntl")
    manifest, manifest_bytes, identifier = load_resource_manifest(source)
    if not verify_resource_tree(source, manifest, include_manifest=True):
        raise RuntimeError("immutable image resource tree does not match manifest")
    os.chown(target, 0, 0); os.chmod(target, 0o755)
    sets = target / "sets"; sets.mkdir(mode=0o755, exist_ok=True)
    os.chown(sets, 0, 0); os.chmod(sets, 0o755)
    lock = target / ".seed.lock"
    lock_fd = os.open(lock, os.O_RDWR | os.O_CREAT | O_NOFOLLOW, 0o600)
    try:
        os.fchmod(lock_fd, 0o600); os.fchown(lock_fd, 0, 0)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        destination = sets / identifier
        try:
            destination_info = os.lstat(destination)
            destination_exists = True
        except FileNotFoundError:
            destination_info = None
            destination_exists = False
        if destination_exists and not stat.S_ISDIR(destination_info.st_mode):
            raise RuntimeError("resource set path is not a real directory")
        try:
            destination_manifest_matches = destination_exists and (destination / "manifest.json").read_bytes() == manifest_bytes
        except (FileNotFoundError, IsADirectoryError, OSError):
            destination_manifest_matches = False
        valid = bool(destination_manifest_matches and verify_resource_tree(destination, manifest, include_manifest=True))
        if destination_exists and not valid:
            quarantine = f".corrupt-{identifier}-{uuid.uuid4().hex}"
            sets_fd = _open_dir(sets)
            try:
                os.replace(destination.name, quarantine, src_dir_fd=sets_fd, dst_dir_fd=sets_fd)
                os.fsync(sets_fd)
            finally:
                os.close(sets_fd)
            _delete_child_tree(sets, quarantine)
        if not valid:
            staging = sets / f".staging-{identifier}-{uuid.uuid4().hex}"
            try:
                _copy_manifest_resources(source, staging, manifest, manifest_bytes)
                os.replace(staging, destination)
            finally:
                if staging.exists():
                    _delete_child_tree(sets, staging.name)
        if not verify_resource_tree(destination, manifest, include_manifest=True):
            raise RuntimeError("seeded resource set failed verification")
        current = target / "current"
        if current.exists() or current.is_symlink():
            info = os.lstat(current)
            if not stat.S_ISLNK(info.st_mode):
                raise RuntimeError("resource current entry is not a symlink")
        temp = target / f".current-{uuid.uuid4().hex}"
        try:
            temp.symlink_to(f"sets/{identifier}", target_is_directory=True)
            os.replace(temp, current)
        finally:
            temp.unlink(missing_ok=True)
        return identifier
    finally:
        os.close(lock_fd)


def _ensure_directory(path: Path, uid: int, gid: int, mode: int) -> None:
    try:
        info = os.lstat(path)
        if not stat.S_ISDIR(info.st_mode):
            raise RuntimeError(f"protected directory has unsafe type: {path}")
    except FileNotFoundError:
        path.mkdir()
    os.chown(path, uid, gid); os.chmod(path, mode)


def ensure_prompt_templates(state_root: Path, uid: int, gid: int) -> None:
    root_info = os.lstat(state_root)
    if not stat.S_ISDIR(root_info.st_mode):
        raise RuntimeError(f"Serena state root has unsafe type: {state_root}")
    target = state_root / "prompt_templates"
    try:
        os.mkdir(target, 0o700)
    except FileExistsError:
        pass
    target_info = os.lstat(target)
    if not stat.S_ISDIR(target_info.st_mode):
        raise RuntimeError(f"protected directory has unsafe type: {target}")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | O_NOFOLLOW
    try:
        directory_fd = os.open(target, flags)
    except OSError as exc:
        raise RuntimeError(f"cannot safely open protected directory: {target}") from exc
    try:
        if not stat.S_ISDIR(os.fstat(directory_fd).st_mode):
            raise RuntimeError(f"protected directory changed type: {target}")
        os.fchown(directory_fd, uid, gid)
        os.fchmod(directory_fd, 0o700)
    finally:
        os.close(directory_fd)


def _install_resource_link() -> None:
    link = STATE / "language_servers"
    try:
        info = os.lstat(link)
        if not stat.S_ISLNK(info.st_mode):
            raise RuntimeError("protected language_servers entry is not a symlink")
        if os.readlink(link) == RESOURCE_LINK_TARGET and info.st_uid == 0 and info.st_gid == 0:
            return
        link.unlink()
    except FileNotFoundError:
        pass
    temp = STATE / f".language_servers-{uuid.uuid4().hex}"
    try:
        temp.symlink_to(RESOURCE_LINK_TARGET, target_is_directory=True)
        os.replace(temp, link)
        os.lchown(link, 0, 0)
    finally:
        temp.unlink(missing_ok=True)


def prepare_serena(uid: int, gid: int) -> None:
    if fcntl is None:
        raise RuntimeError("Serena bootstrap requires POSIX fcntl")
    require_exact_mount(STATE, read_only=False)
    require_exact_mount(RESOURCES, read_only=False)
    os.chown(STATE, 0, 0); os.chmod(STATE, 0o755)
    lock = STATE / ".bootstrap.lock"
    lock_fd = os.open(lock, os.O_RDWR | os.O_CREAT | O_NOFOLLOW, 0o600)
    try:
        os.fchmod(lock_fd, 0o600); os.fchown(lock_fd, 0, 0)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        seed_resources()
        _ensure_directory(STATE / "projects", 0, 0, 0o755)
        _ensure_directory(PROJECT_STATE, uid, gid, 0o755)
        for path in (STATE / "logs", STATE / "memories", STATE / "home", STATE / "xdg-cache"):
            _ensure_directory(path, uid, gid, 0o755)
        ensure_prompt_templates(STATE, uid, gid)
        install_canonical_file(STATE, "serena_config.yml", GLOBAL_SOURCE.read_bytes(), 0, 0, 0o444)
        install_canonical_file(PROJECT_STATE, "project.yml", PROJECT_SOURCE.read_bytes(), 0, 0, 0o444)
        _install_resource_link()
    finally:
        os.close(lock_fd)


def prepare_graphify(uid: int, gid: int) -> None:
    require_exact_mount(GRAPHIFY_OUTPUT, read_only=False)
    if stat.S_ISLNK(os.lstat(GRAPHIFY_OUTPUT).st_mode):
        raise RuntimeError("Graphify output mountpoint is a symlink")
    os.chown(GRAPHIFY_OUTPUT, uid, gid); os.chmod(GRAPHIFY_OUTPUT, 0o755)


def _prctl(libc: ctypes.CDLL, option: int, arg2: int = 0) -> None:
    ctypes.set_errno(0)
    result = libc.prctl(option, arg2, 0, 0, 0)
    if result != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, f"prctl({option}, {arg2}) failed")


def capability_status() -> dict[str, int]:
    values: dict[str, int] = {}
    for line in Path("/proc/self/status").read_text(encoding="utf-8").splitlines():
        key, _, value = line.partition(":")
        if key in {"CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb"}:
            values[key] = int(value.strip(), 16)
        elif key == "NoNewPrivs":
            values[key] = int(value.strip())
    return values


def drop_privileges(uid: int, gid: int) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    last_cap = int(Path("/proc/sys/kernel/cap_last_cap").read_text(encoding="ascii").strip())
    for capability in [value for value in range(last_cap + 1) if value != CAP_SETPCAP] + [CAP_SETPCAP]:
        _prctl(libc, PR_CAPBSET_DROP, capability)
    _prctl(libc, PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL)
    os.setgroups([])
    os.setgid(gid)
    os.setuid(uid)
    _prctl(libc, PR_SET_NO_NEW_PRIVS, 1)
    status = capability_status()
    for name in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb"):
        if status.get(name) != 0:
            raise RuntimeError(f"capability set was not cleared: {name}={status.get(name)}")
    if status.get("NoNewPrivs") != 1:
        raise RuntimeError("NoNewPrivs was not set")


def resolve_runtime_identity() -> tuple[int, int]:
    info = os.stat(WORKSPACE, follow_symlinks=False)
    return (info.st_uid if info.st_uid != 0 else 10001, info.st_gid if info.st_gid != 0 else 10001)


def main() -> None:
    if len(sys.argv) < 4 or sys.argv[2] != "--" or sys.argv[1] not in {"serena", "graphify"}:
        raise SystemExit("usage: runtime-entrypoint.py {serena|graphify} -- command [args...]")
    require_exact_mount(WORKSPACE, read_only=sys.argv[1] == "graphify")
    uid, gid = resolve_runtime_identity()
    if sys.argv[1] == "serena":
        prepare_serena(uid, gid)
    else:
        prepare_graphify(uid, gid)
    drop_privileges(uid, gid)
    if sys.argv[1] == "serena":
        os.environ.update(HOME=str(STATE / "home"), XDG_CACHE_HOME=str(STATE / "xdg-cache"), SERENA_HOME=str(STATE))
    else:
        os.environ.update(HOME="/tmp", XDG_CACHE_HOME="/tmp/cache")
    os.execvp(sys.argv[3], sys.argv[3:])


if __name__ == "__main__":
    main()
