# AI tooling

This repository owns its AI tooling configuration and local runtime. The installer does not require user-level Codex changes and does not install application dependencies.

## Capabilities

- Serena: semantic navigation/diagnostics and explicitly approved symbol-aware edits for the selected profile.
- Graphify: scoped architecture hypotheses through `.ai/scripts/graphify-*` wrappers only.
- Context7: optional external version-specific documentation.
- Sentry: optional read-only evidence for a real incident.
- Doctor: isolated runtime, protocol, version, security, and no-write validation.

Browser/Playwright tooling is not installed.

## Profiles

- `generic`: PowerShell, Bash, Python.
- `typescript`: TypeScript 5.9.3 and TypeScript Language Server 5.1.3, plus shared languages.
- `rust`: Rust 1.85.0 and `rust-analyzer`, plus shared languages.

Tool versions and images are pinned in `.ai/tooling/versions.env` and the corresponding lock/definition files.

## Normal workflow

1. Trust the repository in Codex.
2. Run bootstrap/Doctor after installation or tooling changes.
3. Let Serena start lazily when a semantic task needs it.
4. Run Graphify only with an explicit repository-relative scope.
5. Treat Context7 and Sentry as optional remote capabilities, not local readiness requirements.

See `.ai/policies/tool-boundaries.md` and `AGENTS.md` for deterministic routing rules.
