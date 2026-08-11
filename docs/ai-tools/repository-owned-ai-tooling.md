---
id: repository-owned-ai-tooling
title: Implementing repository-owned AI tooling
sidebar_label: Repository-owned AI tooling
---

# Implementing repository-owned AI tooling

This guide describes a general architecture and implementation process for adding AI-assisted development tools to a software repository without making those tools implicit owners of the application, Git state, developer machine, or production environment.

The design applies to combinations of:

- local semantic/code-intelligence tools;
- architecture/dependency analyzers;
- MCP servers;
- remote documentation or incident connectors;
- agent skills and routing policies;
- repository-local bootstrap, readiness, doctor, and validation scripts.

Specific products such as Serena, Graphify, Context7, Sentry, Codex, Claude, or another MCP-compatible client are examples of capabilities, not required dependencies.

## 1. Start from responsibility boundaries

Before choosing tools, define what each layer is allowed to own.

| Layer | Owns | Must not implicitly own |
|---|---|---|
| Application repository | source, tests, schemas, migrations, committed architecture records | AI runtime state |
| Host | Git client, container/runtime launcher, AI client/CLI | globally installed copies of every project tool unless intentionally chosen |
| Tooling runtime | local AI utilities, language servers, adapters | application dependency graph or production runtime |
| Remote connectors | explicitly requested external evidence | arbitrary repository source or unrestricted secrets |
| Agent policy / skills | task classification, methods, evidence requirements | global workflow state or authorization enforcement |
| Validator / doctor | proving tooling health and contracts | silently repairing unrelated application code |

Generated graphs, indexes, caches, summaries, and model output are **evidence aids**, not authoritative project truth. Source code, schemas, migrations, tests, and committed decisions remain authoritative unless the project explicitly defines another source of truth.

## 2. Classify capabilities before implementation

Inventory capabilities by responsibility rather than by brand name.

A practical classification is:

1. **Ordinary repository operations** — files, Git inspection, tests, known edits.
2. **Semantic code intelligence** — declarations, references, symbol diagnostics, semantic refactors.
3. **Architecture/dependency analysis** — cross-module graphs, blast radius, dependency hypotheses.
4. **External documentation** — version-specific third-party behavior.
5. **Runtime incident evidence** — traces, errors, releases, production events.
6. **Workflow/review capabilities** — test review, security review, architecture review, prompt/workflow validation.

For every capability define:

- entry conditions;
- authoritative inputs;
- allowed tools;
- read/write permissions;
- expected output;
- validation;
- failure behavior;
- whether network access is required.

Do not add a tool merely because it exists. Every capability should have a real use case and at least one acceptance scenario.

## 3. Prefer explicit routing

Tool availability must not imply tool use.

A routing policy should answer:

```text
What type of task is this?
Which capability is the narrowest one that materially reduces uncertainty?
What evidence should it produce?
When should it not run?
```

Example:

| Task | Preferred path |
|---|---|
| Edit known Markdown/config | built-in file tools |
| Find symbol references | semantic tool |
| Analyze uncertain cross-module impact | scoped architecture analyzer + source validation |
| Check third-party API behavior | locked-version documentation source |
| Investigate a real production incident | read-only incident connector |

Avoid invoking several tools for the same responsibility. A second tool should validate a materially different claim.

## 4. Separate the portable core from language profiles

The reusable tooling core should not hardcode assumptions from one language or framework.

A maintainable split is:

```text
AI tooling core
├── runtime boundary
├── readiness / doctor
├── state and locking
├── protocol adapters
├── validation framework
└── routing contracts

Language/profile layer
├── language server
├── semantic-tool configuration
├── source roots
├── ignore rules
├── profile-specific version pins
└── semantic acceptance fixture
```

This lets the same tooling architecture support TypeScript, Rust, Python, or another stack without duplicating lifecycle logic.

## 5. Choose a runtime ownership model

For local repository tooling, prefer a reproducible project-owned runtime when practical. Common options include:

- a container image;
- a project-local virtual environment;
- a hermetic package-manager environment;
- a checked and pinned binary/tool bundle.

The important property is not “Docker everywhere.” The important property is that tool versions, dependencies, and startup behavior are explicit and reproducible.

A project-owned container is particularly useful when tools need language servers, Python/Node dependencies, native binaries, or different host platforms.

### Local and remote tools are different

Do not apply one network policy blindly to all capabilities.

A strong default is:

- **local analyzers:** no runtime network unless a documented use case requires it;
- **remote connectors:** separate, explicit network-enabled path with minimal data disclosure and scoped credentials.

This prevents a local semantic/graph tool from gaining internet access merely because another connector needs it.

## 6. Harden local tooling runtime

When using containers, consider these defaults where compatible with the tool:

