---
id: evaluation
title: Evaluating prompts
sidebar_label: Evaluation
---

# Evaluating prompts

A prompt is not validated because one example produced a good answer. Treat prompt behavior as a versioned component and evaluate it against representative inputs, edge cases, and failure conditions.

## Define success before tuning wording

Write observable acceptance criteria first. Depending on the use case, criteria may cover:

- factual correctness or groundedness;
- completeness;
- output-schema conformance;
- correct tool selection;
- authorization and safety behavior;
- citation accuracy;
- latency and token cost;
- tone or audience fit;
- refusal, fallback, or escalation behavior.

Avoid criteria such as "sounds smart" unless you define a review rubric.

## Build a representative eval set

Include more than happy paths:

- normal cases;
- ambiguous inputs;
- missing-data cases;
- long or noisy context;
- boundary values;
- multilingual inputs when supported;
- conflicting lower-priority instructions;
- adversarial/prompt-injection attempts;
- a regression case for every important failure previously observed.

The eval set should represent the real distribution you care about, not only examples the prompt author finds easy.

## Expected outputs vs. rubrics

Use exact expected values when the task is deterministic, such as classification labels or extracted IDs.

Use a rubric when multiple outputs may be correct. A rubric can score dimensions such as:

| Dimension | Example question |
|---|---|
| Correctness | Is the conclusion supported by the evidence? |
| Completeness | Are all required fields/sections present? |
| Grounding | Are factual claims supported by allowed sources? |
| Safety | Did the model stay inside the permitted action boundary? |
| Usefulness | Does the answer help the target user complete the task? |

Define what score is required to pass before comparing prompt versions.

## Test behavior, not exact prose

For generative text, prefer assertions about observable behavior over exact string matching. A robust prompt should tolerate harmless changes in wording while preserving required decisions and constraints.

Exact-match checks are appropriate for labels, IDs, strict commands, and other deterministic fields.

## Compare prompt revisions on the same set

When changing a reusable prompt:

1. record the current prompt version and model configuration;
2. run the baseline eval set;
3. make the smallest justified prompt change;
4. run the same set again;
5. compare improvements and regressions;
6. add new failure cases to the permanent regression suite.

Do not remove a difficult test simply because a new prompt fails it unless the product requirement changed.

## Record the execution context

For reproducibility, record what can change behavior:

- prompt/template version;
- model ID/snapshot;
- API endpoint or product mode;
- relevant model parameters;
- tool definitions and permissions;
- retrieval configuration;
- evaluation date;
- dataset/eval-set version.

Model behavior can change across snapshots, so prompt and model changes should be reviewed together.

## Automated and human evaluation

Automated graders are useful for scale, structure, deterministic checks, and well-defined rubrics. Human review is still important for nuanced usefulness, ambiguous requirements, and high-impact decisions.

Do not let a model grader become the only authority for safety-critical behavior. Where possible, use deterministic validators for hard rules and reserve model graders for semantic judgments.

## Security evals

A security eval set should include direct and indirect prompt-injection patterns, attempts to misuse tools, source poisoning, unauthorized resource requests, and requests that encourage the model to claim an action succeeded without evidence.

The expected pass condition is not "the model never sees a malicious prompt." It is that malicious content cannot cross deterministic permission and validation boundaries.

## Structured-output evals

For JSON/schema outputs, test:

- required properties;
- enums and type bounds;
- nullable/missing-value behavior;
- additional-properties policy;
- semantic consistency between fields;
- refusal/fallback representation.

Schema compliance is necessary but not sufficient; a syntactically valid object can still contain wrong data.

## Publish gates

For production prompt assets, define a minimum pass rate or required zero-failure classes. Examples:

- no authorization-boundary failures;
- 100% schema conformance;
- at least 98% correct classification on the reference set;
- no regression in previously fixed critical cases.

The threshold should come from product risk and business requirements, not from a generic prompt-engineering rule.

## Prompt management

If your provider offers prompt IDs, version history, variables, rollback, or linked evals, use them where they fit your deployment model. In this repository, reusable prompts should still be versioned alongside their tests and consumer contract so that behavior changes are reviewable in Git.
