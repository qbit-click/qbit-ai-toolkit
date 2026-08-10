# Rollback and recovery

Install, update, repair, and uninstall are planned before mutation. Replacement
of owned content creates repository-local backups, applies non-state content
first, and publishes ownership state last. A write failure reverses completed
actions and restores backups. Exit 6 means rollback succeeded; exit 7 means
recovery remains required.

Do not delete ownership state or backup evidence to resolve a conflict. Correct
the reported path or restore the recorded backup, then rerun verify before a
new mutation. When ownership evidence is missing or corrupt, the installer does
not infer ownership from filenames.