```yaml
read_only: true
cap_drop:
  - ALL
security_opt:
  - no-new-privileges:true
```

Also prefer:

- a non-root runtime identity;
- no privileged mode;
- no host network unless justified;
- no Docker socket mount;
- no published ports for stdio-only tools;
- the narrowest necessary bind mounts;
- explicit writable state/cache mounts;
- secrets supplied at runtime, not committed into configuration.

If a tool genuinely requires a capability that conflicts with these defaults, document the exception and threat boundary instead of silently weakening the whole runtime.

## 7. Make runtime identity real

Running a process as a numeric UID/GID is not always enough. Some tools call OS account APIs and expect the identity to resolve through passwd/group databases.

If the runtime uses a fixed non-root UID/GID, create an actual user/group mapping and validate it.

Check both:

```text
numeric identity
name resolution
home directory
writable state ownership
```

Do not discover identity problems only after a language server or package runtime calls `getpwuid`/equivalent.

## 8. Pin the supply chain

Define one authority for tool versions and keep it machine-readable.

Depending on the ecosystem, pin:

- tool versions;
- base images, preferably by immutable digest when feasible;
- direct and transitive dependencies through lockfiles;
- downloaded artifacts with checksum/signature verification;
- language-server/runtime versions;
- protocol/client compatibility expectations.

Avoid floating `latest` tags and unbounded installer downloads in reproducible tooling.

For higher-assurance environments, add SBOM/artifact-attestation or equivalent supply-chain evidence to the release process.

## 9. Keep authority files explicit

A generic layout can look like:

```text
.ai/
├── policies/
├── scripts/
├── tooling/
│   ├── versions.*
│   ├── container/runtime definition
│   └── profile resources
├── state/          # generated, ignored
└── cache/          # generated, ignored

.agent-or-client-config/
.semantic-tool-config/
.agent-skills/
docs/ai-tooling/
```

The exact paths do not matter. What matters is that each concern has one clear authority:

| Concern | Example authority |
|---|---|
| Versions | version manifest / lockfiles |
| Runtime build | Dockerfile / environment definition |
| Security boundary | Compose/runtime config |
| Readiness/state | one core lifecycle module |
| MCP launcher | one adapter/launcher |
| Architecture analyzer lifecycle | one scoped dispatcher |
| Task routing | agent policy / skills |
| Project profile | language-specific configuration |

Avoid two independent scripts that both “own” repair or state transitions for the same tool.

## 10. Separate bootstrap, readiness, and doctor

These are different operations.

### Bootstrap

Creates or prepares tooling from a known starting point. It may build images or create managed state.

### Quick readiness

Answers: “Can the requested tool run now?”

It should be cheap, conditional, and reusable during normal work.

### Full doctor

Performs deeper diagnostics: versions, identity, state coherence, protocol checks, language runtime, permissions, optional connectors, and lifecycle consistency.

Do not run a full doctor on every prompt or session startup. Reserve it for:

- tooling/version changes;
- explicit maintenance;
- detected inconsistency;
- installation/repair validation.

## 11. Prefer lazy execution

Start expensive capabilities only when their task class requires them.

Examples:

- semantic server starts on the first semantic query;
- architecture graph is built only after the scope is known;
- remote documentation is queried only after the dependency/version is identified;
- incident connectors are used only for a concrete incident.

Avoid background watchers, periodic refreshes, or repository-wide scans unless they have a documented operational need.

## 12. Own state, cache, and locks explicitly

Generated tooling state should be:

- ignored by Git;
- rebuildable;
- namespaced per repository/profile/scope where needed;
- bounded in size or retention;
- protected by a lock/lease if concurrent writers are possible.

Examples:

```text
.ai/state/toolchain.json
.ai/state/doctor.json
.ai/state/locks/
.ai/state/logs/
.ai/cache/
graph-output/<scope-id>/
```

Do not use Git commands such as broad clean/reset operations as a state-management strategy.

## 13. Fingerprint what makes cached state valid

A cached readiness result or architecture graph is reusable only while its relevant inputs remain unchanged.

Fingerprint only authoritative inputs that should invalidate that state, for example:

```text
version manifest
runtime/container definition
profile configuration
launcher/dispatcher code
relevant source files inside an analysis scope
```

Do not invalidate a narrow architecture scope because an unrelated file elsewhere in the repository changed.

## 14. Handle persistent-volume masking

A common container issue is mounting a named volume over a path that already contains files from the image. The volume hides those image-layer files.

If a tool needs immutable runtime resources plus writable managed state, keep them in separate locations:

```text
immutable runtime: /opt/tool-runtime
managed state:     /tool-state
```

Then seed/copy only the required immutable resources into managed state when missing or version-mismatched.

