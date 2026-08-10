# AI tooling architecture

The repository is mounted exactly at `/workspace`. Serena receives it
read-write for approved semantic edits. Graphify and Doctor receive it
read-only. Graphify writes only to the separate `/graphify-output` volume.
Serena state and resources use dedicated volumes.

All services disable networking, use a read-only container filesystem,
`no-new-privileges`, and dropped capabilities. Bootstrap privileges are limited
to validating mounts and seeding owned runtime state before privilege drop.
Doctor uses only tmpfs and disposable container state and does not repair
persistent state.

Graphify is not an MCP server. Codex config contains only Serena and optional
Context7. Generated evidence never replaces source, schemas, tests, or committed
architecture records.
