# AI tooling maintenance

Treat `.ai/tooling/versions.env`, artifact locks, Debian snapshot lock, hashed
Python requirements, and npm lockfile integrity values as one immutable update.
Regenerate them only through a reviewed dependency update, then validate
downloader retry/resume behavior, image build, Doctor, MCP/LSP smoke, Graphify
lifecycle, and isolation.

Do not install host dependencies, run package managers in the repository root,
or add Playwright/Sentry. Keep Graphify CLI-only and preserve the exact Serena
tool allowlist.
