---
id: clarification-and-verification-loops
title: Clarification and verification loops
sidebar_label: Clarification & verification loops
---

# Clarification and verification loops

Two reusable prompt-system patterns solve many reliability problems:

1. **Clarify before execute** — do not start a materially ambiguous task until required decisions are resolved.
2. **Verify and repair** — after execution, test observable results and iterate only when evidence shows a defect.

These patterns work best when the orchestrator controls state and iteration. A prompt can define the policy, but a true external loop needs a runtime that can call tools, observe results, and decide whether another iteration is allowed.

## Pattern 1: Clarify before execute

The weak version is:

```text
Ask questions before you start.
```

That instruction is too vague. The model may ask unnecessary questions, miss a critical one, or start execution before the requirements are actually ready.

A better design uses a **readiness gate**.

## Define required fields

For a general task, readiness might depend on:

```text
- goal
- target user/system
- required inputs
- constraints
- output contract
- acceptance criteria
- risk/permission boundary when relevant
```

Not every task needs every field. The system should define which fields are required for that workflow.

## Define material ambiguity

Ask a question only when the missing answer can materially change one of these:

- architecture or implementation;
- public behavior;
- security or permission boundary;
- irreversible action;
- output format consumed by another system;
- acceptance criteria.

For minor ambiguity, state a safe assumption and continue if the workflow allows it.

## Clarification state machine

```text
INTAKE
  -> extract known facts
  -> identify missing required fields
  -> classify ambiguities as material/non-material

if material questions exist:
  -> CLARIFY
  -> ask the smallest useful set of questions
  -> merge answers into task state
  -> return to readiness check

if no material questions remain:
  -> READY
  -> freeze task brief
  -> EXECUTE
```

The model should not repeatedly ask questions that have already been answered.

## Prompt template: clarify-before-execute

```text
You are in the INTAKE stage.

Goal:
Turn the user's request into an execution-ready task brief before performing the task.

Required fields:
- objective
- inputs/source of truth
- material constraints
- required output
- acceptance criteria

Clarification policy:
- Ask only questions whose answers can materially change correctness, scope, security, public behavior, or the output contract.
- Do not ask again for information already provided.
- Group independent questions into one turn when practical.
- Ask at most 3 questions in one turn.
- For non-material ambiguity, state the assumption instead of blocking.

Readiness gate:
Do not execute until every required field is either:
1. explicitly known, or
2. covered by an allowed, stated assumption.

When ready, return a short task brief under:
- Objective
- Inputs
- Constraints
- Output contract
- Acceptance criteria
- Assumptions

Then proceed only if the workflow allows automatic execution; otherwise wait for approval.
```

## Freeze the task brief

Once the task is ready, create one canonical brief. Later agents should receive that brief rather than reinterpreting the original conversation independently.

For high-impact work, require explicit approval of the frozen brief before mutation.

## Pattern 2: Verify and repair

The weak version is:

```text
Keep trying until it works.
```

This is unsafe and underspecified. It has no definition of “works,” no iteration limit, no evidence requirement, and no escape path for a wrong requirement or environmental failure.

Use a **bounded verification loop** instead.

## Verification loop

```text
EXECUTE
   |
   v
VERIFY ---- pass ----> DONE
   |
  fail
   v
DIAGNOSE
   |
   v
REPAIR
   |
   +-------------> VERIFY
```

The verifier decides based on observable checks.

## Verification order

Prefer this order:

1. deterministic checks;
2. integration/runtime checks;
3. specialist model review for semantic issues;
4. human review for high-impact or subjective decisions.

Do not use “the same model says its answer is correct” as the only verifier.

## Define pass criteria before the loop

Examples:

```text
PASS when:
- all required automated tests pass;
- no new lint/type errors are introduced;
- output matches the schema;
- required security checks have no blocking finding;
- acceptance criteria are all evidenced.
```

The verifier should return structured failure information, not just `failed`.

Example:

```yaml
status: fail
failed_checks:
  - id: test_payment_retry
    evidence: "expected 1 record, got 2"
failure_class: idempotency
recommended_scope: payment retry persistence only
```

## Repair policy

A repair stage should:

1. inspect the actual failing evidence;
2. identify the smallest plausible root cause;
3. change only the necessary scope;
4. re-run the failed check;
5. run the relevant regression set;
6. record the attempt.

