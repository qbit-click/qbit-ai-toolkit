# Release preparation

Release packaging is deterministic: ordinal path ordering, normalized relative
paths, LF text, stable timestamps/modes, and no caches, generated state,
`node_modules`, Graphify output, logs, or secrets. A checksum manifest covers
the archive and its installer inventory. Validation extracts into a disposable
directory and reruns static, dry-run, lifecycle, and payload-drift checks.

Packaging does not publish. Commits, tags, pushes, and releases require separate
explicit authorization.
