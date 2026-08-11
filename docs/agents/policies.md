---
id: policies
title: Agent policies
sidebar_label: Policies
---

# Agent policies

Policies define constraints that apply across one or more skills. They should express durable behavioral or security rules rather than task-specific implementation steps.

## Typical policy concerns

- read-only inspection before state changes;
- protection of secrets and credentials;
- allowed or prohibited tools;
- production-safety requirements;
- scope and ownership boundaries;
- validation and evidence requirements;
- rules for asking for missing decisions instead of guessing.

## Skill versus policy

Use a **skill** when you need a reusable workflow for accomplishing a task. Use a **policy** when multiple workflows must obey the same boundary. Avoid duplicating policy text independently in every skill because the copies will drift.

## Repository placement

Reusable policy assets belong under `agent-assets/policies/`. Repository-specific agent instructions may live alongside the repository when they are part of that repository's own governance contract.
