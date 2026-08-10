---
name: toolkit-governance
description: Use for repository-wide governance, catalog/schema/template ownership, canonical asset placement, and cross-repository consumer boundaries.
---

# Toolkit governance

qbit-toolkit is canonical for its versioned installers, schemas, templates,
prompts, libraries, and tooling. Installer outputs and other repositories consume
those assets; do not create a second source of truth in generated output or a
consumer repository.

1. Identify the canonical asset and every consumer before changing ownership.
2. Distinguish root project-owned files from installer-managed files and preserve
   that boundary through install, verify, and uninstall behavior.
3. Preserve backward compatibility, or document intentional breakage and its
   migration path.
4. Never mutate Git or its index without an explicit user request.
5. Treat qbit-cli as a separate consumer repository. Touch it only when the user
   explicitly authorizes that repository.

See `docs/ai-tooling/architecture.md`.
