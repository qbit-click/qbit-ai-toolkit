---
id: security
title: MCP security
sidebar_label: Security
---

# MCP security

MCP can expose powerful external capabilities to an AI client. Security decisions should therefore be made at the server, transport, credential, and tool-permission layers rather than relying on prompt wording alone.

## Least privilege

Enable only the servers and tools needed for the current workflow. Prefer read-only capabilities by default and require an explicit reason for write, deployment, destructive, or administrative operations.

## Credentials

Do not commit API keys, tokens, or machine-specific secrets in reusable MCP templates. Reference environment variables or approved secret stores and document the required names instead.

## Trust boundaries

Treat tool output as external input. A connected service may return stale, malformed, or adversarial content. Validate important identifiers, paths, and state before acting on them.

## Network and filesystem access

Constrain network destinations and filesystem mounts when the server supports isolation. A tool that only needs repository read access should not receive unrestricted host access.

## Auditability

For state-changing integrations, preserve enough logging to determine which capability was called, with what target, and whether it succeeded. Avoid logging secret values.
