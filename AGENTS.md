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

- Before the first substantive repository analysis, planning, or implementation in a Codex session, automatically start AI context with the repository-owned launcher for the active host: on Windows run `powershell -NoProfile -ExecutionPolicy Bypass -File .ai/context/context.ps1 start`; on Linux/macOS run `bash .ai/context/context.sh start`. Do not ask the developer and do not wait for a context-loading instruction.
- Read `.ai-bridge/context-runtime.md` before substantive planning or implementation. Treat active workstream, cursor, unresolved items, dependencies, acceptance criteria, and validation freshness as the resume contract.
- Central AI context is coordination evidence, never implementation authority. Current source, tests, schemas/migrations, explicit contracts, and committed canonical decisions outrank stored context according to their claim type.
- Preserve pre-existing uncommitted user changes; do not stage, format, rewrite, reset, clean, or otherwise disturb unrelated work.
- After a substantive validated milestone that materially changes durable continuity state, and before the final handoff, automatically write `.ai-bridge/context-checkpoint.json` and run the host checkpoint launcher: Windows `.ai/context/context.ps1 checkpoint`; Linux/macOS `bash .ai/context/context.sh checkpoint`. No developer reminder is required.
- Do not create checkpoints for ordinary read-only questions, every chat message, or work that produced no durable continuity change.
- New substantive checkpoint JSON must use `schemaVersion: 2`, repository `qbit-ai-toolkit`, and include `scope`, controlled `status`, `objective`, `confirmedFindings[]`, `decisions[]`, `rejectedApproaches[]`, `validation[]`, `openQuestions[]`, `nextAction`, plus `continuity.mode`, `continuity.workstream`, and `continuity.validationLedger[]`. `schemaVersion: 1` is legacy-read compatibility only.
- Use `continuity.mode: tracked` while work remains active, pending, blocked, or otherwise resumable. Carry unresolved work items forward by stable ID with dependencies, blockers, acceptance criteria, validation requirements, and an exact execution cursor. Never drop an unresolved item or replace an active workstream ID merely to make a checkpoint pass.
- Use `continuity.mode: snapshot` only when there is no unresolved tracked workstream. Terminal workstreams explicitly close, cancel, or supersede their items and are archived by the lifecycle rather than discarded.
- Structured validation ledger entries must represent validation actually executed for the current repository/worktree. Validation IDs are immutable and validation freshness is bound to the deterministic member worktree fingerprint.
- `export`, `import`, and `reconnect` are the supported portability flow for deliberate offline/cross-machine continuation. Do not bypass reconnect divergence with merge, rebase, reset, or force-push.
- Promote durable technical decisions into their canonical owning repository/ADR/contract; the context checkpoint records continuity, not technical authority.
- Never store secrets, credentials, cookies, tokens, private keys, `.env` values, customer secrets, or raw chat transcripts in AI context.
- If context start/checkpoint fails because of missing context source, authentication, dirty/diverged context state, or a concurrent conflict, do not perform destructive recovery; report the condition and preserve data.
- `.ai-bridge/` and `.ai/context/cache/` are transient/ignored runtime locations. Serena and Graphify remain derived evidence tools, not project memory.
