This workspace is an agent harness. This git tree holds plans, a
negative-ADR ledger, an offline eval loop, and product code.

Read `CLAUDE.md` and `AGENTS.md` at the workspace root.
Humans start at `README.md`.

- One git repository. Do not add a `repos/` clone manager.
- Never `git push`. Never open SSH. A hook blocks those commands.
- Isolated worktrees: `scripts/worktree_agent.sh <branch>`.
- Read `_plans/DECISIONS.md` before you design.
- Score `_eval/GOLD.csv`. Do not score the example gold file.
- Do not run `/eval-loop` until `GOLD.csv` has at least 20 labelled rows.
- Ignore Postgres MCP connection failures unless the user asked for
  `/eval-loop`, `/mount-production-db`, or sidecar SQL.
- Issue independent tool calls in one turn. Retry flakes only. Cap two.
- Search, then read a span. Do not dump whole files.
- Background a long compile or a full test suite. Do not wait idle.
- Do not add a DAG scheduler, a knowledge graph, a message queue, or
  extra machines from a skill. See D5 in `_plans/DECISIONS.md`.
