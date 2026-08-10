# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e
ARG NODE_IMAGE=node:24.18.0-trixie-slim@sha256:5301bbf5e8046148348b1dea15436326f43c579031f8d76654a631225bdfe467
ARG PYTHON_IMAGE=python:3.13.14-slim-trixie@sha256:afe189875f1d2f9b45e287834fb9f2c273a5d59d354ae4050ab9affbf0a6ba06

FROM --platform=linux/amd64 ${NODE_IMAGE} AS language-servers
WORKDIR /opt/serena-language-servers
COPY .ai/tooling/language-servers/package.json .ai/tooling/language-servers/package-lock.json ./
RUN npm ci --ignore-scripts --omit=dev --no-audit --no-fund \
 && test "$(node -p "require('./node_modules/bash-language-server/package.json').version")" = "5.6.0" \
 && test "$(node -p "require('./node_modules/pyright/package.json').version")" = "1.1.403" \
 && npm cache clean --force

FROM --platform=linux/amd64 ${PYTHON_IMAGE}
ARG TARGETPLATFORM
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1 PYTHONDONTWRITEBYTECODE=1 \
    GRAPHIFY_OUT=/graphify-output GRAPHIFY_NO_BACKUP=1 GRAPHIFY_QUERY_LOG_DISABLE=1
RUN test "${TARGETPLATFORM}" = "linux/amd64"

COPY .ai/tooling/python/requirements.lock /tmp/requirements.lock
RUN python -m pip --retries 10 --timeout 120 install \
      --require-hashes --no-deps -r /tmp/requirements.lock \
 && rm -f /tmp/requirements.lock

COPY .ai/tooling/build-download.py /tmp/qbit-download.py
COPY .ai/tooling/debian-trixie-amd64.lock /tmp/debian.lock
RUN python - <<'PY'
from pathlib import Path
import importlib.util
import shutil
import subprocess

snapshot = "20260720T000000Z"
downloads = Path("/tmp/debs")
downloads.mkdir(mode=0o700)
download_spec = importlib.util.spec_from_file_location(
    "qbit_download",
    "/tmp/qbit-download.py",
)
downloader = importlib.util.module_from_spec(download_spec)
assert download_spec.loader is not None
download_spec.loader.exec_module(downloader)
verified_archives = []
try:
    for line in Path("/tmp/debian.lock").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        suite, name, version, pool_path, expected = line.split()
        archive = "debian-security" if suite == "security" else "debian"
        url = f"https://snapshot.debian.org/archive/{archive}/{snapshot}/{pool_path}"
        destination = downloads / Path(pool_path).name
        verified_archives.append(
            downloader.download_verified_artifact(url, expected, destination)
        )
    subprocess.run(["dpkg", "-i", *map(str, sorted(verified_archives))], check=True)
finally:
    shutil.rmtree(downloads, ignore_errors=True)
    Path("/tmp/debian.lock").unlink(missing_ok=True)
PY

COPY .ai/tooling/runtime-entrypoint.py /tmp/qbit-runtime.py
COPY .ai/tooling/serena-artifacts.lock /tmp/artifacts.lock
RUN python - <<'PY'
from pathlib import Path
import importlib.util

spec = importlib.util.spec_from_file_location("qbit_runtime", "/tmp/qbit-runtime.py")
runtime = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(runtime)

download_spec = importlib.util.spec_from_file_location("qbit_download", "/tmp/qbit-download.py")
downloader = importlib.util.module_from_spec(download_spec)
assert download_spec.loader is not None
download_spec.loader.exec_module(downloader)

downloads = Path("/tmp/qbit-artifacts")
downloads.mkdir(mode=0o700)
artifacts = {}
for line in Path("/tmp/artifacts.lock").read_text(encoding="utf-8").splitlines():
    if not line or line.startswith("#"):
        continue
    name, version, url, expected = line.split()
    artifacts[name] = downloader.download_verified_artifact(
        url, expected, downloads / f"{name}.artifact"
    )

pwsh = Path("/opt/microsoft/powershell/7")
pwsh.mkdir(parents=True, mode=0o755)
runtime.extract_tar_safely(artifacts["powershell"].read_bytes(), pwsh, "r:gz")

static = Path("/opt/qbit/serena-resources/language_servers/static")
pyright = static / "PyrightServer"
pyright.mkdir(parents=True, mode=0o755)
ps_root = static / "PowerShellLanguageServer/powershell"
ps_root.mkdir(parents=True, mode=0o755)
runtime.extract_zip_safely(artifacts["powershell-editor-services"].read_bytes(), ps_root)
psa = ps_root / "PowerShellEditorServices/PSScriptAnalyzer/1.25.0"
psa.mkdir(parents=True, mode=0o755)
runtime.extract_zip_safely(artifacts["psscriptanalyzer"].read_bytes(), psa)

shellcheck = static / "BashLanguageServer/bash-lsp/shellcheck/shellcheck-v0.10.0"
shellcheck.mkdir(parents=True, mode=0o755)
runtime.extract_tar_safely(artifacts["shellcheck"].read_bytes(), shellcheck, "r:xz", strip_components=1)

