---
id: api-and-model-controls
title: API and model controls
sidebar_label: API & model controls
---

# API and model controls

Prompt text is only one part of model behavior. In API applications, model selection, message roles, tool configuration, structured output, reasoning controls, token limits, and model versioning are part of the contract.

## OpenAI API direction

For new OpenAI integrations, prefer the **Responses API** and the current model-specific documentation. The older Assistants API is deprecated and is scheduled to shut down on **2026-08-26**; do not start new production work on it.

Chat Completions still exists for compatible use cases, but examples in this guide use Responses-era concepts where possible.

## Instructions and message roles

Current Responses inputs can include `developer`, `system`, `user`, and `assistant` roles. `developer` and `system` instructions have higher instruction priority than `user` content.

The top-level `instructions` field behaves like a developer instruction. When using `previous_response_id`, do not assume prior `instructions` are automatically carried forward; supply the instructions required for the new response according to the API contract.

Do not place secrets, authorization rules, or security-critical policy exclusively in a system/developer prompt.

## Structured Outputs

If software needs machine-readable JSON, prefer **Structured Outputs** with a JSON Schema and strict adherence when the selected model supports it.

Prompt-only JSON instructions such as:

```text
Return valid JSON and nothing else.
```

are weaker than an API-enforced schema. Older JSON mode only guarantees syntactically valid JSON; Structured Outputs can constrain the result to the supplied schema subset.

## Function calling and tools

Tools can include provider-built tools, custom functions, file/search capabilities, code execution, computer-use capabilities, and remote MCP servers depending on the platform.

A good tool definition should specify:

- a narrow name and purpose;
- strongly typed parameters;
- descriptions that make selection criteria clear;
- strict schemas where supported;
- application-side authorization and validation.

`tool_choice` or equivalent controls can allow automatic selection, disable tools, require a tool, or force a specific tool depending on the API.

The prompt should explain *when* a tool is appropriate. The application must enforce *whether the action is permitted*.

## Reasoning controls

Reasoning-capable models may expose `reasoning.effort` or product-level thinking controls. These are model-specific and can trade latency/token usage for more reasoning.

Do not hardcode a universal set of reasoning-effort values into reusable documentation without naming the model family. Supported values and defaults change across models.

## Verbosity

Some current models expose a `verbosity` control for response length/detail. Prefer provider controls when they express the desired behavior cleanly, while still defining any hard output contract in the prompt or schema.

## Temperature and top-p

`temperature` and `top_p` are sampling controls on models that support them. Higher temperature generally increases randomness; lower temperature generally makes sampling more concentrated. `top_p` changes the probability mass considered during nucleus sampling.

Do not teach fixed ranges such as "0-0.3 for code" as universal rules. Model families differ, some reasoning configurations restrict or ignore sampling controls, and lower randomness does not guarantee correctness.

When both controls are available, change one at a time unless you have eval evidence that tuning both is beneficial.

## Output token limits

Use the parameter name documented by the endpoint/model. In the Responses API, `max_output_tokens` is the relevant response-level limit. Other APIs and older examples may use names such as `max_completion_tokens`.

A token limit is a hard ceiling, not a reliable instruction for prose length. If a response must fit a business constraint, also specify that constraint in human terms and test it.

## Presence and frequency penalties

Some model families expose penalties that alter token selection based on whether tokens have appeared or how often they have appeared. They can affect repetition and novelty, but support is model-specific and the effect is not equivalent to "better vocabulary."

Do not make these parameters part of a generic prompt recipe unless the selected model documents them.

## Pin versions and run evals

Model prompting behavior can change between snapshots. For production prompts where behavior stability matters:

1. pin a model snapshot or otherwise control the model version when the platform supports it;
2. version the prompt separately;
3. record relevant model settings;
4. run the same eval set before and after prompt/model changes;
5. treat a model migration as a behavior change, not merely a dependency bump.

## Current-vs-historical terminology

When reading older tutorials, map old terms to the API you are actually using. In particular, avoid copying old `max_tokens`, Assistants/Threads, or JSON-mode examples into new code without checking the current reference.
