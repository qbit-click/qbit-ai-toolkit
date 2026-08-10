#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v python3 >/dev/null 2>&1; then python3 "$root/tools/validate.py"; elif command -v python >/dev/null 2>&1; then python "$root/tools/validate.py"; elif command -v py >/dev/null 2>&1; then py "$root/tools/validate.py"; else echo 'Python is required.' >&2; exit 1; fi
find "$root" -path "$root/.git" -prune -o -name '*.sh' -type f -print | while IFS= read -r file; do sh -n "$file"; done
