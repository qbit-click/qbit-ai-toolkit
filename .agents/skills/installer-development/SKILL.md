---
name: installer-development
description: Use for installer source, behavior, tests, or assets under installers/**.
---

# Installer development

1. Inspect the affected source and test bodies before editing.
2. Preserve installer ID and version unless the user explicitly requests a change.
3. Keep operations transactional and write installer state last. Verify and
   uninstall must be state-driven; DryRun must be write-free.
4. Never run package install, build, or fetch commands in a target repository root,
   and never install an installer into qbit-toolkit itself.
5. Ensure project-owned content survives uninstall, including Force and backup
   paths.
6. Evaluate Windows and Unix platform parity explicitly.
7. Statically review changed source and regression test bodies before any long gate.

Use `validation-gates` to select and run only the required validation layer.
