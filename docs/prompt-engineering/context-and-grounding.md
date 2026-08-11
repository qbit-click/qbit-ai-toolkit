---
id: context-and-grounding
title: Context, memory, tools, and RAG
sidebar_label: Context & grounding
---

# Context, memory, tools, and RAG

Reliable prompting depends on what information the model can actually see. Context management, product memory, retrieval, and tools are related but distinct mechanisms.

## Context window

A model has a finite context window. Depending on the API and model, that window contains some combination of instructions, messages, files, tool calls/results, retrieved content, and reasoning state.

Do not assume that every earlier detail remains equally salient in a long conversation. For long-running workflows:

- keep authoritative requirements compact and explicit;
- summarize stable decisions rather than repeatedly appending the full history;
- pass identifiers and state deterministically when the application can do so;
- detect truncation or context-limit errors instead of silently losing requirements.

## Conversation state in an API

API conversation state is an application/runtime concept. Depending on the platform, you may pass prior items yourself, reference a previous response, or use a conversation/state resource.

State persistence does not remove the need for explicit instructions. For example, OpenAI's Responses API does not automatically carry a previous response's top-level `instructions` forward merely because `previous_response_id` is used.

## ChatGPT memory is a product feature

ChatGPT memory is separate from API context management. As of 2026, ChatGPT can use product-level memory and relevant past context depending on plan, settings, files, and connected apps. The behavior is evolving and should be documented from current product guidance rather than assumed from older "saved memory vs. chat history" diagrams.

For reusable prompts, do not depend on a user's ChatGPT memory unless that dependency is intentional and visible. A prompt intended to work in an API or another product should carry the required context explicitly.

## Tool use

Tools extend the model beyond its pretrained knowledge. Examples include:

- web search for current information;
- file search or document retrieval;
- code execution for deterministic calculations or data analysis;
- custom functions for application actions;
- remote MCP servers for external capabilities.

A prompt should state what evidence or action is needed; the application should provide only the tools required for that job.

## When to retrieve instead of prompt

Do not paste a large knowledge base into a static prompt when the relevant material can be retrieved on demand. Retrieval is appropriate when:

- the source changes more frequently than the prompt;
- only a small subset is relevant to each request;
- citations or source provenance matter;
- access control must filter which documents are available.

## Retrieval-Augmented Generation (RAG)

A typical RAG flow is:

```text
user query
  -> retrieval
  -> filtering/ranking
  -> selected context
  -> model answer
  -> citations / provenance
```

RAG is not simply "add a vector database." Quality depends on the full retrieval system: document quality, chunking, metadata, access control, query formulation, ranking/reranking, context assembly, and citation handling.

## No-answer behavior

Grounded systems need an explicit fallback:

```text
Use only the supplied sources for factual claims.
If the sources do not support the answer, say that the answer is not available from the supplied sources.
Do not fill missing facts from general model knowledge unless the request explicitly allows it.
```

This does not guarantee truth, but it makes unsupported behavior testable.

## Retrieved content is untrusted

A webpage, email, PDF, repository file, or RAG chunk can contain instructions aimed at the model. Treat retrieved content as **untrusted data** by default.

Mitigations include:

- separating instructions from retrieved data;
- restricting tool permissions;
- validating tool arguments and outputs;
- applying authorization before retrieval and before actions;
- requiring human approval for sensitive operations;
- adversarially testing the retrieval pipeline.

RAG and fine-tuning do not eliminate prompt injection.

## Citation discipline

When citations matter, require the answer to identify which source supports each material claim. Then validate that the cited source actually contains the claim. A citation-shaped string is not evidence by itself.

## Context is a budget

Treat context as a budget, not a dump. Prefer the smallest authoritative context that preserves the decisions and evidence required for correctness.
