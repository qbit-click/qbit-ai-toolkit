# Project-owned AI runtime

This directory is the canonical root runtime for Serena 1.5.3 and Graphify
0.9.12. It is intentionally independent of the consumer assets under
`installers/codex-ai-tooling`.

Status: source implemented; runtime not yet validated. This status changes only
after the clean linux/amd64 build, Doctor, MCP/LSP smoke, and fixture-bounded
Graphify E2E gates all pass.

`bootstrap` builds the pinned image only. It never starts a container, installs
host packages, edits Codex configuration, or writes Serena project state.
`doctor` is diagnostic-only. Runtime services have no network, use read-only
root filesystems, and drop every capability before executing project tools.

Serena owns semantic PowerShell, Bash, and Python operations. Its only project
is `/workspace`; all mutable state is external at
`/serena-state/projects/qbit-toolkit`. Graphify is used only for explicit
architecture-wide analysis and may write only the named volume mounted at
`/graphify-output`.

Balloot was consulted only as a read-only behavioral reference. No Balloot file,
runtime, or generated output is installed or copied by this project.
