---
id: architecture
title: Architecture
sidebar_label: Architecture
---

# Architecture

`qbit-ai-toolkit` is the canonical, versioned asset source for Qbit consumers. It is not the Qbit CLI, not the Qbit Console, and not an application runtime.

```text
qbit-cli            ─┐
qbit-console        ─┼── consumes versioned qbit-ai-toolkit assets
future consumers    ─┘
```

## Asset ownership

Assets are organized by type rather than by consuming product. A prompt, Docker template, installer, policy, skill, or script remains one canonical asset and declares its supported consumers in metadata.

Do not create parallel `cli/`, `console/`, or `shared/` copies of the same logical asset. Consumer-specific behavior belongs in metadata, explicit variants, or a documented compatibility boundary.

## Repository boundaries

The repository currently has two different AI-tooling concerns:

1. Root `.ai/`, `.agents/`, `.codex/`, and `.serena/` files are project-local tooling used to develop `qbit-ai-toolkit` itself.
2. `installers/codex-ai-tooling/` is a reusable versioned asset that emits equivalent tooling into consumer repositories.

These boundaries must not become implicit build dependencies. The project-local runtime must not self-install the reusable installer, and generated installer output must not replace canonical source.

## Authority

When sources disagree, authority descends from:

1. canonical versioned source and assets;
2. schemas and catalog contracts;
3. automated tests and installer state contracts;
4. committed architecture and compatibility documentation;
5. generated reports, graphs, caches, logs, and summaries.

Derived evidence may support analysis but does not become a source of truth.

## Compatibility namespaces

The repository name is `qbit-ai-toolkit`. Existing installer state paths and managed-block markers containing `qbit-toolkit` are retained as versioned compatibility identifiers for the installer 1.0 contract. Renaming those identifiers requires an explicit migration and cannot be inferred from the repository rename.