Do not let repair silently change requirements to make tests pass.

## Stop conditions

A loop must stop on more than success.

Stop and escalate when any of these occurs:

- maximum attempts reached;
- the same failure repeats without new evidence;
- fixing the failure requires a new product decision;
- the requested fix would violate a security or compatibility boundary;
- the environment/tool is unavailable;
- a new failure class indicates the repair is expanding scope;
- verification cannot distinguish success from failure reliably.

## Attempt budget

A simple policy:

```text
max_attempts: 3

attempt 1:
  fix the evidence-backed defect

attempt 2:
  re-evaluate root cause using new evidence

attempt 3:
  final bounded correction

if still failing:
  stop and return an escalation report
```

The right number is workflow-specific. The important property is that it is explicit and finite.

## Prompt template: bounded repair loop

```text
You are operating inside a bounded verification loop.

Acceptance criteria:
[CRITERIA]

Current artifact:
[ARTIFACT]

Verifier evidence:
[EVIDENCE]

Attempt:
[CURRENT] of [MAX]

Rules:
- Treat verifier evidence as authoritative for the current failure.
- Do not change requirements to make the check pass.
- Make the smallest correction that addresses the evidenced root cause.
- After the change, run the specified verification again.
- If verification passes, stop.
- If it fails, record the new evidence before another repair.
- Stop early if a missing product decision, security boundary, unavailable dependency, or scope expansion prevents a safe correction.
- Never exceed the maximum attempt count.

Return after each iteration:
- status
- change made
- evidence
- remaining failures
- next action
```

## Prompt loop vs runtime loop

This distinction is critical.

### Prompt-level self-review

A single request can say:

```text
Draft the answer, check it against the rubric, fix any detected issue, then return only the final version.
```

This is useful for low-cost internal revision, but the checks are still performed within the same model execution/context.

### Runtime verification loop

A real loop is controlled outside the prompt:

```text
model produces artifact
-> test tool runs
-> orchestrator reads result
-> model receives failure evidence
-> model repairs
-> test tool runs again
```

Use the runtime loop when verification depends on external truth: tests, files, API responses, database state, browser behavior, security scanners, or independent reviewers.

## Do not create infinite autonomous loops

“Continue until perfect” is not a valid production stop condition. Perfection is undefined and an agent can consume unbounded time/cost or repeatedly mutate a system without convergence.

Always define:

- what success means;
- who measures it;
- maximum attempts/turns/time/cost;
- allowed mutation scope;
- escalation conditions;
- rollback/recovery behavior where state changes are involved.

## Separate implementer and verifier when independence matters

A strong pattern is:

```text
Implementer context
  -> artifact + evidence
Verifier context (read-only)
  -> pass / structured findings
Implementer context
  -> repair from findings
```

The verifier should not receive the implementer's persuasive explanation unless that explanation is itself evidence that must be reviewed.

## Keep a run ledger

For long workflows, record:

```yaml
workflow_id: task-123
state: VERIFY
attempt: 2
requirements_version: 4
artifact_version: 7
checks:
  unit: pass
  integration: fail
  security: pending
last_failure: retry-idempotency
```

The ledger should be application state, not a fact the model is expected to remember perfectly from a long conversation.

## Common anti-patterns

Avoid:

- `keep trying until it works` without a limit;
- asking the implementer to be the only judge of success;
- repeating the same fix without new evidence;
- allowing tests to be edited merely to produce green output;
- re-running expensive full validation when a cheaper targeted check can safely diagnose the next step;
- hiding unresolved assumptions inside a repair loop;
- letting a reviewer mutate the artifact it is supposed to independently inspect.

## Recommended combined flow

```text
INTAKE
  -> CLARIFY until READY
  -> freeze task brief
  -> EXECUTE
  -> deterministic VERIFY
      -> fail: bounded REPAIR loop
  -> independent REVIEW
      -> fail: bounded REPAIR loop
  -> SECURITY GATE
      -> fail: bounded REPAIR or escalation
  -> FINAL ACCEPTANCE
```

This pattern scales from a manual ChatGPT/Claude workflow to a programmatic multi-agent system because the contracts and stop conditions are explicit.
