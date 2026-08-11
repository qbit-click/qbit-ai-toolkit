# Rust profile

This profile extends the shared PowerShell, Bash, Python, and TypeScript tooling image with the pinned Rust semantic runtime:

- Rust toolchain `{{RUST_TOOLCHAIN_VERSION}}`
- `rust-analyzer` installed as a rustup component for that exact toolchain
- Rust base image `{{RUST_BASE_IMAGE}}`

The Rust toolchain is built into the repository-owned tooling image. Bootstrap and Doctor do not run `cargo build`, `cargo fetch`, or `cargo install` in the target repository, and they do not modify `Cargo.toml`, `Cargo.lock`, or `rust-toolchain.toml`.

Serena starts `rust-analyzer` through the pinned rustup toolchain declared in the profile-specific `.serena/project.yml`.
