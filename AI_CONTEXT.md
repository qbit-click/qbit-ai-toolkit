# Qbit AI Context Entry Point

## Repository role

`qbit-ai-toolkit` is the reusable AI tooling authority in the Qbit multi-repository workspace. Current source, tests, configuration, explicit contracts, and committed local engineering decisions remain authoritative for implementation facts owned by this repository.

## Zero-touch lifecycle

Before substantive Codex work, the agent automatically runs the host launcher (`.ai/context/context.ps1 start` on Windows or `bash .ai/context/context.sh start` on Linux/macOS) and reads `.ai-bridge/context-runtime.md`. The launcher clones or safely refreshes the central context into the ignored `.ai/context/cache/project-context` cache.

After a substantive validated milestone that changes durable continuity state, the agent creates `.ai-bridge/context-checkpoint.json` and runs the host checkpoint launcher (`powershell -NoProfile -ExecutionPolicy Bypass -File .ai/context/context.ps1 checkpoint` on Windows or `bash .ai/context/context.sh checkpoint` on Linux/macOS). Checkpoints are milestone-driven, not per-message.

New substantive checkpoints use Continuity v2 (`schemaVersion: 2`). Active work uses a tracked workstream with stable work-item IDs, dependencies/blockers, acceptance criteria, an exact execution cursor, and structured validation ledger entries bound to the current worktree fingerprint. Snapshot mode is reserved for states with no unresolved tracked work. Offline/cross-machine transfer uses `export`, `import`, and `reconnect`; writer divergence fails closed.

The canonical Continuity v2 contract is documented in [`docs/ai-tooling/continuity-v2.md`](docs/ai-tooling/continuity-v2.md).

The canonical context source is the private Git repository `https://github.com/qbit-click/qbit-ai-context.git`. The lifecycle automatically clones or refreshes it into the ignored project-local context cache; no sibling checkout is required.

## Authority and safety

Central AI context is coordination evidence, never implementation authority. Verify stale/version-sensitive claims against the current canonical owner. Preserve unrelated dirty work. Never store secrets or raw chat exports in AI context. Serena/Graphify output is derived evidence only.
