# AI tooling troubleshooting

- If Docker is unavailable, plan and static verify remain usable; Doctor reports
  a host-environment failure.
- If Compose rendering fails, inspect `.ai/tooling/compose.yaml` without changing
  the pinned isolation settings.
- If Serena startup fails, run Doctor and inspect its structured MCP-stage
  result. Do not broaden the tool allowlist.
- If Graphify fails, keep output in `/graphify-output`; never create a
  repository `graphify-out` directory.
- If a hash fails, replace the source only with the exact published artifact.
  Never disable verification or switch to an unverified mirror.
