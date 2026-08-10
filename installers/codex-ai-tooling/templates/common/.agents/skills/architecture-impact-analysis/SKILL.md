---
name: architecture-impact-analysis
description: Use only for catalog/schema contract changes, installer architecture, cross-installer libraries, CLI/toolkit boundaries, broad asset ownership, or release migration blast radius.
---

# Architecture impact analysis

Trigger only when work affects catalog or schema contracts, installer architecture,
shared cross-installer libraries, CLI/toolkit consumer boundaries, broad asset
ownership, or release compatibility and migration blast radius. Do not trigger for
local fixes or isolated assets.

After the phase-2 runtime exists, use the explicit Graphify CLI wrapper only to
form a bounded hypothesis. Graphify output is derived evidence, never authority.
Validate conclusions with source, schemas, tests, the catalog, installer state
contracts, and committed architecture documents. Report affected boundaries,
compatibility risk, validation needs, and unknowns before broad changes.

Never configure Graphify as MCP, enable hooks, run it automatically, or act on its
output alone. See `docs/ai-tooling/architecture.md`.
