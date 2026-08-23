# Authority by claim type

AI context is coordination evidence and never implementation authority. Authority is resolved by the type of claim being made.

| Claim type | Canonical owner/source |
| --- | --- |
| Current implementation/runtime behavior | owning repository source + tests |
| Shared/public API, protocol, or interface requirement | designated contracts/spec owner |
| Local architecture decision | owning repository ADR/docs |
| Cross-repository architecture decision | designated cross-repository ADR/contracts owner |
| Database migration/schema state | owning runtime/data repository migrations/schema |
| Operational/deployment truth | infrastructure repository + runbooks/config |
| Product/business requirement | designated product/spec owner |
| Reusable AI workflow/tooling semantics | AI toolkit/policy owner |
| Active execution state | repository-local `.ai-bridge/` |
| Cross-session continuity/current coordination state | this AI context repository |
| Generated semantic/graph/index evidence | non-authoritative derived evidence |
| Raw conversation | non-authoritative archive only |

## Conflict resolution

1. Identify the claim type.
2. Resolve the canonical owner for that claim type.
3. Compare stored context with current canonical evidence.
4. The canonical owner wins for that claim type.
5. Mark stale/superseded context explicitly.
6. Refresh the context reference/provenance.
7. Never silently modify canonical implementation merely to match AI context.
