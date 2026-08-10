# Installer troubleshooting

- Exit 3: use an existing Git work-tree root.
- Exit 4: resolve the reported unowned or user-modified conflict. Replace policy
  applies only to recorded installer-owned files.
- Exit 5: stop and inspect path, ownership, state, payload, or hash integrity.
- Exit 6: rollback succeeded; correct the causal write failure and retry.
- Exit 7: retain all recovery evidence and resolve the incomplete transaction.
- Exit 8: verify or Doctor completed with failed checks.
- Exit 9: another operation owns the lock, or stale ownership is uncertain.
- Exit 10: install the missing host prerequisite without changing the target.

Do not delete state, backups, journals, or locks whose ownership is uncertain.
