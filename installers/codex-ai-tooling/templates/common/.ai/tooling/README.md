# AI tooling runtime

This directory is the immutable build input for the repository-owned local Serena/Graphify runtime. Bootstrap builds the pinned image without starting long-lived services, installing host dependencies, or installing target application dependencies.

Runtime services use no network, read-only root filesystems, dropped capabilities, `no-new-privileges`, and no published ports. The diagnostic service runs as the mapped non-root `ai-tooling` UID/GID 10001.

Serena state lives under `/serena-state/projects/{{SERENA_PROJECT_NAME}}`. Graphify writes only to `/graphify-output`, where output is namespaced by explicit repository-relative scope. Doctor mounts persistent state and `/workspace` read-only and uses tmpfs for ephemeral writes.

TypeScript language tooling is baked into the shared image. The Rust profile replaces this Dockerfile with a compatible extension that adds the pinned Rust toolchain and `rust-analyzer` without running Cargo in the target repository.
