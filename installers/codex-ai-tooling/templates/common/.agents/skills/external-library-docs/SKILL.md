---
name: external-library-docs
description: Use only for version-specific behavior of an external library, SDK, tool, or service.
---

# External library documentation

1. Determine the repository's pinned version from its manifest or lockfile first.
2. Use official documentation or Context7 narrowly for that version.
3. Never use Context7 to search this repository.
4. Validate important conclusions against local lockfiles, source, schemas,
   generated types, or executable behavior.

Context7 is optional. Missing authentication is a limitation, not justification
for adding or using another MCP server.