required = [
    pwsh / "pwsh",
    ps_root / "PowerShellEditorServices/Start-EditorServices.ps1",
    psa / "PSScriptAnalyzer.psd1",
    psa / "PSScriptAnalyzer.psm1",
    psa / "PSv7/Microsoft.Windows.PowerShell.ScriptAnalyzer.dll",
    shellcheck / "shellcheck",
]
duplicated = ps_root / "PowerShellEditorServices/PowerShellEditorServices"
if duplicated.exists():
    raise SystemExit(f"duplicated PSES extraction layout: {duplicated}")
if not pyright.is_dir() or pyright.is_symlink():
    raise SystemExit(f"required Pyright resource directory missing or unsafe: {pyright}")
for path in required:
    if not path.is_file() or path.is_symlink():
        raise SystemExit(f"required runtime artifact missing or unsafe: {path}")
for path in artifacts.values():
    path.unlink()
downloads.rmdir()
PY

COPY --from=language-servers /usr/local/bin/node /usr/local/bin/node
COPY --from=language-servers /opt/serena-language-servers /opt/serena-language-servers
COPY .ai/tooling/serena_config.yml /opt/qbit/serena-config/serena_config.yml
COPY .serena/project.yml /opt/qbit/serena-config/project.yml
COPY .ai/tooling/runtime-entrypoint.py .ai/tooling/graphify-runtime.py .ai/tooling/doctor.py .ai/tooling/mcp_stdio.py /usr/local/libexec/

RUN python - <<'PY'
from pathlib import Path
import hashlib
import json
import os
import stat

root = Path("/opt/qbit/serena-resources")
for path in [root, *root.rglob("*")]:
    if path.is_symlink():
        raise SystemExit(f"symlink forbidden in immutable resources: {path}")
    if path.is_dir():
        os.chmod(path, 0o555)
    elif path.is_file():
        executable = path.name == "shellcheck"
        os.chmod(path, 0o555 if executable else 0o444)
    else:
        raise SystemExit(f"special file forbidden in immutable resources: {path}")

source_artifacts = []
for line in Path("/tmp/artifacts.lock").read_text(encoding="utf-8").splitlines():
    if line and not line.startswith("#"):
        name, version, url, sha256 = line.split()
        source_artifacts.append({"name": name, "version": version, "url": url, "sha256": sha256})
entries = []
for path in sorted(root.rglob("*")):
    relative = path.relative_to(root).as_posix()
    info = path.stat(follow_symlinks=False)
    if stat.S_ISDIR(info.st_mode):
        entries.append({"path": relative, "type": "directory", "mode": f"{stat.S_IMODE(info.st_mode):04o}", "size": 0})
    elif stat.S_ISREG(info.st_mode):
        data = path.read_bytes()
        entries.append({"path": relative, "type": "file", "mode": f"{stat.S_IMODE(info.st_mode):04o}",
                        "size": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    else:
        raise SystemExit(f"unsupported manifest path: {path}")
manifest = {"schemaVersion": 1, "serenaVersion": "1.5.3",
            "sourceArtifacts": source_artifacts, "entries": entries}
raw = json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8") + b"\n"
(root / "manifest.json").write_bytes(raw)
os.chmod(root / "manifest.json", 0o444)
PY

RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh \
 && chmod 0555 /usr/local/libexec/*.py /opt/microsoft/powershell/7/pwsh \
 && find /opt/microsoft/powershell/7 -type d -exec chmod 0555 {} + \
 && find /opt/microsoft/powershell/7 -type f ! -name pwsh -exec chmod 0444 {} + \
 && chown -R 0:0 /opt/qbit /opt/serena-language-servers /opt/microsoft/powershell/7 /usr/local/libexec \
 && rm -rf /opt/microsoft/powershell/7/Modules/PowerShellGet /opt/microsoft/powershell/7/Modules/PackageManagement \
      /root/.cache /tmp/artifacts.lock /tmp/qbit-download.py /tmp/qbit-runtime.py \
      /var/cache/apt /var/lib/apt /var/lib/dpkg /usr/lib/apt \
 && rm -f /usr/bin/apt /usr/bin/apt-* /usr/bin/dpkg /usr/bin/dpkg-* /usr/bin/dselect
RUN python - <<'PY'
from pathlib import Path
import ensurepip
import pip
import shutil
import site

for package in (Path(pip.__file__).parent, Path(ensurepip.__file__).parent):
    shutil.rmtree(package, ignore_errors=True)
for base in map(Path, site.getsitepackages()):
    for pattern in ("pip-*.dist-info", "setuptools-*.dist-info"):
        for path in base.glob(pattern):
            shutil.rmtree(path, ignore_errors=True)
PY
RUN rm -f /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.13 \
 && test ! -e /usr/local/bin/npm \
 && test ! -e /usr/local/bin/uvx

WORKDIR /workspace
ENTRYPOINT ["python", "-I", "/usr/local/libexec/runtime-entrypoint.py"]
