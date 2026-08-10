# Process contract

JSON mode emits exactly one final UTF-8 JSON object to stdout; diagnostics use
stderr. Stable fields are `schema_version`, `installer_version`, `operation`,
`target`, `profile`, `dry_run`, `success`, `exit_code`, `detected_state`,
action/conflict/warning/error arrays, `rollback`, and `verification`. Plan and
dry-run results contain no timestamp or run identifier.

Exit codes:

| Code | Meaning |
|---:|---|
| 0 | success |
| 2 | invalid arguments or format |
| 3 | invalid target |
| 4 | deterministic conflict |
| 5 | path, ownership, state, or hash integrity failure |
| 6 | mutation failed and rollback succeeded |
| 7 | rollback/recovery requires attention |
| 8 | verify or Doctor completed with failed checks |
| 9 | active or uncertain concurrent operation |
| 10 | unsupported host or missing prerequisite |
| 11 | transient external failure after retries |
| 12 | unexpected internal error |

Text and JSON modes preserve the same exit code.
