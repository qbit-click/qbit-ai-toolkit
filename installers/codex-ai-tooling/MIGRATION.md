# Migration notes

Version 1.1 keeps the published installer ID, profiles, entrypoint names, and compatibility ownership-state location. The host entrypoints expose the seven-operation process contract and JSON output. Legacy `--force` is not public; use the narrower owned-modified `replace` policy after reviewing a previously owned conflict.

For a repository with no ownership state, use `plan` first. `--adopt-matching` takes ownership only of exactly matching current payload files. `--migrate-legacy` replaces only audited historical Qbit, Balloot, and Henkel Serena/Graphify payload fingerprints; it writes backups transactionally and continues to reject arbitrary/custom unowned files. Both options are explicit, idempotent, and available as `-AdoptMatching` / `-MigrateLegacy` on PowerShell.

The current payload keeps the validated repository-owned Serena/Graphify architecture while making the published profiles concrete:

- `generic` provides the shared PowerShell, Bash, and Python semantic runtime;
- `typescript` adds TypeScript 5.9.3 and TypeScript Language Server 5.1.3;
- `rust` adds Rust 1.85.0 and its pinned `rust-analyzer` component.

Graphify remains CLI-only and now runs through explicit repository-relative scopes. Playwright/browser tooling remains absent unless a future project establishes a separate justified capability and acceptance contract.

Earlier broad Sentry-oriented behavior is replaced by an optional OAuth connector with a fixed read-only allowlist and an incident-analysis skill. Sentry is not a local readiness requirement and is used only for a concrete runtime incident.

Existing user content is never silently adopted or migrated. Update requires valid ownership evidence, computes conflicts before mutation, preserves shared common payload across profile migrations, and reports modified owned content before any replacement. Transaction, backup, rollback, and recovery semantics remain part of the 1.1 compatibility contract.
