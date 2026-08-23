# Changelog

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
