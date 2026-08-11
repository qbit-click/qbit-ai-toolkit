# AI tooling onboarding

1. Trust the repository in Codex so `.codex/config.toml` can load.
2. Ensure Docker provides Linux `amd64` and Docker Compose v2 or newer.
3. Run `.ai/scripts/bootstrap.ps1` on Windows or `.ai/scripts/bootstrap.sh` on POSIX hosts after installation or tooling-version changes.
4. Run the corresponding Doctor entrypoint and require it to pass before accepting the tooling runtime.
5. Start a fresh Codex session from the repository root after changing MCP configuration.
6. Use built-ins for ordinary repository work and Serena only for semantic tasks.
7. Use Graphify only through its wrappers with an explicit repository-relative scope, for example `src/payments`.
8. Use Context7 only for external version-specific documentation.
9. Use Sentry only for a real incident and only through the read-only configured tools.

The TypeScript and Rust language runtimes are built into the tooling image. Do not install their language servers globally or run target-root package/Cargo installation merely to prepare AI tooling.

Context7 and Sentry authentication are optional and do not block local Serena/Graphify readiness.
