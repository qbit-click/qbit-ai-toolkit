# AI tooling architecture

## Ownership and authority

Root `AGENTS.md`, `.agents/`, `.ai/`, `.codex/`, and these documents are
project-owned. Assets under `installers/codex-ai-tooling/templates/` are
installer-managed templates for consumer repositories. The root AI layer must not
use installer managed-block markers, and the installer must never self-install into
qbit-ai-toolkit.

Authority descends from canonical versioned source and assets, schemas and catalog
contracts, tests, installer state contracts, and committed architecture records.
Generated graphs, indexes, caches, logs, reports, release output, and summaries are
derived evidence and never replace canonical source.

## Tool boundaries

Codex built-ins perform ordinary file, command, Git inspection, test, structured
text, and orchestration work. Phase 2 may add Serena only for semantic PowerShell,
Bash, and Python operations. Phase 2 may add Graphify only behind an explicit CLI
wrapper for architecture-wide hypotheses; it will not be an MCP server, hook, or
automatic action. Context7 is optional and only supplies external version-specific
documentation.

qbit-cli is a separate consumer repository. Its files and compatibility contract
may be inspected or changed only when the user explicitly places that repository
in scope. The detailed policy is stored at `.ai/policies/tool-boundaries.md`.
# Phase 2 isolation

Serena receives the repository at `/workspace` read-write because approved
semantic edits target source. Its global and project state live in named
volumes, with the single project directory fixed to
`/serena-state/projects/qbit-ai-toolkit`. The tracked `/workspace/.serena` is only
the immutable project-config source.

Graphify receives `/workspace` read-only and a separate writable named-volume
mount at `/graphify-output`; no output mountpoint is created in the repository.
Doctor mounts every input read-only. All services
have no network, a read-only container filesystem, a `no-new-privileges`
security option, and all capabilities dropped. Serena and Graphify bootstrap as
root only long enough to validate mounts and seed ownership, then clear all
capability sets and execute as the workspace UID/GID.

Installer templates remain consumer-runtime assets. Root Phase 2 files are
canonical only for qbit-ai-toolkit and must not be copied into the installer by an
unrelated change.

Balloot is a read-only behavioral reference only. It is not an ownership source,
and no Balloot source or runtime asset is copied into qbit-ai-toolkit.