Do not perform uncontrolled package installation at runtime merely because the persistent state is empty.

## 15. Keep MCP stdio clean

For stdio MCP servers, stdout is protocol output.

Rules:

- valid MCP/JSON-RPC messages only on stdout;
- diagnostic logs on stderr;
- suppress build/progress/UI output from wrappers that could contaminate stdout;
- disable interactive menus and ANSI progress where necessary;
- keep stdin/stdout unbuffered enough for protocol expectations;
- forward termination signals and implement bounded shutdown.

A launcher that sometimes emits package-manager or container build progress to stdout can make a healthy server appear protocol-broken.

## 16. Validate the real protocol path

Do not stop at “the process starts.”

For an MCP semantic server, a useful acceptance flow is:

```text
initialize
-> tools/list
-> one real read-only semantic tool call
-> assert non-empty/expected result
-> graceful bounded shutdown
```

Use a real symbol or fixture from the current language profile rather than a hardcoded repository-specific example in the reusable core.

## 17. Test deterministic lifecycle logic separately

Fake transports/mocks and real integration tests serve different purposes.

Use an injected fake transport for:

- timeout/state-machine branches;
- shutdown behavior;
- malformed response handling;
- wrapper exit-code behavior;
- deterministic retry/lock tests.

Use a real integration path for:

- actual protocol exchange;
- real language-server startup;
- tool inventory;
- a real semantic response;
- actual container/runtime boundary.

A fake transport should not replace integration, and integration should not be the only way to test rare lifecycle branches.

## 18. Use independent timeout budgets

Do not hide the entire lifecycle behind one global timer.

Use separate budgets for:

```text
startup
normal tool call
expensive semantic operation
shutdown
external connector call
```

Choose values from observed cold/warm behavior and product requirements. Keep client and server timeout expectations coherent.

A timeout should identify **which phase** failed.

## 19. Scoped architecture analyzers need a dispatcher

Architecture/dependency tools often create expensive derived state.

Use one dispatcher to own:

```text
scope validation
fingerprint
reuse / rebuild decision
state metadata
output location
locks
cleanup of that scope
```

Agents should request an explicit scope rather than executing low-level graph commands directly.

Treat generated graph output as a hypothesis. Validate material conclusions against authoritative source and, where useful, semantic tooling.

## 20. Remote connectors need a different trust boundary

External documentation, issue trackers, observability systems, and remote MCP services require network and credentials.

Apply these rules:

- identify the exact task before invoking the connector;
- send the minimum necessary query/context;
- never send secrets or unrelated internal source;
- use read-only access by default;
- scope organization/project/environment/release identifiers narrowly;
- treat authentication failure as a capability limitation, not a reason to silently substitute another service;
- keep connector credentials outside committed repository content.

## 21. Skills should encode specialist behavior

A skill is a good place for:

```text
entry gate
method/checklist
allowed tools
prohibitions
evidence requirements
output schema
failure behavior
```

Example skill types:

- architecture-impact analysis;
- external-library documentation;
- incident analysis;
- security review.

Do not put global orchestration state, unbounded retry loops, or authorization enforcement inside a skill. Those belong to workflow/application layers.

## 22. Scope-guard AI-assisted implementation

When an AI agent is implementing the tooling itself, protect pre-existing work.

Before mutation, record a baseline such as:

```text
repository root
branch / current revision when relevant
tracked changed paths
staged changed paths
untracked non-ignored paths
hashes of pre-existing modified files that must remain untouched
```

Then define an exact allowlist of paths the implementation may modify.

After each write-capable stage, verify:

```text
changed paths ⊆ allowed paths + pre-existing changed paths
protected pre-existing hashes unchanged
no unexpected generated artifacts tracked
```

Avoid broad rollback commands that could destroy unrelated developer work. If recovery is required, restore only the path owned by the current operation from a same-run backup or another verified recovery source.

For large implementations, separate read-only diagnosis from mutation and use explicit stop conditions. See **Prompt Engineering → Systems & workflows** for clarification, verification, and bounded repair-loop patterns.

## 23. Validation layers

A mature tooling implementation should have several layers.

### Static validation

Check:

- syntax;
- version metadata consistency;
- forbidden floating versions;
- configuration coherence;
- ignore rules;
- unsafe mounts/capabilities;
- unresolved placeholders;
- accidental absolute host paths/secrets.

### Unit tests

Cover pure logic such as:

- fingerprint calculation;
- lock reclamation;
- timeout transitions;
- scope resolution;
- metadata validation;
- process-result classification.

### Integration tests

Cover real runtime behavior:

- container identity;
- local network policy;
- language/runtime presence;
- stdio protocol;
- semantic call;
- architecture dispatcher behavior;
- state reuse/rebuild.

### End-to-end routing tests

