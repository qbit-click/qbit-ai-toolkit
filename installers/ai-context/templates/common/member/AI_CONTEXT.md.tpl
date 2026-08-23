# AI Context Entry Point

This repository is a member of the `{{PROJECT_ID}}` AI-context workspace.

Before substantive Codex work, the agent automatically runs `.ai/context/context.ps1 start` and reads `.ai-bridge/context-runtime.md`. The launcher clones or safely refreshes the central context into the ignored `.ai/context/cache/project-context` cache.

After a substantive validated milestone that changes durable continuity state, the agent creates `.ai-bridge/context-checkpoint.json` and runs `.ai/context/context.ps1 checkpoint`. Checkpoints are milestone-driven, not per-message.

The canonical context source is `{{CONTEXT_REMOTE}}` on branch `{{CONTEXT_BRANCH}}`.

## Authority and safety

AI context is coordination evidence, never implementation authority. Current source, tests, schemas/migrations, explicit contracts, and committed canonical decisions outrank stored context according to claim type. Preserve pre-existing uncommitted work, never store secrets or raw chat transcripts in context, and do not use destructive Git recovery to resolve context failures.
