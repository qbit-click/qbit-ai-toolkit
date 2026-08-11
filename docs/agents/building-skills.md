---
id: building-skills
title: Building agent skills
sidebar_label: Building skills
---

# Building agent skills

A skill should describe a reusable decision-and-execution workflow, not merely restate a prompt. It needs a clear trigger, bounded scope, required inputs, operational steps, and validation behavior.

## Define the contract

Document:

- **when the skill applies** and when it must not run;
- **required context and inputs**;
- **tools or capabilities** it may use;
- **ordered steps** when later steps depend on earlier results;
- **safety boundaries** for state-changing actions;
- **expected outputs** and completion criteria;
- **failure and escalation behavior** when required information is unavailable.

## Keep skills composable

A skill should solve one coherent class of work. Avoid combining unrelated workflows because they happen to use the same model or tool. Smaller, explicit boundaries make skills easier to test, version, and reuse.

## Avoid hidden assumptions

Do not assume repository paths, credentials, platforms, or available tools unless the skill explicitly requires and verifies them. Product-specific behavior should be parameterized or owned by a product-specific skill.

## Validate behavior

Test representative success paths, missing-input cases, permission failures, and regressions from previous defects. For skills that can mutate repositories or production systems, verify that read-only inspection occurs before mutation and that rollback or recovery expectations are documented.
