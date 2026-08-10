#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'usage: build-release.sh ABSOLUTE_OUTPUT_DIRECTORY' >&2
  exit 2
fi
output=$1
[[ "$output" = /* ]] || { echo 'Release output directory must be absolute.' >&2; exit 2; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
installer_root=$(cd -- "$script_dir/.." && pwd -P)
version=$(tr -d '\r\n' < "$installer_root/VERSION")
archive=$output/codex-ai-tooling-$version.tar.gz
checksum=$archive.sha256
[[ ! -e "$archive" && ! -e "$checksum" ]] || { echo 'Refusing to overwrite an existing release artifact.' >&2; exit 4; }
mkdir -p "$output"
stage=$(mktemp -d /tmp/qbit-installer-release.XXXXXX)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir -p "$stage/source"
cp -a "$installer_root" "$stage/source/codex-ai-tooling"
find "$stage/source/codex-ai-tooling" -type d \( -name node_modules -o -name graphify-out -o -name __pycache__ -o -name .pytest_cache \) -print | grep -q . && {
  echo 'Forbidden generated directory found in release source.' >&2
  exit 5
}
(
  cd "$stage/source/codex-ai-tooling"
  find . -type f ! -name RELEASE-CHECKSUMS.sha256 -print0 |
    LC_ALL=C sort -z |
    while IFS= read -r -d '' file; do sha256sum "${file#./}"; done > RELEASE-CHECKSUMS.sha256
  sha256sum -c RELEASE-CHECKSUMS.sha256 >/dev/null
)
tar --sort=name --format=ustar --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
  --mode='u+rwX,go+rX,go-w' -C "$stage/source" -cf "$stage/archive.tar" codex-ai-tooling
gzip -n -9 < "$stage/archive.tar" > "$archive"
sha256sum "$archive" > "$checksum"
mkdir -p "$stage/extracted"
tar -C "$stage/extracted" -xzf "$archive"
(
  cd "$stage/extracted/codex-ai-tooling"
  sha256sum -c RELEASE-CHECKSUMS.sha256 >/dev/null
)
target=$(mktemp -d /tmp/qbit-release-target.XXXXXX)
git -C "$target" init -q
"$stage/extracted/codex-ai-tooling/install.sh" --operation plan --target "$target" --profile generic --format json --non-interactive > "$stage/plan.json"
python_command=
if command -v python3 >/dev/null 2>&1; then python_command=python3; elif command -v python >/dev/null 2>&1; then python_command=python; fi
if [[ -n "$python_command" ]]; then "$python_command" -m json.tool "$stage/plan.json" >/dev/null; fi
echo "archive=$archive"
echo "checksum=$checksum"
sha256sum "$archive"
