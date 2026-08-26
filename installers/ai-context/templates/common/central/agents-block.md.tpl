## AI context governance

- This repository stores coordination evidence, not implementation authority.
- Resolve authority by claim type using `project/authority.md`; do not use a single global precedence list across unrelated claim types.
- Before persisting a concrete implementation claim, verify it against the current canonical owner and record repository/path/branch/commit provenance where practical.
- Keep context thin and referential. Do not mirror source trees, migrations, contracts, architecture documents, test output, generated semantic indexes, graph databases, or raw chat transcripts.
- Never store secrets, credentials, cookies, tokens, private keys, `.env` values, customer secrets, or production data.
- Context lifecycle tooling under `tooling/`, `templates/member/`, `schemas/`, and `tests/` is installer-managed. Project continuity content under `project/`, `state/`, `handoffs/`, `manifests/`, `repositories/`, `references/`, `sessions/`, `workstreams/`, and `validation/` is project-owned and may evolve independently.
- A tracked workstream is durable continuity state. Existing unresolved work-item IDs must never disappear implicitly; terminal transitions must be explicit and completed workstreams move to `workstreams/archive/`.
- Validation ledgers are append-only evidence records keyed by immutable validation IDs and bound to a member worktree fingerprint. A stale fingerprint means the evidence is historical, not current validation.
- Do not reset, clean, force-push, or overwrite dirty/diverged member or context repositories to make automation succeed.
