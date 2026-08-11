---
id: using-mcp
title: Using MCP
sidebar_label: Configuration & usage
---

# Using MCP

Treat an MCP server as an external capability boundary, not as an invisible extension of the model. Configure only the servers and tools that the workflow actually requires.

## Typical workflow

1. **Identify the capability** — decide whether you need repository analysis, documentation lookup, issue tracking, databases, browser automation, or another integration.
2. **Choose the server** — prefer maintained servers with explicit capability and security documentation.
3. **Configure transport and credentials** — keep machine-local secrets outside committed templates.
4. **Restrict capabilities** — enable only the tools or resources required by the workflow when the client supports allowlists.
5. **Verify initialization** — confirm the server starts, the client can initialize the MCP session, and the expected capabilities are discoverable.
6. **Test a read-only operation first** — validate connectivity and semantics before relying on write operations.

## Configuration templates

Reusable templates should document required environment variables and consumer-specific fields without embedding secrets. Templates belong under `agent-assets/mcp-configs/` when they are intended for reuse across projects.

## Troubleshooting order

Check the client configuration, server process startup, transport connectivity, MCP initialization, capability discovery, and finally the specific tool call. Keeping these layers separate makes failures easier to diagnose.
