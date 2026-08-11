---
id: reusable-assets
title: Reusable AI assets
sidebar_label: Reusable assets
---

# Reusable AI assets

Reusable assets are versioned building blocks that can be consumed by multiple repositories without copying undocumented local conventions.

## Common asset types

- setup and maintenance scripts;
- configuration templates;
- Docker or repository templates;
- reusable prompt libraries;
- MCP configuration templates;
- agent policies and skills.

## Placement matters

Operational scripts and templates belong with the subsystem that owns their lifecycle. Prompt assets belong under `prompts/`. MCP templates belong under `agent-assets/mcp-configs/`. Skills belong under `agent-assets/skills/`. This keeps ownership and release boundaries explicit.

## Reuse without hidden coupling

A reusable asset should declare its assumptions, supported consumers, version, required inputs, generated outputs, and compatibility behavior. Consumers should not depend on undocumented paths or internal implementation details.

Ready-made **agent skills** are documented under **Agents & Skills** because their design and execution contract is different from general setup tooling.
