# AI tooling maintenance

Treat `.ai/tooling/versions.env`, image digests, artifact locks, Debian snapshot metadata, hashed Python requirements, npm lockfile integrity, and profile Dockerfiles as one reviewed dependency contract.

For a tooling/version update:

1. change only the intended version authorities;
2. regenerate lock/checksum material reproducibly;
3. rebuild the repository-owned image;
4. run static/unit validation;
5. run Doctor and real MCP/LSP acceptance;
6. validate TypeScript or Rust profile runtime when selected;
7. validate scoped Graphify build/reuse/query/clean behavior;
8. review remote connector allowlists and documentation;
9. verify no target application dependency or Git index mutation occurred.

Do not run application package managers or Cargo operations in the repository root merely to maintain AI tooling. Keep Graphify CLI-only, preserve the exact Serena allowlist, keep Sentry read-only, and add browser tooling only through a separately justified capability with its own acceptance tests.
