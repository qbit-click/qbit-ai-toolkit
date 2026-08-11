# AI tooling troubleshooting

- **Docker unavailable:** `plan` and static `verify` remain usable. Bootstrap/Doctor report a host-environment failure.
- **Compose render failure:** inspect `.ai/tooling/compose.yaml` and `.ai/tooling/versions.env`; do not remove isolation settings to make Compose pass.
- **MCP JSON/parse failure:** confirm Compose/build progress is not written to protocol stdout and restart Codex after MCP config changes.
- **`getpwuid` / numeric-user failure:** Doctor must resolve UID/GID 10001 as `ai-tooling`; rebuild the pinned image rather than running the container as root.
- **Serena tries to download/install a language server:** the required runtime is missing from the image/profile. Fix the image/lock contract; do not enable network for normal local runtime.
- **TypeScript semantic startup fails:** verify TypeScript 5.9.3 and TypeScript Language Server 5.1.3 are present in `/opt/serena-language-servers` and the TypeScript profile is installed.
- **Rust semantic startup fails:** verify Rust 1.85.0 and `rust-analyzer` are available through the pinned rustup toolchain. Do not run `cargo install` in the target repository.
- **Graphify scope fails:** confirm the scope is a real repository-relative directory without symlink/traversal components. Use `graphify-update` to force a scoped rebuild only after validating the scope.
- **Graphify query times out after a successful build:** distinguish query-time failure from graph construction failure; preserve the graph and narrow the question/scope.
- **Hash/integrity failure:** replace the source only with the exact reviewed artifact/lock update. Never disable integrity verification or switch to an unverified mirror.
- **Optional Context7/Sentry authentication unavailable:** report the remote capability limitation. It does not justify weakening local readiness or substituting an unapproved service.
- **Unexpected persistent-state change during Doctor:** treat it as a failure. Doctor is diagnostic and must not repair persistent state.
