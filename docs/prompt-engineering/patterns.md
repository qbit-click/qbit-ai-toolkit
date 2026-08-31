---
id: patterns
title: Prompt patterns
sidebar_label: Prompt patterns
---

# Prompt patterns

Patterns are reusable structures for common classes of work. They should reduce ambiguity without turning every request into a rigid template.

## Zero-shot first

Start with a direct instruction when the task is well-defined and the model already understands the expected behavior.

```text
Classify the customer message as one of:
- billing
- technical_support
- cancellation
- other

Return the label only.
```

A zero-shot baseline is useful because it tells you whether examples are actually needed.

## One-shot prompting

One-shot prompting is the single-example case between zero-shot and broader few-shot use. Use one precise example when it is enough to demonstrate the required format or convention. One example gives poor edge-case coverage, so evaluate it rather than assuming it generalizes.

## Few-shot examples

Use a small set of examples when the output boundary, labeling convention, edge cases, tone, or transformation is difficult to describe compactly.

```text
Text: "The app crashes when I open settings."
Label: technical_support

Text: "I was charged twice this month."
Label: billing

Text: "Please close my account at the end of the cycle."
Label: cancellation

Text: "Where can I download invoices?"
Label:
```

Choose examples for coverage, not quantity. Include cases that distinguish neighboring classes. Do not assume few-shot prompting always improves performance; verify it on an eval set.

## Role and perspective framing

Role framing can help set vocabulary, audience, tone, or review criteria:

> Review this design from the perspective of a senior security engineer. Focus on trust boundaries, least privilege, secret handling, and rollback risk.

Do not treat fictional credentials as evidence of correctness. Saying "you are a doctor with 20 years of experience" does not give a model medical experience. Prefer explicit expertise criteria and required checks over invented biography.

## Step-back prompting

Step-back prompting asks for the governing principles, criteria, invariants, or domain abstractions before applying them to a concrete case. It is useful when a design or review decision improves by recalling its governing rules, or when an unfamiliar instance needs better framing first.

For example:

```text
Before reviewing this payment-retry design, list the invariants for preventing duplicate charges.
Then assess the supplied design against those invariants and identify any gap.
```

This can be one structured prompt, or separate retrieval/analysis stages when isolation or independent validation matters. It is not a request for hidden Chain-of-Thought: ask for concise, reviewable principles and evidence instead. Treat it as a heuristic to evaluate on representative cases, not a guarantee of greater accuracy or lower bias.

## Decompose complex work

When a task contains dependent decisions, split it into explicit phases.

```text
1. Inspect the supplied requirements and list unresolved decisions.
2. Do not implement while a decision that affects the public API remains unresolved.
3. After decisions are resolved, produce the implementation contract.
4. Validate the result against the acceptance criteria.
```

Decomposition is different from asking for hidden internal reasoning. The purpose is to control observable workflow boundaries.

## Critique and revise

For drafts where quality is subjective, separate generation from review:

```text
Draft a release note for the change.
Then review the draft against these criteria:
- factual accuracy
- no unsupported claims
- user-visible impact first
- under 180 words
Return only the revised final version.
```

For high-stakes tasks, use a separate evaluator or human reviewer rather than asking the same generation to certify itself.

## Structured extraction

Define fields and missing-value behavior:

```text
Extract:
- incident_id
- affected_service
- start_time
- customer_impact

If a value is absent, return null. Do not infer missing values.
```

When an API supports Structured Outputs, encode the contract as JSON Schema instead of depending on prompt text alone.

## Tool-assisted work

Separate read-only discovery from mutation:

```text
First inspect the repository state and configuration using read-only tools.
Before any state-changing action, verify the target, expected impact, and rollback path.
After the change, run the specified validation commands and report the actual results.
```

The application—not the prompt—must enforce permissions.

## Grounded answers

When the answer must come from supplied sources, define source precedence and no-answer behavior:

```text
Answer only from the supplied policy documents.
Cite the document section supporting each material claim.
If the sources do not contain the answer, say "Not supported by the supplied sources" instead of guessing.
```

## Prompt handoff

When one agent designs and another implements, the prompt must be self-contained. Include scope, known facts, decisions, compatibility constraints, failure behavior, files or boundaries, acceptance criteria, and required tests. Do not rely on hidden conversation context.

## Avoid prompt folklore

Phrases such as "be extremely intelligent," "take a deep breath," or elaborate persona stories are not substitutes for requirements. If a technique does not improve a measured outcome, remove it.
