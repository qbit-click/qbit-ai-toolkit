# TypeScript profile

This profile extends the shared PowerShell, Bash, and Python semantic runtime with a pinned TypeScript toolchain:

- TypeScript `{{TYPESCRIPT_VERSION}}`
- TypeScript Language Server `{{TYPESCRIPT_LANGUAGE_SERVER_VERSION}}`

The language server is built into the repository-owned tooling image. The installer does not run `npm install`, `pnpm install`, `yarn install`, or `bun install` in the target repository.

Serena uses the project-local `.serena/project.yml` profile and the same bounded MCP allowlist as the common runtime.
