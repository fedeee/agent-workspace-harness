# Agent instructions

This is an **agent harness**. This git tree holds plans, a negative-ADR
ledger, an offline eval loop, and product code.

Read [CLAUDE.md](./CLAUDE.md) for the full orchestrator rules.
Humans start at [README.md](./README.md).

Short version:

- One git repository. Do not add a `repos/` clone manager.
- Never `git push`. Never open SSH. A hook blocks `git push`, `ssh`,
  and `git commit --no-verify`.
- Isolated worktrees: `scripts/worktree_agent.sh <branch>`.
- Read `_plans/DECISIONS.md` before you design. If it is missing, read
  `_plans/DECISIONS.example.md` for format only.
- Do not record harness-internal planning in `_plans/` or
  `DECISIONS.md`. Standing harness rules live in `CLAUDE.md` and skills.
- Score `_eval/GOLD.csv`. Do not score `GOLD.example.csv`.
- Do not run `/eval-loop` until `GOLD.csv` has at least 20 labelled
  rows (`in_class` or `out_class`). `unsure` does not count.
- One eval hypothesis per cycle. Keep only if precision error drops
  and recall error does not rise.
- Ignore Postgres MCP connection failures unless the user asked for
  `/eval-loop`, `/mount-production-db`, or sidecar SQL.
- Issue independent tool calls in one turn. Retry flakes only. Cap
  retries at two.
- Search, then read a span. Do not dump whole files into context.
- Background a long compile or a full test suite. Do not wait idle.
  Do not add a DAG scheduler, a knowledge graph, a message queue, or
  extra machines from a skill.

Skills live in `.claude/skills/` and are mirrored under `.cursor/skills/`.
