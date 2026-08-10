## Qbit AI tooling

This block describes repository-owned AI tooling installed by `qbit-toolkit`. Existing instructions outside this managed block remain authoritative for project architecture, build commands, test commands, coding conventions, and contribution rules.

- Follow `.ai/policies/tool-boundaries.md` before routing work to AI tools.
- Serena is for semantic PowerShell, Bash, and Python symbol operations; it uses only the configured 12-tool allowlist.
- Graphify is architecture hypothesis support only. Verify its output against source code, tests, committed schemas or migrations, and committed architecture documentation.
- Context7 is for external version-specific library documentation, not internal source-code lookup.
- Playwright and Sentry are not part of this toolchain.
- Bootstrap prepares only repository-owned AI tooling. It must not install target application dependencies.
- Doctor validates only repository-owned AI tooling. It must not modify tracked target files.
