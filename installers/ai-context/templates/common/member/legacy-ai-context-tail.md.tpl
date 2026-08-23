## Zero-touch lifecycle

Before substantive Codex work, the agent automatically runs `.ai/context/context.ps1 start` and reads `.ai-bridge/context-runtime.md`. The launcher clones or safely refreshes the central context into the ignored `.ai/context/cache/project-context` cache.

After a substantive validated milestone that changes durable continuity state, the agent creates `.ai-bridge/context-checkpoint.json` and runs `.ai/context/context.ps1 checkpoint`. Checkpoints are milestone-driven, not per-message.

The canonical context source is the private Git repository `{{CONTEXT_REMOTE}}`. The lifecycle automatically clones or refreshes it into the ignored project-local context cache; no sibling checkout is required.

## Authority and safety

Central AI context is coordination evidence, never implementation authority. Verify stale/version-sensitive claims against the current canonical owner. Preserve unrelated dirty work. Never store secrets or raw chat exports in AI context. Serena/Graphify output is derived evidence only.
