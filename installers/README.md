# Installers

Versioned installers live here. Each installer has a manifest, platform entrypoints, verifiers, uninstallers, tests, and documentation.

- `codex-ai-tooling`: repository-owned Serena/Graphify runtime, MCP configuration, routing policy, and AI development tooling.
- `codexpro`: complete pinned CodexPro 0.29.0 Windows deployment, including required host dependencies, the Qbit workspace-sandbox/host-execution patch, MCP token, launcher, `cpx` helper, and Cloudflare named-tunnel configuration.
- `ai-context`: zero-touch cross-session AI context lifecycle for member repositories and dedicated central context repositories. Version 1.0 supports Windows/PowerShell hosts.

`installer.codexpro` owns the full Windows installation flow. It receives the deployment hostname/workspace/tunnel parameters from the caller; it does not invent or silently discover a public domain.
