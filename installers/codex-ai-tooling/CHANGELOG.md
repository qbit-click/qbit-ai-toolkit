# Changelog

## 1.1.3

- Removes the POSIX top-level lifecycle's dependency on executable mode bits for installer helper scripts by invoking the Bash engine and POSIX verify/uninstall helpers through explicit interpreters.
- Adds an integration regression that chmods helper scripts to `0644` and proves install, verify, and uninstall still succeed, matching native Linux clones from repositories that track shell files as `100644`.
- Keeps 1.1.2 ownership state upgrade-compatible so existing consumers can update transactionally to 1.1.3.

## 1.1.2

- Restores the public process contract for unrecognized legacy migration: PowerShell and POSIX host entrypoints now classify the coherent-fingerprint rejection as conflict exit code 4 rather than generic operation exit code 12.
- Makes the PowerShell cross-installer composability regression test use the repository's portable SHA-256 pattern instead of depending on `Get-FileHash` availability.
- Keeps 1.1.1 ownership state upgrade-compatible so existing consumers can update transactionally to 1.1.2.

## 1.1.1

- Corrects legacy migration authorization: audited historical fingerprints are now coherent and path-specific, so a recognized file cannot authorize replacement of unrelated unowned content.
- Preserves recognized legacy shared blocks while migrating them transactionally, with state written last and repeat migration remaining idempotent.
- Restores the project-local Doctor private Serena tmpfs ownership contract required by repository validation.

## 1.1.0

- Adds explicit `-AdoptMatching` / `--adopt-matching` and `-MigrateLegacy` / `--migrate-legacy` lifecycle options.
- Migrates only audited historical Serena/Graphify fingerprints, keeps arbitrary unowned content fail-closed, and retains transactional backup/rollback behavior.
- Allows legitimate target-root application `node_modules`; the installer still never invokes an application package manager or creates application dependencies.

## 1.0.0

- Initializes the reusable `codex-ai-tooling` installer asset.
- Adds generic, TypeScript, and Rust profiles.
- Uses managed-block ownership for `AGENTS.md` so target repository instructions are preserved.
- Preserves pinned Serena, Graphify, TypeScript, TypeScript Language Server, Python base image, Node base image, and Rust toolchain/runtime versions.
