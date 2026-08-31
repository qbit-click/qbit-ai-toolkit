---
id: index
title: Prompt Engineering
sidebar_label: Overview
---

# Prompt Engineering

Prompt engineering is the practice of designing model inputs, instructions, examples, context, tool access, and output contracts so that an AI system behaves predictably enough for the intended task. It is not a collection of magic phrases. Modern prompting is closer to interface and workflow design: make the goal explicit, provide the information that changes the decision, define observable success criteria, and test the result.

This guide was reorganized from the supplied Persian *Prompt Engineering v4* training booklet and revalidated/reconciled against current model/API guidance on **2026-08-31**. Historical techniques from the booklet are retained where they are still useful, but they are separated from current production guidance.

## Learning path

### Foundations

1. **Fundamentals** — what prompts are, how model context works, and how instruction roles differ.
2. **Writing effective prompts** — goal, context, constraints, output contracts, uncertainty handling, and acceptance criteria.

### Techniques

3. **Prompt patterns** — zero-shot, few-shot, examples, step-back prompting, decomposition, critique, extraction, and tool-assisted patterns.
4. **Reasoning and agent patterns** — Chain-of-Thought, self-consistency, ReAct, and Tree of Thoughts as historical/research patterns, plus safer modern guidance for reasoning models.

### Systems and workflows

5. **Prompt systems and orchestration** — workflow vs. agent-driven control, skills, manager/handoff patterns, context isolation, and structured handoffs.
6. **Clarification and verification loops** — readiness gates, clarify-before-execute, bounded repair loops, stop conditions, and runtime verification.

### Production and APIs

7. **API and model controls** — OpenAI Responses API, message roles, Structured Outputs, tools, reasoning effort, sampling controls, and version pinning.
8. **Context and grounding** — context windows, conversation state, ChatGPT memory, tools, and Retrieval-Augmented Generation (RAG).
9. **Security** — prompt injection, system-prompt leakage, least privilege, output validation, and human approval for high-risk actions.
10. **Multimodal prompting** — production contracts for image, video, audio, and document evidence.

### Examples and practice

11. **Code prompting** — production contracts for generating, explaining, migrating, debugging, and reviewing code.
12. **Templates and examples** — reusable templates for teaching, summarization, debugging, support, RAG, extraction, and engineering handoff.
13. **Evaluation** — eval sets, rubrics, regression testing, adversarial cases, prompt optimization, and prompt versioning.
14. **Exercises** — practical exercises with suggested answers.
15. **Glossary and references** — terminology, research papers, and current operational references.

## Repository relationship

Reusable prompt assets belong under `prompts/`. Documentation in this section explains how to design and evaluate them; production prompt files should remain versioned assets with explicit ownership, consumers, and acceptance tests.

## Core principle

A good prompt should reduce unnecessary guessing, but prompt wording alone cannot guarantee correctness, security, authorization, or factuality. Those properties require model choice, grounded data, deterministic application controls, tool permissions, validation, and evaluation.
