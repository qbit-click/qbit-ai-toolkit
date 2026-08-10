# Qbit AI Toolkit documentation site

This directory contains the Docusaurus presentation and deployment layer for the canonical documentation under `../docs`.

## Toolchain

- Bun `1.3.14`
- Docusaurus `3.10.2`
- English default locale
- Persian (`fa`) RTL locale

Install exactly from the committed lockfile:

```bash
bun ci
```

Run English locally:

```bash
bun run start
```

Run Persian locally:

```bash
bun run start:fa
```

Validate TypeScript and build both locales:

```bash
bun run typecheck
bun run build
```

The production URL is `https://ai-toolkit.qbit.click`. Deployment is handled by `.github/workflows/deploy-docs.yml`; local deployment commands do not publish the site.
