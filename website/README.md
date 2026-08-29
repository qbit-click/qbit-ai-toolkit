# Qbit AI Toolkit documentation template

This directory is both the Qbit AI Toolkit documentation site and the canonical Docusaurus template for Qbit documentation properties.

Consumer documentation sites should clone the structure and shared presentation/testing contracts in this directory, then override only product content, product routes/assets, locale-default routing, deployment base paths, and repository-specific links.

## Toolchain

- Bun `1.4.0`
- Docusaurus `3.10.2`
- React `19`
- TypeScript `~6.0.2`
- Vazirmatn Variable `5.3.0`
- Local search via `@easyops-cn/docusaurus-search-local` `0.55.3`
- Vitest `4.1.11`
- Playwright `1.62.1`
- English default locale
- Persian (`fa`) RTL locale

Install exactly from the committed lockfile:

```bash
bun install --frozen-lockfile
```

Run English locally:

```bash
bun run start
```

Run Persian locally:

```bash
bun run start:fa
```

`start` and `start:fa` are single-locale development servers. Use the production-like preview when validating bilingual routing, locale switching, search, or RTL/LTR behavior.

Build and preview all locales:

```bash
bun run build
bun run preview
```

The preview server listens on `http://127.0.0.1:43177/`; Persian is available under `/fa/`.

Run the complete documentation quality gate:

```bash
bun run check
```

That gate covers TypeScript, unit contracts, production build/integration checks, and Playwright E2E behavior including local search and locale direction.

## Template contract

`template.manifest.json` defines the files and package/config contracts consumers are expected to inherit from this site. Shared CSS and homepage layout CSS should stay byte-for-byte aligned unless the template manifest explicitly marks a field as product-specific.

The production URL is `https://ai-toolkit.qbit.click`. Deployment is handled by `.github/workflows/deploy-docs.yml`; local commands do not publish the site.
