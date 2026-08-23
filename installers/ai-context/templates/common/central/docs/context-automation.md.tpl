# AI Context Automation

Member repositories run `.ai/context/context.ps1 start` automatically before substantive Codex work. The launcher ensures the central context cache exists, verifies its configured origin/branch, safely refreshes a clean cache, and generates `.ai-bridge/context-runtime.md` plus JSON runtime evidence.

After a substantive validated milestone, the agent writes `.ai-bridge/context-checkpoint.json` and runs the `checkpoint` action. The central lifecycle validates shape/status, rejects secret-like material, derives Git provenance, writes repository-scoped continuity, commits it, and pushes when enabled.

Network Git operations use the normal Git credential chain first. If a private `github.com` operation fails and GitHub CLI is available, the lifecycle retries through `gh auth git-credential` without embedding tokens in configuration or command arguments. A clean cache may migrate its `origin` when the configured context remote changes; a dirty cache refuses automatic origin migration.

Version 1.0 of this installer targets Windows/PowerShell. POSIX lifecycle parity is intentionally not claimed yet.
