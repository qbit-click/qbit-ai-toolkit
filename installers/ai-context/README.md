# AI Context Lifecycle installer

`installer.ai-context` installs the zero-touch AI context lifecycle as a versioned toolkit asset. Version 1.1 supports Windows, Linux, and macOS in two modes:

- `member`: installs repository launchers/config plus managed lifecycle blocks in `AGENTS.md`, `AI_CONTEXT.md`, `.gitignore`, and `.ai-bridge/.gitignore`.
- `central`: installs the canonical lifecycle engines, member launcher templates, checkpoint schema, regression suites, and automation documentation. It seeds project continuity files only when absent; seeded continuity becomes project-owned immediately and is never overwritten or removed by installer update/uninstall.

The installer never runs application dependency installation and never performs `git add`, `git commit`, `git reset`, `git clean`, or `git stash` in the target repository. The lifecycle checkpoint engine performs scoped Git add/commit/push only inside the dedicated central context cache when a validated checkpoint explicitly requests that workflow.

## Platform requirements

- Windows: PowerShell 5.1+ and Git.
- Linux/macOS: Bash, Git, and Python 3.10+ from the host environment.

Both Windows and POSIX launchers/tooling are provisioned by either installer host so a managed repository remains portable after cloning on another supported platform.

## Member install

Windows:

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

Linux/macOS:

```bash
bash installers/ai-context/install.sh \
  --operation install \
  --mode member \
  --target /work/service \
  --project-id example \
  --repository-id example-service \
  --context-remote https://github.com/example/example-ai-context.git \
  --context-branch main
```

## Central install

Run against an existing Git work-tree root for the dedicated context repository.

Windows:

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

Linux/macOS:

```bash
bash installers/ai-context/install.sh \
  --operation install \
  --mode central \
  --target /work/example-ai-context \
  --project-id example \
  --project-display-name Example \
  --repository-id example-ai-context \
  --context-remote https://github.com/example/example-ai-context.git \
  --context-branch main
```

## Operations

- `plan`: read-only conflict/action plan.
- `install`: fresh install or idempotent repeated install.
- `update`: requires ownership state and updates only installer-owned files/blocks.
- `verify`: read-only hash/block verification.
- `uninstall`: removes only installer-owned files/blocks; project-owned central seed files are preserved.

PowerShell uses `-OwnedModified replace`, `-AdoptMatching`, and `-MigrateLegacy`; POSIX uses the equivalent `--owned-modified replace`, `--adopt-matching`, and `--migrate-legacy` switches.

The replace policy permits replacing a modified installer-owned file/block after writing a recovery copy under ignored `.qbit-toolkit/ai-context/backups/`. It never overrides an unowned conflict. Matching adoption explicitly adopts byte-/block-identical pre-existing generated content into installer ownership.

Legacy migration is explicit and fail-closed. It accepts only the recognized pre-installer lifecycle sections plus a semantically equivalent member `config.json`; unknown or modified legacy content remains a conflict. During migration, repository-specific `AI_CONTEXT.md` role text is preserved while the lifecycle/authority tail becomes an installer-managed block.

State is written last to `.qbit/toolkit/installed/ai-context.json`. Mutations snapshot touched files and restore byte-exact content if a write fails. Managed paths reject path traversal and symlink/reparse-point escapes.

## Runtime lifecycle

Member agents select the launcher for the active host:

```text
Windows      .ai/context/context.ps1 start|status|checkpoint
Linux/macOS  bash .ai/context/context.sh start|status|checkpoint
```

The POSIX launcher uses only Python's standard library plus Git. Cache refresh is non-destructive: dirty context caches are never overwritten, diverged caches are not reset, and dirty caches refuse automatic origin migration/checkpointing. Checkpoint content is shape/status validated and secret-like material is rejected before central continuity files are written.

## Security and authority

Context remotes must not embed credentials. Windows runtime Git uses the normal credential chain first and may retry failed private `github.com` operations through `gh auth git-credential` when GitHub CLI is available. POSIX runtime Git delegates authentication to normal Git credential helpers and does not persist credentials in state or configuration.

AI context remains coordination evidence, never implementation authority. Central project continuity is deliberately outside installer ownership after bootstrap.
