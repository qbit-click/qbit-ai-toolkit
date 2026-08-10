# AI tool boundaries

| Capability | Responsibility | Boundary |
| --- | --- | --- |
| Codex built-ins | Files, commands, Git inspection, tests, orchestration, Markdown, JSON, YAML, TOML, and general fallback | Primary tools for ordinary repository work |
| Serena | Semantic navigation, references, diagnostics, and edits for PowerShell, Bash, and Python only | Phase 2 source implemented, runtime not yet validated; no generic file, shell, search, Git, or memory operations |
| Graphify | Broad architecture and blast-radius hypotheses | Phase 2 source implemented, runtime not yet validated; explicit CLI wrapper only, never MCP, hooks, or automatic execution |
| Context7 | Narrow external, version-specific documentation | Optional; never repository search or a source of repository truth |

Playwright and Sentry are intentionally absent from this repository toolchain. No
generic filesystem, shell, search, Git, memory, browser, database, or security
scanner MCP belongs here.

Phase 2 source is implemented; the runtime is not yet validated. Root runtime
ownership remains separate from installer-managed consumer templates. Balloot is
only a read-only behavioral reference and is never copied or installed.

Source, schemas, tests, catalog data, installer state contracts, committed
architecture records, and versioned assets remain authoritative. Generated graphs,
indexes, caches, logs, reports, and summaries are derived evidence. Never expose
secrets.
## Phase 2 runtime boundary

Serena is the semantic tool for PowerShell, Bash, and Python. Its MCP allowlist
contains symbol overview, lookup, reference lookup, symbol-body replacement,
symbol insertion, and rename only. Codex built-ins retain ordinary file,
command, Git, JSON, YAML, TOML, and Markdown work.

Graphify is permitted only when architecture-wide analysis is explicit. Its
runtime accepts the fixed build, query, report, and clean verbs; it has no
network and can write only the `/graphify-output` named-volume mount. Neither
runtime may install, download, modify Git/index, or write below
`/workspace/.serena`.
