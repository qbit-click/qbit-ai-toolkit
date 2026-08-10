---
name: release-validation
description: Use for catalog versions, immutable assets, release archives, checksums, tags, GitHub/GitLab release workflows, or consumer compatibility.
---

# Release validation

1. Validate immutable versioned paths and consumer compatibility.
2. Verify archive checksums and manifest/catalog consistency.
3. Distinguish packaging validation from publication.
4. Never create commits, tags, releases, or pushes without explicit user
   instruction.
5. Ensure generated release output does not replace canonical source.
6. Report the exact produced artifacts and their hashes.

Use `validation-gates` and stop at the publication boundary authorized by the user.
