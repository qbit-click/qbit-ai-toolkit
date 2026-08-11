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

`start` and `start:fa` are single-locale development servers. Docusaurus does not serve all locales at the same time in dev mode, so do not use the locale dropdown to validate bilingual navigation from those commands.

Preview the complete production-like bilingual site, including the English/Persian language switcher:

```bash
bun run preview
```

The preview command builds all configured locales and serves the generated site at `http://127.0.0.1:3000/`. Persian is available under `/fa/`.

Validate TypeScript and build both locales:

```bash
bun run typecheck
bun run build
```

The production URL is `https://ai-toolkit.qbit.click`. Deployment is handled by `.github/workflows/deploy-docs.yml`; local deployment commands do not publish the site.
