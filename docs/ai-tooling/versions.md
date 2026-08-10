---
title: AI tooling versions
sidebar_label: Versions
---

# AI tooling versions

The project-local Phase 2 runtime uses immutable version pins. A pinned version means the source contract is defined; it does **not** by itself mean the runtime has passed the current revision's Docker/Doctor/semantic validation gates.

| Component | Version/source |
| --- | --- |
| Runtime platform | `linux/amd64` |
| Python image | `python:3.13.14-slim-trixie`, pinned by digest |
| Node build image | `node:24.18.0-trixie-slim`, pinned by digest |
| Serena | `serena-agent==1.5.3`, hashed Python lock |
| Graphify | `graphifyy==0.9.12`, hashed Python lock |
| PowerShell | `7.6.4`, SHA-256 locked artifact |
| PowerShell Editor Services | `4.4.0`, SHA-256 locked artifact |
| PSScriptAnalyzer | `1.25.0`, SHA-256 locked artifact |
| ShellCheck | `0.10.0`, SHA-256 locked artifact |
| Pyright | `1.1.403`, npm lock integrity |
| Bash Language Server | `5.6.0`, npm lock integrity |
| Debian runtime libraries | snapshot `20260720T000000Z`, per-package SHA-256 lock |

The authoritative pins and artifact metadata are stored in `.ai/tooling/versions.env`, `.ai/tooling/serena-artifacts.lock`, `.ai/tooling/debian-trixie-amd64.lock`, the hashed Python lock, and the npm lockfile.

Versions must never float in release-defining configuration. Updating a pin requires corresponding contract and validation updates.
