# Installer rollout and repository onboarding

Use the canonical installers from `qbit-ai-toolkit`; never copy their payload files into a consumer repository manually.

## Order and lifecycle

1. Start the repository's AI context (`.ai/context/context.ps1 start` on Windows or `bash .ai/context/context.sh start` on POSIX) and read `.ai-bridge/context-runtime.md`.
2. Snapshot Git status and dirty paths. Preserve project edits and never stage, reset, or stash them.
3. Run `installer.codex-ai-tooling plan`.
4. Use `install` for a fresh repository, `update` for valid ownership state, `--adopt-matching` / `-AdoptMatching` for exact current unowned content, or `--migrate-legacy` / `-MigrateLegacy` for a recognized historical Serena/Graphify installation. Unknown unowned content remains a conflict.
5. Run tooling `verify`, then installed `bootstrap` and `doctor` when Docker is available. Re-run `plan` and `verify` after repair or update.
6. Install or update `installer.ai-context`, then verify both installers. Each managed block in `AGENTS.md`, `.gitignore`, and `.gitattributes` must occur once and preserve project content outside it.

PowerShell and POSIX use the same lifecycle and exit-code contract. Invoke POSIX shell entrypoints explicitly through `bash` (for example, `bash installers/codex-ai-tooling/install.sh ...`) so operation does not depend on repository executable mode bits. Always use `plan` before mutation and `--format json` for automation.

## Legacy and dirty repositories

`--migrate-legacy` recognizes audited historical payload fingerprints, makes transactional backups, publishes ownership last, and is idempotent. It is not a force switch. `--adopt-matching` only takes ownership of exact current payload files. For dirty repositories, compare pre/post Git diffs and use a selective index or clean worktree for an AI-only publication; never include product work.

AI tooling does not run target-root package-manager commands, create application dependency trees, or forbid legitimate application `node_modules`. It does not change the Git index. Uninstall and repair are ownership-driven; use them instead of deleting managed files by hand.

## Context and publication

Member repositories require a configured central context remote and `context.ps1`, `context.py`, and `context.sh`. Context `start` is automatic before substantive work; checkpoint only after a substantive validated milestone. Commit only validated installer/context paths, push only the existing tracked branch, never force-push, and record credential/network failures without undoing validated local work. If a repository-wide ignore rule matches the installer-owned non-secret `.env.ai.example`, use a force-add for that one example file in the selective publication; never force-add a real environment file. A `publish: false` laboratory remains local-only.

## Final checklist

- Both installer states/versions verify successfully.
- Context launchers exist and managed blocks are unique.
- Serena/Graphify assets are installer-owned; Graphify remains CLI-only.
- Bootstrap/Doctor/smoke passed, or its environmental skip is recorded.
- Pre-existing product diffs are unchanged and `git diff --check` passes.
- Publication is AI/context-only; the final matrix records status, branch/upstream, commits, pushes, and blockers.
