---
id: security
title: Security
sidebar_label: Security
---

# Security

Qbit AI Toolkit assets must preserve explicit trust boundaries across source repositories, installer targets, downloads, containers, generated state, and release artifacts.

## Baseline rules

- Never commit credentials, access tokens, private keys, or real production connection strings.
- Example environment files contain placeholders only.
- Downloads used by versioned runtime assets must be pinned and integrity-verified before use.
- Archive extraction must reject traversal, unsafe links, devices, FIFOs, and unsupported special entries.
- Installer writes stay below the validated target Git work-tree root.
- Unowned conflicts are not overwritten.
- Modified owned content is not replaced without the explicit narrow replacement policy and backup evidence.
- Verify and plan operations remain read-only.

## Runtime isolation

Repository AI tooling and emitted installer runtimes use container boundaries to reduce host-side effects. Where applicable, services disable networking, use read-only root filesystems, drop capabilities, and mount the workspace read-only unless a documented semantic-edit operation requires write access.

## GitHub Pages

The documentation workflow requires only repository read permission during build and `pages:write` plus OIDC `id-token:write` during deployment. No deployment secret is stored in the repository.

For the custom Pages domain, verify the domain in the Qbit GitHub organization when possible and avoid wildcard DNS records, which increase subdomain takeover risk.
