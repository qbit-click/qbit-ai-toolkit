# AI tooling onboarding

1. Trust the repository in Codex so `.codex/config.toml` can load.
2. Provide Docker with a Linux amd64 backend and Compose major version 2 or
   newer.
3. Run `.ai/scripts/bootstrap.sh` or `.ai/scripts/bootstrap.ps1`.
4. Run the corresponding Doctor entrypoint.
5. Use Serena only for semantic PowerShell, Bash, and Python operations.
6. Run Graphify explicitly for architecture-wide hypotheses and validate its
   output against authoritative repository evidence.

Context7 authentication is optional. No browser, Sentry, global package, or
application dependency setup is performed.
