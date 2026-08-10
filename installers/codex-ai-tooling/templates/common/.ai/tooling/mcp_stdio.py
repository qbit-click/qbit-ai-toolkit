#!/usr/bin/env python3
"""Bounded byte-oriented JSON-RPC client for Serena's stdio transport."""
from __future__ import annotations

import json
import queue
import subprocess
import threading
import time
from typing import Any, BinaryIO, Mapping, Sequence

MAX_MESSAGE_BYTES = 16 * 1024 * 1024


class MCPProtocolError(RuntimeError):
    """Raised when an MCP stdio frame is malformed or incomplete."""


def _decode_message(payload: bytes) -> dict[str, Any]:
    if len(payload) > MAX_MESSAGE_BYTES:
        raise MCPProtocolError("MCP message exceeds size limit")
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise MCPProtocolError(f"invalid UTF-8 JSON-RPC message: {exc}") from exc
    if not isinstance(value, dict) or value.get("jsonrpc") != "2.0":
        raise MCPProtocolError("MCP message is not a JSON-RPC 2.0 object")
    return value


def _read_exact(stream: BinaryIO, length: int) -> bytes:
    chunks: list[bytes] = []
    remaining = length
    while remaining:
        chunk = stream.read(remaining)
        if not chunk:
            raise MCPProtocolError(
                f"truncated MCP frame: expected {length} bytes, received {length - remaining}"
            )
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def read_mcp_message(stream: BinaryIO) -> dict[str, Any]:
    """Read one Serena message, accepting its NDJSON output and framed MCP output."""
    while True:
        first_line = stream.readline()
        if not first_line:
            raise EOFError("MCP stdout closed")
        stripped = first_line.strip()
        if not stripped:
            continue

        if stripped.lower().startswith(b"content-length:"):
            try:
                length = int(stripped.split(b":", 1)[1].strip())
            except (ValueError, IndexError) as exc:
                raise MCPProtocolError("invalid Content-Length header") from exc
            if length <= 0 or length > MAX_MESSAGE_BYTES:
                raise MCPProtocolError("invalid Content-Length value")
            while True:
                header = stream.readline()
                if not header:
                    raise MCPProtocolError("truncated MCP headers")
                if header in (b"\n", b"\r\n"):
                    break
                if b":" not in header:
                    raise MCPProtocolError("malformed MCP header")
            return _decode_message(_read_exact(stream, length))

        try:
            return _decode_message(stripped)
        except MCPProtocolError as exc:
            # Serena may emit human-readable startup diagnostics on stdout.
            # JSON-shaped or protocol-shaped lines are never treated as diagnostics.
            if stripped.startswith((b"{", b"[")) or b"jsonrpc" in stripped.lower():
                raise
            try:
                stripped.decode("utf-8")
            except UnicodeDecodeError:
                raise exc


class MCPClient:
    """Subprocess-backed MCP client with bounded reads and continuously drained stderr."""

    def __init__(
        self,
        argv: Sequence[str],
        *,
        cwd: str,
        env: Mapping[str, str] | None = None,
    ) -> None:
        self.argv = list(argv)
        self.cwd = cwd
        self.env = dict(env) if env is not None else None
        self.process: subprocess.Popen[bytes] | None = None
        self.next_id = 1
        self._events: queue.Queue[tuple[str, Any]] = queue.Queue()
        self._stderr = bytearray()
        self._stderr_lock = threading.Lock()
        self._stdout_thread: threading.Thread | None = None
        self._stderr_thread: threading.Thread | None = None

    def start(self) -> None:
        if self.process is not None:
            raise RuntimeError("MCP process already started")
        self.process = subprocess.Popen(
            self.argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
            cwd=self.cwd,
            env=self.env,
        )
        self._stdout_thread = threading.Thread(target=self._capture_stdout, daemon=True)
        self._stderr_thread = threading.Thread(target=self._capture_stderr, daemon=True)
        self._stdout_thread.start()
        self._stderr_thread.start()

    def _capture_stdout(self) -> None:
        assert self.process is not None and self.process.stdout is not None
        try:
            while True:
                self._events.put(("message", read_mcp_message(self.process.stdout)))
        except BaseException as exc:  # noqa: BLE001
            self._events.put(("error", exc))

    def _capture_stderr(self) -> None:
        assert self.process is not None and self.process.stderr is not None
        while True:
            chunk = self.process.stderr.read(4096)
            if not chunk:
                return
            with self._stderr_lock:
                self._stderr.extend(chunk)
                if len(self._stderr) > 65536:
                    del self._stderr[:-65536]

    def stderr_tail(self) -> str:
        with self._stderr_lock:
            return bytes(self._stderr[-5000:]).decode("utf-8", errors="replace")

    def send(self, value: dict[str, Any]) -> None:
        if self.process is None or self.process.stdin is None:
            raise RuntimeError("MCP process is not started")
        payload = json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.process.stdin.write(payload + b"\n")
        self.process.stdin.flush()

    def send_request(self, method: str, params: dict[str, Any]) -> int:
        request_id = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        return request_id

    def receive(self, request_id: int, timeout: float = 60) -> Any:
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError(f"MCP request timed out: {request_id}")
            try:
                kind, value = self._events.get(timeout=remaining)
            except queue.Empty as exc:
                raise TimeoutError(f"MCP request timed out: {request_id}") from exc
            if kind == "error":
                if isinstance(value, EOFError):
                    code = self.process.poll() if self.process is not None else None
                    raise RuntimeError(
                        f"Serena MCP exited early ({code}): {self.stderr_tail()}"
                    ) from value
                raise value
            if value.get("id") != request_id:
                continue
            if "error" in value:
                raise RuntimeError(f"MCP request {request_id} failed: {value['error']}")
            if "result" not in value:
                raise MCPProtocolError(f"MCP response {request_id} has no result")
            return value["result"]

    def request(self, method: str, params: dict[str, Any], timeout: float = 60) -> Any:
        return self.receive(self.send_request(method, params), timeout)

    def close(self) -> None:
        process = self.process
        if process is None:
            return
        if process.stdin is not None:
            try:
                process.stdin.close()
            except OSError:
                pass
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        for stream in (process.stdout, process.stderr):
            if stream is not None:
                stream.close()
        for thread in (self._stdout_thread, self._stderr_thread):
            if thread is not None:
                thread.join(timeout=2)
