---
name: validation-gates
description: Use to select, execute, and report repository validation while minimizing redundant or long-running checks.
---

# Validation gates

1. Determine the minimum validation layer required by the request and affected
   source. Audit source and test bodies before execution.
2. Never rerun a successful layer unless affected source changed. Interrupted,
   timed-out, partial, or handle-lost runs are not passes.
3. Capture long logs outside the repository. Emit no heartbeat or progress messages,
   do not repeatedly poll, tail, or sample active logs, and wait silently for exit
   or the configured timeout. Inspect process or log state only with evidence of a
   stall.
4. Report the exact exit code and passed, failed, and skipped totals. Clearly
   separate authoritative runs from discarded runs.
5. After long gates, audit cleanup and generated artifacts. Preserve Git and index
   state throughout.
6. Stop at the validation boundary requested by the user.
