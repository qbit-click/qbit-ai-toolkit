# AI tool boundaries

Repository source, schemas, migrations, tests, committed architecture records, and installer-owned configuration remain authoritative. Generated graphs, indexes, caches, logs, reports, and model summaries are derived evidence.

## Mandatory task classification

Classify the task before selecting an AI capability:

| Task class | Primary capability | Entry condition |
| --- | --- | --- |
| Ordinary repository work | Built-in file/command/Git tools | Known files, tests, config, Markdown, or literal edits |
| Semantic code work | Serena | Declaration/reference/implementation/diagnostic or symbol-aware edit is materially useful |
| Architecture impact | Graphify, then source/Serena validation | Cross-module or broad dependency impact is explicitly requested or materially uncertain |
| External library documentation | Context7 | A third-party version/API behavior must be verified |
| Production incident analysis | Sentry | A real incident, issue, trace, release, or event is being investigated |

Do not invoke a capability merely because it is available.

## Deterministic tool routing

- **Built-ins** own ordinary files, commands, Git inspection, tests, JSON/YAML/TOML/Markdown, and orchestration.
- **Serena** owns semantic navigation, references, implementations, diagnostics, and the configured symbol-level edits for the installed language profile. It is not a generic file, shell, Git, search, or memory tool.
- **Graphify** is architecture-hypothesis support. Agent-facing wrappers require an explicit repository-relative scope. Do not call `graphify extract`, `graphify update`, `graphify cluster-only`, or `graphify clean` directly.
- **Context7** is only for narrow, version-specific external documentation. Resolve the dependency/version from authoritative project metadata first.
- **Sentry** is optional and read-only. Use it only for a concrete incident and only through the configured read-only allowlist.
- **Playwright/browser tooling** is not installed by this toolchain. Add browser capability only when a project has a separately justified acceptance scenario.

## Execution timing and reuse

- Serena starts lazily through the project-scoped MCP configuration. The Compose path may build the pinned image on first use.
- Graphify runs only through scoped wrappers. `graphify-build` reuses a graph while the scope fingerprint is unchanged; `graphify-update` forces a rebuild.
- Context7 and Sentry are remote optional capabilities and must not block local readiness when unused.
- Full Doctor is for installation, maintenance, version changes, or real inconsistency; it is not a per-prompt requirement.

## Runtime and mutation boundary

Local Serena and Graphify execution is container-owned, network-disabled, least-privilege, and isolated from host-global tool installation. Bootstrap may build only the repository-owned tooling runtime; it must not install target application dependencies. Doctor is read-only against persistent project/tooling state.

Graphify can write only its dedicated output volume. Serena may write to the workspace only when an explicitly approved semantic edit tool is invoked. Neither local runtime may stage, reset, clean, stash, commit, or otherwise manage Git state.

Never send secrets or unrelated internal source to remote connectors. Authentication remains outside committed repository content.
