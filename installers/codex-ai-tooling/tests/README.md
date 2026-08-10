# codex-ai-tooling tests

The `codex-ai-tooling` feature uses explicit test layers. Do not call integration scenarios unit tests.

## Unit

Unit tests call deterministic functions directly and avoid Docker, bootstrap, doctor, npm, Sentry, Context7, browsers, and global configuration.

- PowerShell: `installers/codex-ai-tooling/tests/unit/test-unit.ps1`
- POSIX: `installers/codex-ai-tooling/tests/unit/test-unit.sh`
- Python validator: `tests/unit/test_validate.py`

Covered logic includes slug normalization, TypeScript/Rust/generic profile auto-detection, literal IPv4/IPv6 origin normalization and duplicate handling, exact-line managed-block analysis, malformed marker rejection, insertion-separator metadata, exact prefix/suffix preservation, `AGENTS.md` managed-block ownership, explicit write modes and effective byte hashing, JSON escaping and decoded-control rejection, real UTC calendar validation, strict state parsing, ASCII-only ordinal case-sensitive profile manifests, template override/collision policy, relative path safety, semantic-version validation, catalog/manifest consistency, allowlist checks, Rust metadata checks, and MCP boundary checks.

## Integration

Integration tests exercise installer/verifier/uninstaller behavior against temporary Git repositories without bootstrap or doctor. They cover fresh installs, byte-canonical rewrites, strict state corruption across every consumer, control-character input and state rejection, literal IPv6 duplicate-origin handling, real timestamp validation, case-sensitive ASCII-only ownership paths, installation-timestamp lifecycle, deterministic ownership manifests, JSON display-name escaping, transactional profile migrations, owned-file replacement policy, migration DryRun and rollback, merge preservation, malformed marker failures, state-driven uninstall, project-owned hidden-directory preservation, conflicts, no browser installation, no target-root package-manager or Cargo operations, Rust profile output, and installed-output hygiene.

- PowerShell: `installers/codex-ai-tooling/tests/integration/test-installer.ps1`
- POSIX: `installers/codex-ai-tooling/tests/integration/test-installer.sh`

## E2E

E2E tests cover complete user-visible lifecycles rather than every integration edge case.

- PowerShell: `installers/codex-ai-tooling/tests/e2e/test-e2e.ps1`
- POSIX: `installers/codex-ai-tooling/tests/e2e/test-e2e.sh`

The PowerShell E2E suite covers TypeScript lifecycle, generic lifecycle, Rust lifecycle with an existing project-owned `AGENTS.md`, and forced conflict recovery. The POSIX E2E suite covers TypeScript, generic, and Rust lifecycles where a POSIX shell is available.

## Docker-dependent check

`installers/codex-ai-tooling/tests/e2e/test-docker.ps1` is separate from normal E2E. It runs only when Docker and Docker Compose are available. It creates temporary TypeScript and Rust targets, runs AI-only bootstrap, builds the pinned images, runs doctor, verifies Serena/Graphify versions, verifies Rust `1.85.0` and rust-analyzer for the Rust path, confirms target Cargo files are unchanged, and removes project-specific images and named volumes. It never installs browsers or target-root dependencies.

## Runners

PowerShell:

```powershell
./tools/test.ps1 -Layer unit
./tools/test.ps1 -Layer integration
./tools/test.ps1 -Layer e2e
./tools/test.ps1 -Layer docker
./tools/test.ps1 -Layer all
```

POSIX:

```sh
./tools/test.sh --layer unit
./tools/test.sh --layer integration
./tools/test.sh --layer e2e
./tools/test.sh --layer all
```

On Windows, `tools/test.ps1` checks for direct `sh` and then Git for Windows `sh.exe`. If neither exists, POSIX layers are reported as skipped and not counted as passed.
