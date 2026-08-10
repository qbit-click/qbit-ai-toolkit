# Qbit AI Toolkit agent routing

qbit-ai-toolkit is the canonical versioned asset repository for Qbit installers,
schemas, templates, prompts, libraries, and tooling. Read the relevant repository
skill under `.agents/skills/` before broad work.

- Codex built-ins own ordinary file, command, Git inspection, test, Markdown,
  JSON, YAML, and TOML operations.
- Serena is reserved for semantic PowerShell, Bash, and Python operations after
  its runtime phase is installed.
- Graphify is only for explicit architecture-wide analysis.
- Context7 is only for external, version-specific documentation.
- Playwright and Sentry are not part of this repository toolchain.

The project-owned Serena runtime registers exactly `/workspace` and keeps all
state under `/serena-state/projects/qbit-ai-toolkit`; `.serena/project.yml` is a
tracked immutable input, not a runtime state directory. Bootstrap may build the
pinned image but must not install host dependencies or start services. Doctor
is read-only and must not repair state.

Source, schemas, tests, committed architecture records, and versioned repository
assets are authoritative. Generated evidence is not a source of truth. Never
expose secrets in prompts, commands, logs, reports, or generated artifacts.

See [`docs/ai-tooling/README.md`](docs/ai-tooling/README.md).
