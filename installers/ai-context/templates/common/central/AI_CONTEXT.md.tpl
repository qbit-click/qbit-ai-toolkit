# {{PROJECT_DISPLAY_NAME}} AI Context

This repository stores long-lived, curated AI continuity for the `{{PROJECT_ID}}` project. It is coordination evidence, not implementation authority.

## Load order

1. `project/authority.md`
2. `state/current.md`
3. repository manifest under `manifests/repositories/` when present
4. active workstream under `workstreams/active/` when referenced by the manifest
5. repository validation ledger under `validation/repositories/` when present
6. `state/next-action.md`
7. `repositories/repositories.yaml`
8. relevant canonical repository source/tests/contracts/migrations/docs
9. current Git state and worktree fingerprint
10. repository-scoped state/handoff/session records when relevant
11. derived semantic or graph evidence only when needed

Do not treat this repository as a substitute for current implementation evidence. When context conflicts with a canonical owner for a claim type, the canonical owner wins and the context must be marked stale or refreshed.
