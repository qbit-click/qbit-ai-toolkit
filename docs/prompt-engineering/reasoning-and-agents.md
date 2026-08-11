---
id: reasoning-and-agents
title: Reasoning and agent patterns
sidebar_label: Reasoning & agents
---

# Reasoning and agent patterns

Several well-known prompting papers introduced techniques that were valuable for earlier generations of language models. They remain important concepts, but they should not all be applied as literal prompt recipes to modern reasoning models.

## Chain-of-Thought: historical context

Chain-of-Thought (CoT) prompting demonstrated that showing or eliciting intermediate reasoning could improve performance on some multi-step tasks. Zero-shot CoT popularized instructions such as "think step by step."

For current reasoning models, do not assume that requesting a long visible chain of thought is beneficial. Modern reasoning models already perform internal reasoning, and production systems often expose only the final answer or a reasoning summary. Prefer requests for **verifiable evidence** rather than hidden thought traces.

Prefer:

```text
Solve the problem. Return:
1. the final answer;
2. the formula or key steps needed to verify it;
3. any assumptions that materially affect the result.
```

Instead of requiring the model to reveal every internal reasoning step.

## Reasoning effort

Some APIs expose a model-level reasoning control such as `reasoning.effort`. When available, use that control for the latency/quality trade-off rather than trying to simulate more reasoning with phrases such as "think harder" or repeated requests to think step by step.

Support and allowed values are model-specific. Check the selected model's current documentation.

## Self-consistency

Self-consistency samples multiple candidate reasoning paths or answers and selects an aggregate or majority result. This is an application-level strategy, not a guarantee of truth.

Use it when:

- independent samples provide useful diversity;
- a deterministic verifier or clear answer space exists;
- the additional latency and cost are justified.

Do not use majority vote as a substitute for source verification or deterministic validation.

## ReAct

ReAct (Reasoning + Acting) introduced a loop that interleaves reasoning, actions, and observations. In modern agent systems, the useful production abstraction is usually:

```text
model decision -> tool call -> tool result -> next model decision
```

You normally do not need to expose a literal `Thought:` field to the user. The important properties are tool selection, permission boundaries, observation handling, stop conditions, retries, and validation.

ReAct is therefore better treated as an **agent orchestration pattern** than as a magic prompt template.

## Tree of Thoughts

Tree of Thoughts explores multiple candidate branches, evaluates them, and continues promising branches. It is useful as a research/orchestration idea for search-heavy problems, but it usually requires multiple model calls, a scoring strategy, or explicit search logic.

Do not teach it as a single sentence that automatically makes a model "reason better."

## Plan-then-execute

A practical modern pattern is to separate planning from execution when the task is long or stateful:

```text
Before changing anything:
- inspect the current state;
- identify dependencies and irreversible operations;
- produce a short execution plan.

Then execute only the approved plan and verify each externally observable result.
```

This pattern controls workflow without demanding private reasoning.

## Verification beats verbosity

For math, code, research, and operational work, ask for artifacts that can be checked:

- equations and substituted values;
- citations to sources;
- tests and test results;
- diffs;
- tool outputs;
- assumptions and uncertainty;
- explicit pass/fail criteria.

A longer explanation is not automatically a more reliable answer.

## When to use multiple agents

Use separate generator/reviewer or planner/executor roles when the separation creates a real control boundary—for example independent review, different tool permissions, or different context. Merely telling one model to "act as two agents" does not create independence.
