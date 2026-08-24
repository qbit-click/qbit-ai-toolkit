# AI Context Automation

Member repositories run the repository-owned launcher for the active host automatically before substantive Codex work: `.ai/context/context.ps1 start` on Windows or `bash .ai/context/context.sh start` on Linux/macOS. The launcher ensures the central context cache exists, verifies its configured origin/branch, safely refreshes a clean cache, and generates `.ai-bridge/context-runtime.md` plus JSON runtime evidence.

After a substantive validated milestone, the agent writes `.ai-bridge/context-checkpoint.json` and runs the `checkpoint` action. The central lifecycle validates shape/status, rejects secret-like material, derives Git provenance, writes repository-scoped continuity, commits it, and pushes when enabled.

Network Git operations use the host's normal Git credential chain. The Windows PowerShell launcher may additionally retry failed private `github.com` operations through `gh auth git-credential` when GitHub CLI is available. The POSIX launcher deliberately delegates authentication to Git credential helpers and does not persist credentials. A clean cache may migrate its `origin` when the configured context remote changes; a dirty cache refuses automatic origin migration.

Version 1.1 supports Windows/PowerShell and Linux/macOS through Bash plus Python 3.10+. Both launcher/tooling variants are installed so a managed repository remains portable after cloning on another supported host.
