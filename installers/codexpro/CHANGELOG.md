# Changelog

## 1.0.0

- Add a complete Windows CodexPro deployment installer pinned to CodexPro 0.29.0.
- Install or validate required Git, package-manager, Codex CLI, CodexPro, and cloudflared dependencies.
- Apply the Qbit Windows workspace-sandbox/environment patch and host-execution extension.
- Generate and protect the MCP token, write durable deployment configuration, install the reusable launcher, and add the managed `cpx` PowerShell helper.
- Provision or reuse a Cloudflare named tunnel and route the requested public hostname.
- Default long-lived Cloudflare transport to HTTP/2 while allowing explicit `auto` or `quic` selection.
- Add verification and conservative uninstall/rollback entrypoints.
