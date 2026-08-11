## Qbit AI tooling

This managed block describes repository-owned AI tooling installed by `qbit-toolkit`. Existing project instructions outside this block remain authoritative for architecture, build/test commands, coding conventions, and contribution rules.

### Mandatory task classification

Before selecting an AI capability, classify the request as ordinary repository work, semantic code work, architecture-impact analysis, external-library documentation, or real incident analysis.

### Deterministic tool routing

- Use built-in file/command/Git tools for ordinary repository work.
- Use Serena only when semantic symbol/reference/diagnostic behavior is materially useful. Start with a read-only semantic call.
- Use Graphify only for explicit broad architecture-impact work and only through the scoped `.ai/scripts/graphify-*` wrappers. Always validate material graph conclusions against source and, where useful, Serena.
- Use Context7 only for narrow external version-specific documentation after resolving the dependency/version from project metadata.
- Use Sentry only for a concrete incident and only through the configured read-only tools.
- Browser/Playwright tooling is intentionally absent unless the project establishes a separate justified capability.

### Execution timing and reuse

- Local tooling is container-owned; do not install Serena, Graphify, language servers, or Rust components globally on the host.
- Serena starts lazily through project-scoped MCP configuration; first use may build the pinned image.
- Graphify requires an explicit repository-relative scope. The build wrapper reuses an unchanged scope fingerprint; the update wrapper forces a rebuild.
- Full Doctor is for installation, maintenance, tooling/version changes, or real inconsistency, not every prompt.
- Bootstrap and Doctor must not install target application dependencies or run target-root package-manager/Cargo operations.
- Follow `.ai/policies/tool-boundaries.md` for trust, mutation, network, and evidence boundaries.
