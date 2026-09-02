# Decisions ledger

This is the live negative ADR ledger for this workspace.
Agents read it before they design.

If an ID has no body in this file, do not treat
`_plans/DECISIONS.example.md` as the live text for that ID.

## Decisions Index

| Subsystem           | Key Decision IDs   | Core invalidation summary                                                                                                                                                                                                                                       |
| ------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Harness](#harness) | D1, D2, D3, D4, D5 | Do not restore a `repos/` clone manager. Do not add ceremony scripts. Track the ledger and gold set in git. Name the mount skill after the job, not the transport. Do not add a DAG engine, a knowledge graph, a message queue, or extra machines from a skill. |

## How to read a status

| Status       | Meaning                                                             |
| ------------ | ------------------------------------------------------------------- |
| **settled**  | Decided against. Do not re-propose without new evidence.            |
| **reversed** | Was decided one way, then overturned. The current answer is stated. |
| **open**     | Named, not settled. Fair to raise — but read the entry first.       |

## How to add an entry

Append at the bottom of the relevant section with the next free ID. Never
renumber. Create the section if it does not exist.

---

## Harness

### D5 — Runtime graph engine in the harness
- **Status**: settled
- **Was**: A DAG scheduler, a knowledge graph beside the tree, a message
  queue, or extra machines, added from a skill to run plan steps or eval
  hypotheses in parallel.
- **Why**: The orchestrator agent already schedules work. A second
  scheduler holds state and makes decisions when no agent turn is
  active. That is a second control plane to debug. It also moves the
  "what runs next" decision away from the agent that can read the code.
- **Do not** add a process, a status store, or a retry loop that outlives
  the session. A script that reads `Depends on` from a plan and prints
  waves is a formatter. It is allowed. The moment it spawns workers,
  polls them, or writes status, it is the engine this entry forbids.
- **Allowed**: `Depends on` and `Files` data in the plan file. Waves
  computed by the orchestrator inside `/implement-plan`. One worktree
  per worker from `scripts/worktree_agent.sh`. Merge by the orchestrator.
- **History**: On 2026-09-02 the broad reading (no parallel task
  execution) was considered and rejected. `session-execution.md` already
  requires parallel tool calls and worktrees for isolated tasks.
  Parallel eval hypotheses stay out for a different reason: a 20-row
  gold set cannot support multiple comparisons. See `/eval-loop`.
