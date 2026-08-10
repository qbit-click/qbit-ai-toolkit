"""Build-only streaming downloader for pinned, hash-verified artifacts."""

from __future__ import annotations

import hashlib
import http.client
import os
from pathlib import Path
import re
import socket
import time
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

MAX_ATTEMPTS = 6
TIMEOUT_SECONDS = 120
CHUNK_SIZE = 1024 * 1024
BACKOFF_BASE_SECONDS = 1.0
BACKOFF_CAP_SECONDS = 16.0
TRANSIENT_HTTP_STATUS = {408, 425, 429, 500, 502, 503, 504}
CONTENT_RANGE = re.compile(r"^bytes ([0-9]+)-([0-9]+)/([0-9]+|\*)$")


class DownloadError(RuntimeError):
    """A pinned artifact could not be downloaded and verified."""


class RetryableDownloadError(DownloadError):
    """A bounded retry may recover from this download failure."""


def _discard(path: Path) -> None:
    path.unlink(missing_ok=True)


def _header_length(headers: Any, name: str) -> int | None:
    value = headers.get(name)
    if value is None:
        return None
    try:
        result = int(value)
    except (TypeError, ValueError) as exc:
        raise RetryableDownloadError(f"invalid {name}: {value!r}") from exc
    if result < 0:
        raise RetryableDownloadError(f"negative {name}: {result}")
    return result


def _response_plan(response: Any, requested_offset: int) -> tuple[str, int | None, int | None]:
    status = int(response.status)
    content_length = _header_length(response.headers, "Content-Length")
    content_range = response.headers.get("Content-Range")

    if status == 200:
        # A server may ignore Range. Opening with wb restarts safely at byte zero.
        return "wb", content_length, content_length

    if status != 206:
        raise RetryableDownloadError(f"unexpected HTTP status: {status}")

    match = CONTENT_RANGE.fullmatch(content_range or "")
    if match is None:
        raise RetryableDownloadError(f"invalid Content-Range: {content_range!r}")
    start, end = int(match.group(1)), int(match.group(2))
    total = None if match.group(3) == "*" else int(match.group(3))
    if start != requested_offset or end < start:
        raise RetryableDownloadError(
            f"Content-Range does not resume requested offset {requested_offset}: {content_range}"
        )
    segment_length = end - start + 1
    if content_length is not None and content_length != segment_length:
        raise RetryableDownloadError("Content-Length disagrees with Content-Range")
    if total is not None and (end >= total or requested_offset > total):
        raise RetryableDownloadError("Content-Range total is inconsistent")
    return ("ab" if requested_offset else "wb"), segment_length, total


def _sha256(path: Path, chunk_size: int) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()


def fsync_parent_directory(destination: Path) -> None:
    if os.name != "posix":
        return

    flags = os.O_RDONLY
    if hasattr(os, "O_DIRECTORY"):
        flags |= os.O_DIRECTORY

    directory_fd = os.open(destination.parent, flags)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def download_verified_artifact(
    url: str,
    expected_sha256: str,
    destination: Path,
    *,
    attempts: int = MAX_ATTEMPTS,
    timeout: int = TIMEOUT_SECONDS,
    chunk_size: int = CHUNK_SIZE,
    backoff_base: float = BACKOFF_BASE_SECONDS,
    backoff_cap: float = BACKOFF_CAP_SECONDS,
    opener: Callable[..., Any] = urlopen,
    sleeper: Callable[[float], None] = time.sleep,
) -> Path:
    """Download to a .part file, verify length/hash, then atomically publish."""
    if attempts < 1 or timeout <= 0 or chunk_size < 1:
        raise ValueError("attempts, timeout, and chunk_size must be positive")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise ValueError("expected SHA-256 must be 64 lowercase hexadecimal characters")

    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + ".part")
    last_error: BaseException | None = None

    for attempt in range(1, attempts + 1):
        try:
            offset = partial.stat().st_size if partial.is_file() else 0
            request = Request(url, headers={"Range": f"bytes={offset}-"} if offset else {})
            with opener(request, timeout=timeout) as response:
                mode, expected_response_bytes, expected_total = _response_plan(response, offset)
                received = 0
                with partial.open(mode) as output:
                    while True:
                        try:
                            chunk = response.read(chunk_size)
                        except http.client.IncompleteRead as exc:
                            if exc.partial:
                                output.write(exc.partial)
                                received += len(exc.partial)
                            output.flush()
                            os.fsync(output.fileno())
                            raise RetryableDownloadError("HTTP response ended early") from exc
                        if not chunk:
                            break
                        output.write(chunk)
                        received += len(chunk)
                    output.flush()
                    os.fsync(output.fileno())

            actual_size = partial.stat().st_size
            if expected_response_bytes is not None and received != expected_response_bytes:
                raise RetryableDownloadError(
                    f"response was truncated: received {received}, expected {expected_response_bytes}"
                )
            if expected_total is not None and actual_size != expected_total:
                if actual_size > expected_total:
                    _discard(partial)
                raise RetryableDownloadError(
                    f"artifact was truncated: received {actual_size}, expected {expected_total}"
                )
            if _sha256(partial, chunk_size) != expected_sha256:
                _discard(partial)
                raise RetryableDownloadError("artifact SHA-256 mismatch")

            os.replace(partial, destination)
            fsync_parent_directory(destination)
            return destination
        except HTTPError as exc:
            if exc.code == 416:
                _discard(partial)
            elif exc.code not in TRANSIENT_HTTP_STATUS:
                _discard(partial)
                raise DownloadError(f"permanent HTTP failure {exc.code}: {url}") from exc
            last_error = exc
        except (
            RetryableDownloadError,
            http.client.IncompleteRead,
            socket.timeout,
            TimeoutError,
            ConnectionResetError,
            URLError,
        ) as exc:
            last_error = exc

        if attempt == attempts:
            _discard(partial)
            break
        sleeper(min(backoff_cap, backoff_base * (2 ** (attempt - 1))))

    raise DownloadError(f"artifact download failed after {attempts} attempts: {url}") from last_error
