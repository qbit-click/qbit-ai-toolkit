# Contributing

Keep this repository focused on versioned reusable assets. Do not add Qbit CLI or Qbit Console runtime implementation here.

## Rules

- Use JSON for machine-readable catalogs and manifests.
- Keep templates type-oriented and declare consumers in metadata.
- Use LF line endings, UTF-8 without BOM, and final newlines.
- Pin dependency versions; do not use floating selectors such as `latest`.
- Do not commit secrets, local credentials, user-specific paths, generated browser state, or generated Graphify state.
- Preserve target-project dependencies; installers must not modify application package manifests or lockfiles unless that is the asset's explicit contract.

Run `python tools/validate.py` and the relevant installer tests before review.
