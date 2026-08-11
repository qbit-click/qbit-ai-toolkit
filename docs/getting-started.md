---
id: getting-started
title: Getting started
sidebar_label: Getting started
sidebar_position: 2
---

# Getting started

Qbit AI Toolkit is currently developed as a source repository. The repository owns the asset catalog, reusable installers, validation contracts, and the documentation site.

## Repository layout

```text
qbit-ai-toolkit/
├── catalog.json
├── schemas/
├── installers/
│   └── codex-ai-tooling/
├── agent-assets/
├── prompts/
├── libraries/
├── templates/
├── docs/
├── website/
├── tests/
└── tools/
```

`docs/` contains canonical documentation. `website/` contains only the Docusaurus application used to render and deploy those documents.

## Documentation development

The documentation site uses Docusaurus and Bun.

```bash
cd website
bun ci
bun run start
```

To run the Persian locale locally:

```bash
bun run start:fa
```

`start` and `start:fa` are single-locale development workflows. Use them while editing one locale, not to validate the language switcher.

To preview both English and Persian together with production-like routing:

```bash
bun run preview
```

The preview builds all configured locales and serves them from one local site. English is available at `/` and Persian at `/fa/`; use this mode when validating the locale dropdown and cross-locale navigation.

Build both locales before publishing:

```bash
bun run build
```

The production site is configured for `https://ai-toolkit.qbit.click` and is deployed by GitHub Actions after documentation or website changes reach `main`.

## Repository validation

Repository metadata and static contracts are validated with:

```bash
python tools/validate.py
```

Platform-specific wrappers and layered tests are available under `tools/` and `tests/`. A successful unit test run does not replace repository validation: catalog, manifest, templates, version pins, and hygiene rules must also agree.

## Documentation-first changes

For behavior or architecture changes:

1. Define the intended contract and compatibility behavior in documentation.
2. Update schemas or catalog metadata when the machine-readable contract changes.
3. Implement the behavior without creating a second source of truth.
4. Add meaningful unit, integration, and E2E coverage where applicable.
5. Validate documentation, implementation, and release metadata together.

Installer compatibility namespaces such as `.qbit-toolkit/` and existing managed-block markers are historical on-disk contracts. The repository rename to `qbit-ai-toolkit` does not implicitly rename those paths; changing them requires an explicit migration design.
