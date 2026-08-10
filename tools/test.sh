#!/usr/bin/env sh
set -eu
layer=all
if [ "$#" -gt 0 ]; then
  case "$1" in --layer) layer=${2:-all}; shift 2 ;; -h|--help) echo 'Usage: test.sh [--layer unit|integration|e2e|docker|all]'; exit 0 ;; *) echo 'Usage: test.sh [--layer unit|integration|e2e|docker|all]' >&2; exit 2 ;; esac
fi
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
failures=0
run_checked(){ name=$1; shift; echo "== $name =="; if "$@"; then :; else failures=$((failures+1)); fi; }
run_python_unit(){ if command -v python3 >/dev/null 2>&1; then PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest tests.unit.test_validate -v; elif command -v python >/dev/null 2>&1; then PYTHONDONTWRITEBYTECODE=1 python -B -m unittest tests.unit.test_validate -v; elif command -v py >/dev/null 2>&1; then PYTHONDONTWRITEBYTECODE=1 py -3 -B -m unittest tests.unit.test_validate -v; else echo 'Python is required.' >&2; return 1; fi; }
case "$layer" in unit|all)
  run_checked 'Python validator unit' run_python_unit
  run_checked 'POSIX unit' sh "$root/installers/codex-ai-tooling/tests/unit/test-unit.sh"
  ;;
esac
case "$layer" in integration|all)
  run_checked 'POSIX integration' sh "$root/installers/codex-ai-tooling/tests/integration/test-installer.sh"
  ;;
esac
case "$layer" in e2e|all)
  run_checked 'POSIX E2E' sh "$root/installers/codex-ai-tooling/tests/e2e/test-e2e.sh"
  ;;
esac
case "$layer" in docker|all)
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo 'Docker-dependent PowerShell E2E requires PowerShell and is run by tools/test.ps1 on Windows.'
  else
    echo 'SKIP Docker-dependent E2E: Docker or Compose unavailable.'
  fi
  ;;
esac
[ "$failures" -eq 0 ] || { echo "Test runner failed with $failures failing layer command(s)." >&2; exit 1; }
echo 'All requested POSIX test layers completed.'
