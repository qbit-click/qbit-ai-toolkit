# AI Context Automation

Member repositories run the repository-owned launcher for the active host automatically before substantive Codex work: `.ai/context/context.ps1 start` on Windows or `bash .ai/context/context.sh start` on Linux/macOS. The launcher ensures the central context cache exists, verifies its configured origin/branch, safely refreshes a clean cache, and generates `.ai-bridge/context-runtime.md` plus JSON runtime evidence.

## Continuity v2

New substantive checkpoints use checkpoint `schemaVersion: 2`. The ordinary mode is `continuity.mode: tracked`, which persists a first-class workstream containing stable work-item IDs, repository roles, dependencies/blockers, acceptance criteria, validation requirements, and an execution cursor with the exact current item, last completed item/action, phase, and next action. `continuity.mode: snapshot` is only for checkpoints that have no unresolved tracked workstream.

The lifecycle is fail-closed against continuity loss. An unresolved work item cannot disappear from a subsequent checkpoint, a terminal item/workstream cannot be silently reopened, dependency cycles are rejected, blocked items must identify blockers, and an active workstream cannot be replaced by a different workstream ID until it has been explicitly completed/cancelled/superseded. Completed workstreams move from `workstreams/active/` to `workstreams/archive/` rather than being discarded.

Validation evidence is stored in append-only repository ledgers under `validation/repositories/`. Every validation entry has an immutable ID and is bound to the member repository HEAD plus a deterministic worktree fingerprint. `start` reports how many ledger entries are fresh or stale for the current worktree; stale evidence remains historical evidence and must not be treated as current validation.

`schemaVersion: 1` checkpoints remain accepted only for backward compatibility when no unresolved v2 workstream would be lost. Agents should not create new substantive v1 checkpoints.

## Checkpoint lifecycle

After a substantive validated milestone, the agent writes `.ai-bridge/context-checkpoint.json` and runs the `checkpoint` action. The central lifecycle validates shape/status/continuity invariants, rejects secret-like material, derives Git provenance and the worktree fingerprint, writes repository-scoped state/handoff/session records, persists workstream and validation records, commits only the scoped context paths, and pushes when enabled.

## Offline portability

Use offline transfer only when the central context remote will not be available to the receiving workspace or machine. Run `export` while the central context cache is clean. The launcher writes an ignored `.ai-bridge/context-transfer/manifest.json` and `context.bundle`. Export scans every tracked central-context file and rejects non-regular Git entries, symlink/reparse entries, repository escapes, non-UTF-8 text, and secret-like content. The manifest binds the package to project/repository identity, configured context branch, source member/context Git provenance, bundle size, SHA-256, and the current continuity cursor summary.

On the receiving repository, copy the complete `context-transfer` directory into `.ai-bridge/` and run `import`. Import verifies the exact manifest shape, project/repository/branch identity, byte length, SHA-256, Git bundle integrity, and source context HEAD before creating or accepting the context cache. After a successful import, `start`, `status`, and `checkpoint` run without remote access and runtime freshness is `OFFLINE_IMPORTED_CONTEXT`. Offline checkpoints remain normal local context commits but deliberately skip remote push.

When the configured central remote becomes reachable again, run `reconnect`. If remote history is an ancestor of the locally advanced offline history, reconnect performs a normal non-force push. If local history is an ancestor of remote history, reconnect fast-forwards locally. If both histories advanced independently, reconnect rejects the operation and preserves both histories and the offline marker for explicit human reconciliation; it never auto-merges, rebases, resets, or force-pushes. Only a successful synchronization removes the offline marker and returns ordinary `start` behavior.

Network Git operations use the host's normal Git credential chain. The Windows PowerShell launcher may additionally retry failed private `github.com` operations through `gh auth git-credential` when GitHub CLI is available. The POSIX launcher deliberately delegates authentication to Git credential helpers and does not persist credentials. A clean cache may migrate its `origin` when the configured context remote changes; a dirty cache refuses automatic origin migration.

Windows/PowerShell and Linux/macOS through Bash plus Python 3.10+ are supported. Both launcher/tooling variants are installed so a managed repository remains portable after cloning on another supported host.
