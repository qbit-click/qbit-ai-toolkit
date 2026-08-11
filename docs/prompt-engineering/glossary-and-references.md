---
id: glossary-and-references
title: Glossary and references
sidebar_label: Glossary & references
---

# Glossary and references

## Glossary

| Term | Meaning |
|---|---|
| Prompt | Input that helps determine the model's next response or action; it may include more than plain text. |
| Prompt Engineering | Designing and evaluating instructions, context, examples, tools, and output contracts for a target behavior. |
| Token | A model's text-processing unit; token boundaries do not map one-to-one to words. |
| Context Window | The maximum context a model can process in one interaction/state window, subject to model and API behavior. |
| Zero-shot | Asking for a task without in-prompt examples. |
| Few-shot | Supplying a small number of examples to demonstrate a task or output convention. |
| Chain-of-Thought (CoT) | Intermediate reasoning traces. Historically, prompting models to emit such traces improved some reasoning tasks; modern reasoning models often reason internally, so production prompts should prefer verifiable summaries/evidence over demanding private reasoning. |
| Reasoning Model | A model family trained/configured to spend additional inference work on complex tasks, often with model-specific reasoning controls. |
| Self-consistency | Sampling multiple candidate reasoning/answer paths and aggregating them. |
| ReAct | A research/agent pattern combining model decisions, actions/tool calls, and observations. |
| Tree of Thoughts | A search/orchestration approach that explores and evaluates multiple candidate reasoning branches. |
| Structured Outputs | API-level schema-constrained model output, typically using JSON Schema on supported models. |
| Function/Tool Calling | Allowing a model to select and provide arguments for external functions/tools that the application executes. |
| MCP | Model Context Protocol, used by compatible systems to expose external tools/resources through standardized servers/connectors. |
| RAG | Retrieval-Augmented Generation: retrieve relevant external content and provide it to the model before generation. |
| Prompt Injection | Malicious or unintended instructions that alter model behavior; can be direct or embedded in external content. |
| System/Developer Instruction | Higher-priority application instructions in APIs that support message-role hierarchies. Not a secure secret store. |
| Hallucination | Model output that is unsupported, fabricated, or incorrect while being presented plausibly. |
| Eval | A repeatable test used to measure model/prompt behavior against defined criteria. |
| Fine-tuning | Updating a model's learned behavior using training data; distinct from supplying examples in a single prompt. |
| AI Agent | A system in which a model can make decisions across multiple steps and use tools or external systems under an orchestration and permission model. |

## Key corrections from the source booklet

The supplied v4 booklet is a strong introductory base, but this documentation makes these changes:

- standardizes the term **Prompt Engineering** instead of the reversed `Engineering Prompt` wording;
- treats Chain-of-Thought prompting primarily as historical/research context and avoids requiring hidden reasoning from modern reasoning models;
- treats ReAct and Tree of Thoughts as orchestration/search patterns rather than one-line prompt tricks;
- replaces fictional-expertise role prompts with explicit review criteria and perspective framing;
- updates OpenAI examples around the Responses API, Structured Outputs, `reasoning.effort`, and `max_output_tokens`;
- avoids universal temperature ranges and other model-agnostic parameter recipes;
- distinguishes ChatGPT product memory from API conversation state;
- states explicitly that the system prompt is not a secret or authorization boundary;
- strengthens RAG guidance around access control, citation validation, and indirect prompt injection;
- makes evals and regression tests part of the prompt lifecycle rather than an optional final review.

## Research foundations

The historical techniques described in this guide originate from widely cited research including:

- Brown et al. (2020), *Language Models are Few-Shot Learners*.
- Wei et al. (2022), *Chain-of-Thought Prompting Elicits Reasoning in Large Language Models*.
- Kojima et al. (2022), *Large Language Models are Zero-Shot Reasoners*.
- Wang et al. (2022), *Self-Consistency Improves Chain of Thought Reasoning in Language Models*.
- Yao et al. (2023), *ReAct: Synergizing Reasoning and Acting in Language Models*.
- Yao et al. (2023), *Tree of Thoughts: Deliberate Problem Solving with Large Language Models*.
- Lewis et al. (2020), *Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks*.

These papers establish techniques in particular model/evaluation settings. They should not be interpreted as guarantees that the same technique improves every current model.

## Current operational references

For implementation guidance, prefer current official documentation over static tutorial parameter tables:

- OpenAI Help Center — *Prompt engineering best practices for ChatGPT*.
- OpenAI Help Center — *Best practices for prompt engineering with the OpenAI API*.
- OpenAI API Reference — Responses API message roles, reasoning controls, tools, and Structured Outputs.
- OpenAI API documentation — model-version compatibility and eval guidance.
- OpenAI Help Center — current ChatGPT Memory documentation.
- OWASP GenAI Security Project — `LLM01:2025 Prompt Injection`.
- OWASP GenAI Security Project — `LLM07:2025 System Prompt Leakage`.
- OWASP GenAI Security Project — current RAG/vector/embedding risk guidance.

## Review date

This documentation was technically reviewed against current public references on **2026-08-10**. Provider behavior changes quickly; re-check model-specific API documentation before copying parameter names, supported values, or lifecycle dates into production code.
