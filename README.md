# qbit-ai-toolkit

`qbit-ai-toolkit` is the canonical, versioned asset repository for AI-development tooling in the Qbit ecosystem. It stores reusable installers, schemas, templates, prompts, libraries, agent assets, policies, and validation tooling without becoming a consumer product's application codebase.

```text
qbit-cli            ─┐
qbit-console        ─┼── consumes versioned qbit-ai-toolkit assets
future consumers    ─┘
```

The repository is type-oriented, not consumer-folder-oriented. A single canonical asset declares its supported consumers instead of being duplicated for each product.

## Current asset

The first implemented catalog asset is `installer.codex-ai-tooling`, version `1.0.0`. It provides a cross-platform lifecycle contract for repository-owned AI development tooling.

## Documentation

The canonical documentation lives under `docs/`. A Docusaurus application under `website/` renders the English and Persian documentation and deploys it to:

`https://ai-toolkit.qbit.click`

Local documentation development:

```bash
cd website
bun ci
bun run start
```

Persian locale:

```bash
bun run start:fa
```

Production build:

```bash
bun run build
```

## Catalog contract

`catalog.json` is the entry point for machine consumers. It references `schemas/catalog.schema.json` and lists each asset's stable ID, kind, semantic version, relative path, consumers, lifecycle status, description, compatibility metadata, platform support, entrypoints, and optional integrity or release metadata.

Assets use semantic versions. A catalog version points to immutable asset content in the corresponding repository revision.

## Validation

Run repository validation with:

```bash
python tools/validate.py
```

PowerShell and POSIX wrappers are available as `tools/validate.ps1` and `tools/validate.sh`.

## Compatibility note

The repository was renamed from `qbit-toolkit` to `qbit-ai-toolkit`. Existing installer 1.0 on-disk namespaces such as `.qbit-toolkit/` and historical managed-block markers remain compatibility identifiers; they are not renamed implicitly.
