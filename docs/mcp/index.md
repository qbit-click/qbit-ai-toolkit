---
id: index
title: Model Context Protocol (MCP)
sidebar_label: Overview
---

# Model Context Protocol (MCP)

MCP is the integration boundary through which an AI client can discover and call capabilities exposed by external servers. This section focuses on using MCP safely and predictably inside development workflows.

## What this section covers

- how to choose and configure an MCP server;
- how tools, resources, and permissions fit into the client/server model;
- how to validate that a server is reachable and exposing the intended capabilities;
- how to limit access and protect credentials;
- how to diagnose common connection and capability failures.

Reusable MCP configuration assets belong under `agent-assets/mcp-configs/`. Product-specific credentials or machine-local secrets must not be committed with those templates.
