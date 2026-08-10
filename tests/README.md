# Tests

Repository-level tests are organized by feature and layer. The current implemented feature is `installer.codex-ai-tooling`.

Run feature tests through the repository runners:

```powershell
./tools/test.ps1 -Layer all
```

```sh
./tools/test.sh --layer all
```

Layer meanings:

- **Unit:** deterministic functions and validator logic with no installer side effects.
- **Integration:** installer/verifier/uninstaller operations against temporary Git repositories.
- **E2E:** complete user-visible lifecycle workflows.
- **Docker-dependent:** optional bootstrap/doctor validation when Docker is available.

POSIX tests require an existing POSIX shell. The repository does not install one.
Phase 2 root-runtime contracts live in `tests/unit/test_ai_tooling_contract.py`.
The Docker E2E body is `tests/e2e/ai_tooling_docker.py`, with thin PowerShell
and Bash launchers. Docker E2E is opt-in and must never be run as part of the
ordinary focused static/unit gate.
