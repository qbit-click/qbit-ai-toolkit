---
id: versioning
title: Versioning
sidebar_label: Versioning
---

# Versioning

Qbit AI Toolkit assets use semantic versions. Catalog entries, asset manifests, and asset `VERSION` files must agree.

## Immutable inputs

Lockfiles, dependency hashes, image digests, release checksums, and pinned runtime artifacts are part of the versioned asset contract. Do not use floating dependency versions, mutable image tags, branch names, or unpinned package selectors for release-defining inputs.

## Compatibility

A compatible asset release must preserve stable asset IDs and documented state/ownership contracts. Breaking changes require an intentional version change and a migration path.

The repository rename from `qbit-toolkit` to `qbit-ai-toolkit` does not by itself rename the installer 1.0 on-disk namespaces `.qbit-toolkit/` or existing managed-block markers. Those values are compatibility identifiers and require a separately designed migration if they are ever changed.

## Release discipline

Update one asset version at a time and include validation evidence. Packaging is distinct from publication: creating an archive does not authorize commits, tags, pushes, or releases.
