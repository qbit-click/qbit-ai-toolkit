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

## AI context lifecycle

- Before the first substantive repository analysis, planning, or implementation in a Codex session, automatically run `powershell -NoProfile -ExecutionPolicy Bypass -File .ai/context/context.ps1 start`. Do not ask the developer and do not wait for a context-loading instruction.
- Read `.ai-bridge/context-runtime.md` before substantive planning or implementation. Do not rerun `start` repeatedly in the same session unless the context cache may have changed materially.
- Central AI context is coordination evidence, never implementation authority. Current source, tests, schemas/migrations, explicit contracts, and committed canonical decisions outrank stored context according to their claim type.
- Preserve pre-existing uncommitted user changes; do not stage, format, rewrite, reset, clean, or otherwise disturb unrelated work.
- After a substantive validated milestone that materially changes durable continuity state, and before the final handoff, automatically write `.ai-bridge/context-checkpoint.json` and run `powershell -NoProfile -ExecutionPolicy Bypass -File .ai/context/context.ps1 checkpoint`. No developer reminder is required.
- Do not create checkpoints for ordinary read-only questions, every chat message, or work that produced no durable continuity change.
- The checkpoint JSON must use `schemaVersion: 1`, repository `qbit-ai-toolkit`, and include `scope`, controlled `status`, `objective`, `confirmedFindings[]`, `decisions[]`, `rejectedApproaches[]`, `validation[]`, `openQuestions[]`, and `nextAction`.
- Promote durable technical decisions into their canonical owning repository/ADR/contract; the context checkpoint records continuity, not technical authority.
- Never store secrets, credentials, cookies, tokens, private keys, `.env` values, customer secrets, or raw chat transcripts in AI context.
- If context start/checkpoint fails because of missing context source, authentication, dirty/diverged context state, or a concurrent conflict, do not perform destructive recovery; report the condition and preserve data.
- `.ai-bridge/` and `.ai/context/cache/` are transient/ignored runtime locations. Serena and Graphify remain derived evidence tools, not project memory.
