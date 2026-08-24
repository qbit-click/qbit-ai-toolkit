# Changelog

## 1.1.0

- Adds explicit `-AdoptMatching` / `--adopt-matching` and `-MigrateLegacy` / `--migrate-legacy` lifecycle options.
- Migrates only audited historical Serena/Graphify fingerprints, keeps arbitrary unowned content fail-closed, and retains transactional backup/rollback behavior.
- Allows legitimate target-root application `node_modules`; the installer still never invokes an application package manager or creates application dependencies.

## 1.0.0

- Initializes the reusable `codex-ai-tooling` installer asset.
- Adds generic, TypeScript, and Rust profiles.
- Uses managed-block ownership for `AGENTS.md` so target repository instructions are preserved.
- Preserves pinned Serena, Graphify, TypeScript, TypeScript Language Server, Python base image, Node base image, and Rust toolchain/runtime versions.
