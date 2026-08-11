---
id: codex-chatgpt-web
title: Use ChatGPT Web Models in Codex with codex-chatgpt-web
sidebar_label: ChatGPT Web for Codex
description: Learn how to use ChatGPT Web models, including ChatGPT Pro, inside the native Codex workflow with codex-chatgpt-web on Windows, macOS, and Linux.
keywords:
  - ChatGPT Web for Codex
  - use ChatGPT Web models in Codex
  - use ChatGPT Pro in Codex
  - Codex web models
  - codex-chatgpt-web
  - ChatGPT models in Codex
  - Codex ChatGPT integration
---

# Use ChatGPT Web Models in Codex with codex-chatgpt-web

[`codex-chatgpt-web`](https://github.com/miuuyy/codex-chatgpt-web) is an independent open-source bridge that lets you **use ChatGPT Web models as selectable models inside Codex**. Instead of moving your task to a separate browser chat, the bridge keeps Codex as the native task harness and routes the selected model turn through ChatGPT Web.

That distinction is the main reason to use the project: you keep Codex task history, context lifecycle, streaming, tracing, images, approvals, sandboxing, and the native model picker while gaining access to the ChatGPT Web model tiers exposed by your authenticated account.

> `codex-chatgpt-web` is unofficial browser automation and is not an OpenAI API or an OpenAI-endorsed integration. Use it only with your own account and within the applicable ChatGPT, Codex, workspace, and usage policies.

## Why use web models in Codex?

For developers searching for **how to use ChatGPT Web models in Codex**, this project provides a direct answer: it adds routed `ChatGPT Web — ...` entries to the existing Codex model picker instead of creating a second coding interface.

Typical reasons to use it include:

- **Use ChatGPT Web inside Codex:** run a task in the same Codex UI while the selected reasoning turn is handled by ChatGPT Web.
- **Use ChatGPT Pro in Codex:** when the authenticated account exposes Pro, the launcher can add a Pro entry to the Codex model picker.
- **Switch between native Codex models and web models:** the proxy preserves Codex's built-in `openai` provider and live native model catalog, then appends the routed ChatGPT Web models.
- **Keep Codex context and task history:** each browser turn receives the current compiled Codex task context in a fresh ChatGPT Temporary Chat.
- **Keep images and streaming in the same task:** image attachments and visible response activity are routed back into the active Codex task.
- **Optionally reconnect local Codex tools:** Full Harness mode uses MCP plus the OpenAI tunnel so supported ChatGPT Web modes can call tools from the active Codex turn.

The project is designed to change the **model backend**, not the Codex workflow.

## How it works

The high-level path is:

```text
Codex task
   │
   │ Responses + SSE on loopback
   ▼
codex-chatgpt-web launcher/runtime
   │
   │ embedded browser
   ▼
ChatGPT Web / Temporary Chat
   │
   └── optional Full Harness: MCP → OpenAI Tunnel → active Codex tools
```

Codex remains the source of truth for the local task. The bridge runs a loopback Responses service, opens a fresh Temporary Chat for routed browser turns, and streams the result back to Codex. In Full Harness mode, a custom ChatGPT connector can send supported tool calls back to the active Codex task.

## Official project demo

The screenshots below are frames extracted from the upstream project's official `assets/demo.gif` and are included here for setup orientation.

![codex-chatgpt-web launcher setup screen](/img/codex-chatgpt-web/launcher-setup.png)

*Launcher setup flow from the upstream project demo.*

![ChatGPT Web model selection for Codex](/img/codex-chatgpt-web/model-picker.png)

*The project exposes ChatGPT Web choices through the Codex model workflow.*

![Using a ChatGPT Web model in Codex](/img/codex-chatgpt-web/codex-web-model.png)

*A routed ChatGPT Web turn shown in the upstream demo.*

## Browser-only vs Full Harness

The launcher supports two operational modes.

| Mode | Web models | Local Codex tools | Additional setup |
| --- | --- | --- | --- |
| Browser-only | Free/Go: Luna; Plus: Instant–High; Pro: adds Extra High and Pro | No | None beyond launcher sign-in/setup |
| Full Harness | Same account-dependent model set | Non-Pro models: yes when connector is available; Pro: read-only | OpenAI Tunnel + ChatGPT connector |

The exact model choices are account-dependent. The launcher detects the controls exposed to the signed-in ChatGPT account rather than assuming that every account has every tier.

### Important Pro behavior

**Using ChatGPT Pro in Codex is supported when Pro is exposed by the authenticated account**, but current ChatGPT Pro mode does not expose the custom MCP connector required for local tool calls. Pro can still receive the compiled Codex context and use its native capabilities such as web search and research, but it cannot initiate local Codex MCP actions through this bridge.

A practical workflow is to gather repository context or perform local tool work with a supported non-Pro ChatGPT Web mode, then switch to Pro for deeper analysis when appropriate.

## Supported desktop platforms

The upstream project currently publishes launcher packages for:

- Windows x64;
- Linux x64;
- macOS 13+ on arm64 and x64.

The browser flow is manually exercised upstream on macOS and Windows 11, while runtime, tests, and native packaging are gated across the supported operating systems in CI.

## Prerequisites

For the normal launcher path you need:

- Codex installed and working;
- a ChatGPT account;
- Google Chrome or Chromium installed for the sign-in handoff;
- network access to ChatGPT and GitHub releases.

You do **not** need a model API key, system Node.js, system Bun, or a Playwright-managed browser for normal launcher use. The packaged launcher carries its own runtime and uses installed Chrome/Chromium only for the passkey-compatible sign-in handoff; model turns run in the launcher's embedded browser.

Full Harness has additional requirements described later.

## Install on Windows

Open PowerShell and run the launcher installer published by the latest GitHub release:

```powershell
irm https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.ps1 | iex
```

After installation, open the launcher and complete its setup checks.

> Until the upstream project configures platform signing credentials for a release, Windows SmartScreen may show an unknown-publisher warning. The upstream installer verifies the published SHA-256 manifest before installation.

## Install on macOS or Linux

Run:

```bash
curl -fsSL https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh | sh
```

Then open the launcher and continue with the sign-in workflow.

## Run from source

The project can also be run from source:

```bash
git clone https://github.com/miuuyy/codex-chatgpt-web.git
cd codex-chatgpt-web
bun run app
```

The upstream source path currently requires **Bun 1.3.14**. The packaged launcher is usually preferable when your goal is simply to use web models in Codex.

## First-time setup: connect ChatGPT Web to Codex

After installing the launcher:

1. Open the launcher.
2. Start **Sign in**.
3. Complete ChatGPT authentication in the dedicated Chrome/Chromium window opened by the launcher and leave that window open while the launcher verifies the authenticated Temporary Chat composer.
4. Run the launcher's **browser smoke test**.
5. Choose **Install models**.
6. Restart Codex once.
7. Open the Codex model picker and select one of the available `ChatGPT Web — ...` entries.

At this point you can use a **ChatGPT Web model in Codex** without changing to a separate chat application.

The available entries depend on your account. Upstream currently documents the account mapping as:

- Free/Go: `Luna`;
- Plus: `Instant` through `High`;
- Pro: adds `Extra High` and `Pro` when exposed by the authenticated account.

## Using ChatGPT Web models in Codex

Once models are installed, normal usage stays inside Codex:

1. Open or continue a Codex task.
2. Open the native model picker.
3. Select the required `ChatGPT Web — ...` model.
4. Submit the task as usual.
5. The bridge sends the current compiled Codex context to a fresh ChatGPT Temporary Chat.
6. The response, visible activity, images, and supported tool lifecycle are returned to the same Codex task.

This is the key operational benefit: **using web models in Codex does not require maintaining a parallel browser conversation or manually copying repository context between Codex and ChatGPT**.

## Optional: enable the Full Harness

Browser-only mode is sufficient when you only need ChatGPT Web reasoning inside Codex. Enable Full Harness only when supported ChatGPT Web modes also need to invoke tools from the active Codex task.

The current upstream launcher flow is:

1. Complete the normal launcher setup first.
2. Open the **MCP** page in the launcher.
3. Create an OpenAI Tunnel and a regular API key on the same OpenAI account that will use the ChatGPT connector.
4. Enter the Tunnel ID and API key in the launcher and choose **Connect harness**.
5. Enable Developer Mode in ChatGPT.
6. Create a **new** ChatGPT connector using the Tunnel transport.
7. Set Authentication to `None`.
8. Name the connector exactly **`Codex Native2`**.
9. Set connector permissions to **Allow all actions** when that is appropriate for your workspace policy.
10. Run **Verify runtime** in the launcher.

Do not rename or reuse an older `Codex Native` connector. The current direct turn-token contract uses the `Codex Native2` connector identity and upstream verification intentionally rejects the legacy identity instead of silently falling back.

Creating the regular API key for the tunnel does not mean model turns are billed as model API calls; the project uses it for tunnel access. Your OpenAI account and workspace must still permit the requested connector actions.

## What Full Harness preserves

In Full Harness mode, the bridge does not become a second coding agent. Codex still owns:

- the active task;
- filesystem and shell tool definitions;
- sandbox policy;
- approvals;
- command sessions;
- tool results.

The bridge transports the supported ChatGPT Web model's tool decision back to that same Codex turn. Unsupported capabilities fail explicitly rather than silently switching to another model or transport.

## Updating or repairing

Quit the launcher, then run the same platform installer again.

### Windows

```powershell
irm https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.ps1 | iex
```

### macOS/Linux

```bash
curl -fsSL https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh | sh
```

According to upstream, reinstalling replaces the launcher application and embedded runtime while preserving the ChatGPT profile and launcher configuration.

## Health checks and operations

Most current operations are available from the launcher UI:

- **Activity** — structured local logs;
- **Settings → Run doctor** — end-to-end health validation;
- **Settings → Cancel retained browser turn** — clears a retained browser turn after a stopped task;
- **Settings → Remove Codex integration** — restores the previous Codex route before removing the launcher;
- **MCP** — Full Harness and tunnel setup.

For browser diagnostics, the runtime also supports `CODEX_CHATGPT_WEB_BROWSER_DIAGNOSTICS=1`, which makes the browser worker capture a screenshot at every checkpoint during an investigation. Without it, screenshots are normally saved for stalled or failed turns where UI state is needed for diagnostics.

## Security and privacy

Using ChatGPT Web models in Codex changes the data path and should be treated as an explicit trust decision.

Key points from the upstream security model:

- ChatGPT Temporary Chat is a privacy mode, not local inference or anonymity. Prompt data is still processed by OpenAI under the account's settings and applicable policy.
- The Responses bridge listens on loopback (`127.0.0.1`), but another process running as the same OS user can reach that local surface.
- The launcher's browser profile contains sensitive authenticated state. Never sync, upload, attach, or commit it.
- Full Harness can expose write/command capabilities when the ChatGPT workspace, connector permissions, and Codex approval/sandbox policy permit them.
- Repository content, tool output, websites, and prompt text should be treated as untrusted input because they can contain prompt injection.
- The project intentionally fails on unsupported models, missing capabilities, or browser UI drift rather than silently selecting another backend.
- The project is not intended to bypass ChatGPT plans, workspace controls, usage limits, authentication, or product restrictions.

Use Full Harness only on a trusted workstation and with connector permissions that match the intended task.

## Troubleshooting

### ChatGPT Web models do not appear in Codex

- confirm launcher sign-in is valid;
- run the browser smoke test again;
- run **Install models** again;
- restart Codex once;
- run **Settings → Run doctor** and inspect **Activity** for explicit errors.

### Pro is missing

Pro is appended only when the authenticated ChatGPT account exposes that mode. The launcher does not fabricate access to model tiers that are unavailable to the account.

### Local tools are unavailable

If you are in Browser-only mode, that is expected. Configure Full Harness if you need supported non-Pro web models to call Codex tools.

If Full Harness is configured, verify:

- the tunnel is connected;
- ChatGPT Developer Mode is enabled;
- the connector is named exactly `Codex Native2`;
- the connector uses the intended permissions;
- launcher **Verify runtime** passes.

### ChatGPT Pro cannot edit files

That is a current product/bridge limitation, not a setup failure. Pro can receive the compiled Codex context but cannot initiate this project's custom MCP calls. Use a supported non-Pro ChatGPT Web mode for local tool rounds.

### Browser selectors stop working

The project automates ChatGPT's browser UI, which is not a stable API. UI drift can break selectors. Check the upstream repository and releases for updates instead of weakening validation or forcing a fallback.

## FAQ: web models in Codex

### Can I use ChatGPT Web models directly in Codex?

Yes. That is the primary purpose of `codex-chatgpt-web`: it appends account-available ChatGPT Web choices to Codex's native model workflow and routes those selected turns through ChatGPT Web.

### Can I use ChatGPT Pro in Codex?

Yes, when Pro is available on the authenticated ChatGPT account. Pro receives the current compiled Codex context, but current Pro mode cannot use the bridge's custom MCP connector for local Codex tools.

### Do I need an OpenAI API key to use ChatGPT Web in Codex?

Not for normal browser-only model turns. Full Harness requires a regular API key for OpenAI Tunnel access, but the web-model turn itself is still routed through the authenticated ChatGPT browser session rather than a model API key.

### Does this replace Codex?

No. Codex remains the task harness. The project changes the selected model route while preserving the native Codex workflow.

### Is this an official OpenAI integration?

No. It is independent open-source software and upstream explicitly states that it is not affiliated with or endorsed by OpenAI.

## Source references

- Project repository and current setup: [miuuyy/codex-chatgpt-web](https://github.com/miuuyy/codex-chatgpt-web)
- Architecture: [docs/architecture.md](https://github.com/miuuyy/codex-chatgpt-web/blob/main/docs/architecture.md)
- Security model: [docs/security-model.md](https://github.com/miuuyy/codex-chatgpt-web/blob/main/docs/security-model.md)

The setup and capability descriptions on this page were verified against the upstream repository on **2026-08-11**. Because this integration depends on the ChatGPT UI, Codex routing behavior, and launcher releases, re-check upstream documentation when performing a future installation.
