# AI tooling architecture

The repository is mounted exactly at `/workspace`. Serena receives it read-write for explicitly approved semantic edits. Graphify and Doctor receive it read-only. Graphify writes only to the separate `/graphify-output` volume; each requested repository-relative scope has its own derived graph metadata and fingerprint.

Serena state and immutable seeded resources use dedicated volumes. The local runtime contains the shared PowerShell/Bash/Python language support plus the selected TypeScript or Rust profile resources.

Local services disable networking, use a read-only container filesystem, `no-new-privileges`, and dropped capabilities. Bootstrap privileges are limited to validating mounts and seeding owned runtime state before privilege drop. The diagnostic identity is a real mapped non-root UID/GID 10001. Doctor uses read-only persistent mounts plus tmpfs and does not repair persistent state.

Graphify is not an MCP server. Agent-facing Graphify wrappers require an explicit scope and own reuse/rebuild decisions. Generated graph evidence never replaces source, schemas, tests, migrations, or committed architecture records.

Project-scoped MCP configuration exposes Serena plus optional remote Context7 and read-only Sentry connectors. Remote connectors have a separate trust boundary from the network-disabled local tooling and are not local readiness requirements.
