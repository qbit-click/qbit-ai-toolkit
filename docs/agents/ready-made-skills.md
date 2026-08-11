---
id: ready-made-skills
title: Ready-made skills
sidebar_label: Ready-made skills
---

# Ready-made skills

Qbit AI Toolkit can publish reusable skills for recurring engineering workflows. The documentation explains what each skill does and its constraints; the versioned skill asset itself belongs under `agent-assets/skills/`.

## Good candidates

Reusable skills are appropriate for workflows such as:

- architecture-impact analysis;
- security review;
- release validation;
- installer development and verification;
- external-library documentation lookup;
- repository governance and validation gates.

## What every published skill should document

A ready-made skill should state its trigger conditions, required tools, supported environments, write permissions, expected outputs, failure behavior, and examples of when not to use it.

## Versioning

Changing a skill's operational behavior can affect multiple repositories even when its filename does not change. Treat behavior changes as versioned assets and keep compatibility expectations explicit for downstream consumers.
