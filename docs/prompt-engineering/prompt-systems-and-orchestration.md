---
id: prompt-systems-and-orchestration
title: Prompt systems and orchestration
sidebar_label: Prompt systems & orchestration
---

# Prompt systems and orchestration

Reliable multi-step AI work usually needs more than one large prompt. A **prompt system** combines role prompts, state, tools, handoff contracts, verifiers, retry rules, and an orchestrator that decides what runs next.

## Core building blocks

- **Prompt** — instructions and context for one task or role.
- **Skill** — reusable operating knowledge: method, checklist, examples, tool guidance, and output schema.
- **Agent** — a model configured with instructions, tools, context/state, and optional delegation behavior.
- **Workflow** — a predefined sequence or graph of stages.
- **Orchestrator** — controls stage order, state transfer, retries, limits, and finalization.
- **Verifier** — deterministic checks, a specialist reviewer, or a human gate that evaluates evidence.

A useful rule is:

> Skills define **how a specialist works**. The orchestrator defines **when that specialist runs**.

## Workflow or agent-driven flow?

Use a **workflow** when mandatory stages are already known:

```text
Intake
  -> Clarify
  -> Implement
  -> Test
  -> Security review
  -> Repair if needed
  -> Final acceptance
```

If testing and security review must always run, encode those gates in the workflow. Do not ask the model whether they are necessary.

Use agent-driven routing when the next step genuinely requires open-ended judgment, such as selecting a specialist, choosing a data source, or decomposing a task into parallel subtasks.

A hybrid design is often best: code owns mandatory gates; agents make bounded decisions inside each gate.

## Recommended implementation -> test -> security architecture

```text
Requirements / acceptance criteria
            |
            v
      +-------------+
      | Implementer |
      +------+-------+
             |
             v
      deterministic tests
             |
       fail / \ pass
           /   \
      repair    v
         ^   security reviewer
         |        |
         +--fail  | pass
                  v
             final acceptance
```

A reviewer should consume **evidence**, not the implementer's confidence. Pass the actual artifact/diff, test output, requirements, known decisions, and relevant logs.

## One chat or separate contexts?

Keep stages in one conversation when continuity matters more than independence: clarification, drafting, or iterative refinement of one artifact.

Use a separate context/session when the stage is intended to provide independent review, should have narrower context, should have different permissions, or should not be anchored on the implementer's explanation. Testing and security review often benefit from this separation.

Do not simulate independence with:

```text
Forget your previous role and now act as an independent security reviewer.
```

inside the same long conversation. The same model still sees the prior context and assumptions.

## Structured handoffs

Pass a compact handoff artifact instead of copying the full transcript:

```yaml
stage: security_review
objective: verify the implemented change
requirements:
  - auth boundary must not change
  - secrets must not be logged
artifacts:
  diff: <reference>
  test_results: <reference>
known_decisions:
  - public API compatibility is required
review_output:
  - status
  - findings
  - evidence
  - required_corrections
```

This reduces hidden coupling and makes context filtering explicit.

## Manager vs handoff

### Manager / agents-as-tools

A central manager retains control and invokes specialists.

Use this when one front door should own user interaction, several specialist results must be aggregated, or budgets/guardrails should be centralized. This is a strong default for `implementation -> test -> security -> final synthesis`.

### Handoff

The current agent transfers control to a specialist.

Use this when routing is dynamic and the specialist should own the next part of the conversation. For fixed mandatory stages, explicit code orchestration is usually more predictable than model-selected handoffs.

## What belongs in a skill?

A `security-review` skill can contain:

```text
- threat-model checklist
- trust-boundary review method
- secret-handling checks
- dependency-risk checks
- evidence requirements
- finding severity rubric
- allowed read-only tools
- output schema
```

Do not put global workflow ordering, unbounded retry logic, run-specific state, or authorization controls into a skill. Those belong to orchestration/application layers.

## Custom GPTs and custom assistants

A custom GPT is useful for packaging one reusable assistant with stable instructions, knowledge, and selected capabilities. It can represent a role such as “Security Reviewer” or “Prompt Designer.”

It is not, by itself, a reliable multi-agent orchestration engine. Manual routing between GPTs/chats can work for personal workflows, but automatic sequencing, retry policies, state transitions, and independent verification should live in an orchestration layer when reliability matters.

For automated systems, prefer an API/agent SDK or another explicit workflow runtime.

## UI-only workflow

If you want to stay entirely inside ChatGPT or Claude UI:

1. clarify requirements in the primary chat;
2. produce a frozen task brief;
3. implement in one chat/assistant;
4. pass the brief + artifact + evidence to a separate test/review context;
5. send findings back to the implementation context;
6. repeat with an explicit attempt limit;
7. run security review in another independent context;
8. maintain a small external run ledger.

This is workable, but coordination is manual and state can drift.

## Programmatic workflow

For repeatability, make the state machine explicit:

```text
CLARIFY -> READY -> EXECUTE -> VERIFY -> SECURITY -> DONE
                          ^        |          |
                          |        v          v
                          +----- REPAIR <-----+
```

Store state explicitly rather than depending on conversation memory.

## Parallel agents

Parallelism helps when reviews are independent:

```text
                 -> dependency review ---+
implementation -> test review -----------+-> aggregator
                 -> security review ------+
```

Do not let parallel agents mutate the same workspace without isolation. Shared mutable state creates races and hard-to-review changes.

## Independence is a design property

A reviewer is more independent when it has a separate context, a separate rubric, read-only access, independent tool evidence, and no access to the implementer's self-justification. A different role name alone does not create independence.

## Recommended reusable architecture

```text
Workflow definition
  -> stage contracts
  -> specialist skills
  -> agent configurations
  -> tools/permissions
  -> verifier gates
  -> bounded repair policy
  -> trace/run ledger
```

Keep workflow definitions separate from skills so the same skill can be reused in several flows.

## Official references

- OpenAI Agents SDK — Agent orchestration: https://openai.github.io/openai-agents-python/multi_agent/
- OpenAI Agents SDK — Handoffs: https://openai.github.io/openai-agents-python/handoffs/
- OpenAI Help — GPTs in ChatGPT: https://help.openai.com/en/articles/8554407-gpts-in-chatgpt
- Anthropic Engineering — Building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic Engineering — Multi-agent research system: https://www.anthropic.com/engineering/multi-agent-research-system
