# Changelog

## 1.1.1

- Add native Ubuntu/macOS GitHub Actions validation for the POSIX installer lifecycle.
- Make POSIX integration fixtures compatible with macOS Bash 3.2 by removing `mapfile` and using portable SHA-256 helpers.
- Make checkpoint verification clones explicitly target `main` so bare-remote default HEAD differences do not produce false failures on Linux/macOS.

## 1.1.0

- Add real Linux/macOS installer parity through Bash entrypoints backed by a Python 3.10+ standard-library engine.
- Provision both Windows and POSIX member launchers (`context.ps1`, `context.sh`, and `context.py`) and both central lifecycle engines so managed repositories remain portable across supported hosts.
- Add POSIX start/status/checkpoint behavior with safe cache refresh, dirty/diverged-cache refusal, secret-aware checkpoint validation, scoped context commits, and optional Git push through the normal credential chain.
- Make managed member lifecycle instructions platform-aware without changing authority or checkpoint semantics.
- Add POSIX unit, installer integration, legacy migration, installed central lifecycle, end-to-end, and cross-platform ownership-state parity coverage.
- Reject absolute, traversal, symlink, and reparse-point context cache paths so runtime cache operations remain inside the member repository.
- Report clean-but-diverged caches as `DIVERGED_LOCAL_CONTEXT` (and behind-only caches as `STALE_LOCAL_CONTEXT`) instead of incorrectly labeling them current.

## 1.0.2

- Refresh ownership state when the installed payload is unchanged but the recorded installer version is older.
- Exclude generated AI context cache and transient `.ai-bridge` runtime files from toolkit repository hygiene validation.
- Add regression coverage for version-only ownership-state upgrades and runtime-path validator exclusions.

## 1.0.1

- Add explicit `-MigrateLegacy` support for the pre-installer manual rollout shape.
- Canonicalize semantically equivalent legacy member config JSON during migration.
- Convert recognized legacy `AGENTS.md`, `AI_CONTEXT.md`, and `.ai-bridge/.gitignore` content into managed blocks without duplicating policy text.
- Keep the member `AI_CONTEXT.md` repository-role header project-owned while managing only the zero-touch lifecycle/authority tail.
- Preserve unknown or modified legacy content as a conflict; migration remains opt-in and fail-closed.

## 1.0.0

- Add Windows member/central AI Context lifecycle installation.
- Add ownership state, managed-block updates, conflict detection, explicit matching adoption, byte-exact rollback, and recovery backups for replaced owned content.
- Add canonical zero-touch member launcher with safe GitHub CLI credential fallback and clean-only origin migration.
- Add central checkpoint lifecycle, schema, regression suite, typed authority bootstrap, and project-owned continuity seed structure.
- Preserve central continuity data during installer update and uninstall.
