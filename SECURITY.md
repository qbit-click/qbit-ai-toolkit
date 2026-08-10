# Security

Report security issues through the Qbit private security process. Do not open public issues containing secrets, exploit details, or customer data.

## Repository policy

Committed files must not contain API keys, OAuth tokens, passwords, private keys, Sentry credentials, Context7 credentials, machine-specific absolute paths, or internal production hostnames. Use placeholders such as `CONTEXT7_API_KEY` only.

Installers must be scoped to repository-owned tooling, avoid global configuration changes, and preserve target-project application dependencies.
