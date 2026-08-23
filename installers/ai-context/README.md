# AI Context Lifecycle installer

`installer.ai-context` installs the zero-touch AI context lifecycle as a versioned toolkit asset. Version 1.0 supports Windows/PowerShell hosts and two modes:

- `member`: installs the repository launcher/config plus managed lifecycle blocks in `AGENTS.md`, `AI_CONTEXT.md`, `.gitignore`, and `.ai-bridge/.gitignore`.
- `central`: installs the canonical lifecycle engine, member launcher template, checkpoint schema, regression suite, and automation documentation. It seeds project continuity files only when absent; seeded continuity becomes project-owned immediately and is never overwritten or removed by installer update/uninstall.

The installer never runs `git add`, `git commit`, `git reset`, `git clean`, `git stash`, or application dependency installation.

## Member install

```powershell
.\installers\ai-context\install.ps1 `
  -Operation install `
  -Mode member `
  -Target C:\work\service `
  -ProjectId example `
  -RepositoryId example-service `
  -ContextRemote https://github.com/example/example-ai-context.git `
  -ContextBranch main
```

## Central install

Run against an existing Git work-tree root for the dedicated context repository:

```powershell
.\installers\ai-context\install.ps1 `
  -Operation install `
  -Mode central `
  -Target C:\work\example-ai-context `
  -ProjectId example `
  -ProjectDisplayName Example `
  -RepositoryId example-ai-context `
  -ContextRemote https://github.com/example/example-ai-context.git `
  -ContextBranch main
```

## Operations

- `plan`: read-only conflict/action plan.
- `install`: fresh install or idempotent repeated install.
- `update`: requires ownership state and updates only installer-owned files/blocks.
- `verify`: read-only hash/block verification.
- `uninstall`: removes only installer-owned files/blocks; project-owned central seed files are preserved.

`-OwnedModified replace` permits replacing a modified installer-owned file/block after writing a recovery copy under ignored `.qbit-toolkit/ai-context/backups/`. It never overrides an unowned conflict. `-AdoptMatching` explicitly adopts byte-/block-identical pre-existing generated content into installer ownership.

State is written last to `.qbit/toolkit/installed/ai-context.json`. Mutations snapshot touched files and roll back byte-exact content if a write fails.

## Security and authority

Context remotes must not embed credentials. Runtime Git uses the normal credential chain first and, for failed private `github.com` operations, may retry through `gh auth git-credential` when GitHub CLI is available. Tokens are not written to tracked configuration or command artifacts.

AI context remains coordination evidence, never implementation authority. Central project continuity is deliberately outside installer ownership after bootstrap.

## Platform scope

Version 1.0 is Windows-only. The POSIX entrypoints intentionally return unsupported rather than pretending lifecycle parity.
