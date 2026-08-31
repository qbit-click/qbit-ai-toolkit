---
id: code-prompting
title: Code prompting
sidebar_label: Code prompting
---

# Code prompting

Treat generated code as untrusted until it is reviewed and tested. Prompting can accelerate engineering work, but it does not replace repository contracts, security review, or operational controls.

## Generate code

Before generation, specify the language, runtime, framework and dependency versions, repository conventions, public behavior, inputs, outputs, errors, security constraints, and required tests. Verify dependency and version behavior against authoritative project manifests, lockfiles, and current documentation.

## Explain code

Base an explanation on the supplied source and configuration. Mark unknown runtime behavior as unknown; do not invent repository state, deployment settings, or dependencies that were not provided.

## Translate or migrate code

Require observable semantics to be preserved. Call out potential differences in filesystem behavior, concurrency, errors, runtime, and platform before replacing the source implementation, then run regression tests against the old behavior.

## Debug or review code

Request reproducible evidence and separate verified facts from hypotheses. Prefer a root-cause fix to a symptom patch, keep the change minimal and maintainable, and assess security and operational impact. See the existing debugging and engineering-handoff templates for fuller task contracts.

## Safe validation

Do not execute generated or state-changing code directly in production just to see whether it works. Start with read-only diagnostics for live systems. Cover every meaningful applicable layer—unit, integration, and E2E—and document why a layer is genuinely inapplicable. Add regression coverage for the behavior that motivated the change.
