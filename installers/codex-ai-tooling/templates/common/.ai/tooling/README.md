# AI tooling runtime

This directory is the immutable build input for the repository-owned
Serena/Graphify runtime. Bootstrap builds the pinned image without starting
services or installing host dependencies. Runtime services have no network,
read-only root filesystems, dropped capabilities, and no published ports.

Serena state lives under `/serena-state/projects/{{SERENA_PROJECT_NAME}}`.
Graphify output lives only in `/graphify-output`. Doctor mounts persistent state
and `/workspace` read-only and uses tmpfs for ephemeral writes.
