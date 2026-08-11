---
id: fundamentals
title: Fundamentals
sidebar_label: Fundamentals
---

# Fundamentals

## What is a prompt?

A prompt is the input that helps determine a model's next action or response. Depending on the product and API, that input can include text, images, audio, files, prior messages, retrieved documents, tool results, and higher-priority instructions.

Prompt engineering is the deliberate design of that input and its surrounding execution contract. The goal is not to discover a universally optimal wording; it is to make the intended behavior clear enough to test and maintain.

## How language models respond

A language model generates output token by token from the context available to it. Describing this as "predicting the next token" is a useful mental model, but modern systems may also include multimodal encoders, reasoning processes, tool calls, retrieval, and application-managed state.

Two consequences matter for prompting:

- ambiguity creates more than one plausible continuation;
- irrelevant or conflicting context can compete with the instruction you actually care about.

More text is therefore not automatically better. Add context when it changes the correct answer or decision.

## Instructions and data are different concepts

A robust prompt distinguishes:

- **instructions** — what the model should do;
- **context/data** — material the model should analyze;
- **examples** — demonstrations of desired behavior;
- **output contract** — what the response must look like;
- **fallback behavior** — what to do when required information is missing or confidence is insufficient.

Use headings, delimiters, fenced blocks, XML-like tags, or structured fields when they make these boundaries easier to inspect. Delimiters improve organization, but they are not a security boundary against prompt injection.

## Message roles and instruction hierarchy

Provider terminology differs. In the current OpenAI Responses API, message inputs can use `developer`, `system`, `user`, and `assistant` roles. `developer` and `system` instructions take precedence over `user` instructions, while `assistant` messages normally represent prior model output. The top-level `instructions` field is equivalent to a developer-level instruction.

Do not describe `system` as simply "obsolete." It is still accepted in current APIs. For new application logic, use the role and API pattern documented for the model/provider you are actually integrating.

Tool outputs and retrieved documents should be treated as data unless the application explicitly gives them authority. External content can contain adversarial instructions.

## ChatGPT is not the same as an API integration

A ChatGPT conversation may include product features such as memory, connected apps, files, search, or automatic model routing. An API request only has the state and tools your application supplies or that the selected API persists. Do not infer API behavior from the ChatGPT UI, or vice versa.

## A useful mental model

Treat prompting as a contract between three layers:

1. **Application** — permissions, tools, data sources, validation, retries, and state.
2. **Prompt** — goal, instructions, examples, constraints, and output shape.
3. **Evaluation** — evidence that the combined system behaves correctly across representative inputs.

Prompt quality matters, but production reliability comes from all three layers.