Exercise task classes:

```text
ordinary task -> no expensive AI tool
semantic task -> semantic capability
architecture task -> scoped architecture capability + validation
external docs -> remote documentation connector
incident -> read-only incident connector
```

## 24. Validate leaks and cleanup by delta

When checking for leaked processes/containers, record the baseline first.

The correct question is:

```text
what new process/container remains after this run?
```

not:

```text
is any matching process/container currently running?
```

Pre-existing developer sessions should not be mislabeled as leaks created by the validator.

## 25. Documentation is part of the contract

Document at least:

```text
architecture and trust boundaries
version authorities
onboarding
readiness / doctor behavior
tool routing
maintenance and upgrades
troubleshooting
validation commands
known limitations
```

Every lifecycle claim should point to an authority file or automated check. Documentation drift is a tooling defect when operators depend on it.

## 26. Upgrade process

A controlled tool upgrade should normally include:

1. change the version authority;
2. update lockfiles/checksums/digests reproducibly;
3. rebuild the runtime;
4. run static/unit validation;
5. run real integration acceptance;
6. run relevant routing/profile tests;
7. update version/maintenance documentation;
8. review supply-chain/security impact;
9. release the tooling change independently when practical.

Do not let a tool upgrade silently become an application dependency upgrade.

## 27. Troubleshooting patterns worth preserving

Several failures recur across tool stacks:

| Symptom | General cause to check |
|---|---|
| Protocol parse errors | non-protocol stdout contamination |
| Numeric user failures | UID/GID has no real account mapping |
| Offline runtime tries to install packages | required runtime resource not pre-baked/seeded |
| Tool present in image but missing at runtime | volume masks image path |
| Intermittent semantic timeout | cold-start budget too small |
| Shutdown hangs | no independent shutdown deadline/signal forwarding |
| Cached graph/index wrong | incomplete or over-broad fingerprint |
| False process leak | no pre-run process/container inventory |
| Documentation contradicts behavior | authority files and docs evolved separately |
| “Self-test” passes without real logic | test bypasses production state machine |

Preserve these as diagnostic patterns, not as assumptions that every implementation must reproduce the same fix.

## 28. What should remain project-specific

Do **not** make these universal constants in a reusable guide:

- exact tool versions;
- exact timeout values;
- exact semantic symbol used for acceptance;
- module-count thresholds for architecture analysis;
- one repository's branch/commit/hash inventory;
- one package manager's commands;
- one host user's absolute paths;
- one language server or framework profile;
- historical commit/staging strategy.

Put those values in profile/configuration or a project-specific runbook.

## 29. Completion checklist

### Architecture

- [ ] Capability boundaries are explicit.
- [ ] Authoritative project sources are identified.
- [ ] Portable core and language/profile logic are separated.
- [ ] Tool routing has entry and non-entry rules.

### Reproducibility

- [ ] Tool versions are pinned.
- [ ] Lockfiles/checksums/digests are used where applicable.
- [ ] Runtime is reproducible on supported hosts.
- [ ] Generated state is rebuildable and ignored.

### Security

- [ ] Runtime uses least privilege.
- [ ] Writable mounts are explicit.
- [ ] Docker socket/privileged access is absent unless explicitly justified.
- [ ] Local and remote network boundaries are separated.
- [ ] Secrets are not committed or emitted into logs/protocol output.

### Lifecycle

- [ ] Bootstrap, quick readiness, and full doctor have distinct responsibilities.
- [ ] Expensive tools start lazily.
- [ ] State has explicit locks/fingerprints.
- [ ] Timeout phases and shutdown are bounded.

### Validation

- [ ] Static checks exist.
- [ ] Unit lifecycle tests exist.
- [ ] Real integration tests exist.
- [ ] Protocol validation exercises a real useful call.
- [ ] Routing scenarios are tested.
- [ ] Leak detection compares against a pre-run baseline.

### Documentation

- [ ] Architecture, maintenance, onboarding, and troubleshooting are documented.
- [ ] Project-specific values live outside the generic core guide.
- [ ] Documentation claims match authority files and automated checks.

## 30. Design principle

> AI tooling should extend a repository's capabilities without becoming an implicit owner of the repository. Tooling should be scoped, reproducible, auditable, replaceable, and unable to silently broaden its permissions or mutate unrelated project state.

## Further reading

- Docker Compose service configuration and security options: https://docs.docker.com/reference/compose-file/services/
- Docker rootless mode: https://docs.docker.com/engine/security/rootless/
- Model Context Protocol transports: https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
- GitHub supply-chain security: https://docs.github.com/en/code-security/concepts/supply-chain-security/supply-chain-security
- OpenAI Agents SDK orchestration: https://openai.github.io/openai-agents-python/multi_agent/
