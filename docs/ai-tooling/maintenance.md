# Maintenance

- Review skills, routing, policies, and linked documentation together. Changes to
  tool responsibility or routing require explicit review.
- Keep root project-owned assets distinct from installer templates; do not sync
  them through installer managed blocks.
- Pin future local runtimes and dependencies to immutable versions. Do not use
  floating versions.
- Keep generated graphs, indexes, caches, logs, reports, builds, temporary files,
  and release output untracked.
- When phase-2 pins change, update the version record and validate compatibility
  before changing runtime configuration.

Phase 1 has no local runtime pins. See [versions](versions.md).
# Phase 2 maintenance

Update a version only with its immutable upstream version and digest, regenerate
the npm lock outside the repository with scripts disabled, and refresh the
appropriate lock record. Python inputs and lock remain byte-identical to the
reviewed installer lock until their dependency set intentionally diverges.

Never add runtime download fallback. The image build is the sole networked
dependency acquisition phase. Runtime resources are manifest-addressed and a
corrupt named-volume set is repaired from immutable image content while locked.
Changes require the focused static/unit gate before any separately authorized
Docker validation.
