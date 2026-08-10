# Migration notes

Version 1.0 keeps the published installer ID, version, profiles, entrypoint
names, and ownership-state location. The host entrypoints now add an explicit
seven-operation process contract and JSON output. Legacy `--force` is no longer
public; use the narrower owned-modified `replace` policy.

The payload replaces the earlier TypeScript/Rust/Playwright/Sentry-oriented
runtime with the validated PowerShell/Bash/Python Serena runtime and CLI-only
Graphify. Playwright and Sentry assets are removed. Existing user content is
never silently migrated: update requires valid ownership evidence and reports
conflicts before mutation.
