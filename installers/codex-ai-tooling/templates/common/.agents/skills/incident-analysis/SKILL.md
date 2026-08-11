---
name: incident-analysis
description: Use only for a concrete runtime incident, issue, trace, release, or event where read-only Sentry evidence is relevant.
---

# Incident analysis

1. Confirm that the request concerns a real incident rather than a hypothetical debugging task.
2. Resolve the exact organization, project, environment, release, issue, or time window before broad searches.
3. Use only the configured read-only Sentry tools: organization/project discovery, resource reads, event search, and issue search.
4. Minimize data disclosure. Do not send unrelated repository source, credentials, tokens, connection strings, or customer secrets.
5. Treat Sentry evidence as runtime evidence, not as authority for source behavior. Validate root-cause claims against repository source, tests, configuration, and release metadata.
6. Do not acknowledge, resolve, update, assign, delete, or otherwise mutate incidents through this skill.
7. If Sentry authentication is unavailable, report the capability limitation instead of substituting an unapproved remote service.
