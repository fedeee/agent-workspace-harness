# Session execution

Rules for how an agent uses tools in this harness.

## Parallel tool calls

Issue independent tool calls in one turn. Do not wait for a call that
does not feed the next call.

Wait when the next action needs the result. You must read a file before
you edit it.

Keep plan steps in dependency order. `/implement-plan` reads `Depends on`
and `Files`, groups independent steps into waves, and runs a wave of two
or more steps as worktree workers. That is the default. Steps that
depend on each other stay serial.

## Flake retry

Retry a failed tool call only when the failure is a flake.

Flakes are a network timeout, a dead subagent, and a transient lock.

Do not retry a red test, a type error, or a wrong result. Stop. Find the
cause. Fix the code. Then run the check again.

Cap a flake retry at two attempts. Then stop and report.

## Structural retrieval

Search first. Use grep, glob, and definition or caller lookup.

Read only the span you need. Do not load a whole file unless the task
needs the whole file.

Do not paste entire files into a plan. Write a short summary.

## Long jobs

Start a full test suite, a long compile, or a sidecar restore in the
background. Do other independent work while it runs.

Do not sit idle on a job that will take minutes.

Use `scripts/worktree_agent.sh` when a parallel task needs an isolated
tree.

## Out of scope

Do not add a DAG scheduler, a knowledge graph beside the tree, a message
queue, or extra machines from a skill. See D5 in `_plans/DECISIONS.md`.
Dependency data in a plan file is not an engine. A process that outlives
the session is.
