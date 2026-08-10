# Troubleshooting

- **Project configuration does not load:** trust the repository in Codex, then
  start a new session if needed.
- **Context7 is unavailable or unauthenticated:** it is optional. Export
  `CONTEXT7_API_KEY` from the parent process or use approved authentication; do not
  add a substitute MCP server.
- **Repository skills are not visible:** start a new Codex session after adding or
  changing skills.
- **Serena or Graphify is unavailable:** phase 2 is not installed. Phase 1 provides
  no bootstrap or runtime.
- **Generated artifacts need cleanup:** remove only known derived paths. Confirm
  targets before cleanup and never delete canonical schemas, templates, catalog,
  installers, libraries, prompts, tests, docs, or agent assets.
# Phase 2 troubleshooting

- A missing mount is fatal; do not replace it with a workspace directory.
- A missing language server is a build defect; runtime npm, uvx, PowerShell
  module installation, and downloader fallbacks are forbidden.
- Doctor reports only. It must not repair permissions, seed volumes, or write
  configuration.
- Serena configuration writes indicate an incomplete or migrated tracked
  configuration and must fail validation. Both YAML files must retain identical
  bytes and timestamps across load and pre-registered startup.
- Graphify clean refuses any output path that is not the exact nested mount and
  never follows symlinks.
