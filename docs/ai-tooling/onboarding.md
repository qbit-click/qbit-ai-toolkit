# Phase 1 onboarding

1. Open and trust this repository in Codex so project configuration can load.
2. Read root `AGENTS.md` and the relevant skill under `.agents/skills/` before
   broad work.
3. Optionally export `CONTEXT7_API_KEY` in the parent process environment or use an
   approved secret manager. `.env.ai.example` is documentation only.

No bootstrap command exists in phase 1. Serena and Graphify are not installed or
ready; do not claim or depend on those runtime capabilities.
# Phase 2 onboarding

Prerequisites are Docker with Compose and a trusted project-scoped Codex
configuration. Run `.ai/scripts/bootstrap.ps1` on PowerShell or
`.ai/scripts/bootstrap.sh` on Bash to build the pinned image. This step does not
start containers or install host packages. Run the matching doctor script only
after runtime volumes have been initialized by an explicitly started Serena
session.

Use Graphify scripts only for an explicit architecture-wide request. Generated
graphs stay in the project-owned `graphify-output` named volume mounted at
`/graphify-output`; Serena state and Graphify output never belong below the
working tree.
