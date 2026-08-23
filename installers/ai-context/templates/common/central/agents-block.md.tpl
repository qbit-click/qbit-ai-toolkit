## AI context governance

- This repository stores coordination evidence, not implementation authority.
- Resolve authority by claim type using `project/authority.md`; do not use a single global precedence list across unrelated claim types.
- Before persisting a concrete implementation claim, verify it against the current canonical owner and record repository/path/branch/commit provenance where practical.
- Keep context thin and referential. Do not mirror source trees, migrations, contracts, architecture documents, test output, generated semantic indexes, graph databases, or raw chat transcripts.
- Never store secrets, credentials, cookies, tokens, private keys, `.env` values, customer secrets, or production data.
- Context lifecycle tooling under `tooling/`, `templates/member/`, `schemas/`, and `tests/` is installer-managed. Project continuity content under `project/`, `state/`, `handoffs/`, `manifests/`, `repositories/`, `references/`, and `sessions/` is project-owned and may evolve independently.
- Do not reset, clean, force-push, or overwrite dirty/diverged member or context repositories to make automation succeed.
