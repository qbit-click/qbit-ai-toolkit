---
id: asset-contract
title: Asset contract
sidebar_label: Asset contract
---

# Asset contract

Every catalog asset declares a stable machine-readable contract.

Required fields include:

- stable unique ID;
- asset kind;
- semantic version;
- repository-relative path;
- supported consumers;
- lifecycle status;
- human-readable description.

Optional metadata may describe minimum compatible consumer versions, supported platforms, entrypoints, integrity data, and release information.

## Canonical source

`catalog.json` is the machine-consumer entry point. It references `schemas/catalog.schema.json`, which delegates individual asset validation to `schemas/asset.schema.json`.

Installer assets also have an installer manifest validated by `schemas/installer-manifest.schema.json`. Catalog version, manifest version, and the asset `VERSION` file must agree.

## Consumer metadata

The current schema recognizes `cli`, `console`, and `shared`. These values describe the existing catalog contract and should not be assumed to identify every future product repository. A future standalone AI Toolkit CLI may require a more explicit consumer identity model before it becomes a catalog consumer.

## Template placeholders

Template source may use placeholders in the `{{PLACEHOLDER_NAME}}` format. Concrete installed or rendered output must not contain unresolved placeholders.

## Integrity

Versioned assets should provide enough immutable metadata for a consumer to verify that the selected version and downloaded artifact are the intended content. Floating versions, mutable image tags, branch selectors, or undocumented generated copies are not authoritative asset identities.
