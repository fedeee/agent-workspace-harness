This workspace is an agent harness. This git tree holds plans, a
negative-ADR ledger, an offline eval loop, and product code.

Read `CLAUDE.md` and `AGENTS.md` at the workspace root.
Humans start at `ONBOARDING.md`.

- One git repository. Do not add a `repos/` clone manager.
- Never `git push`. Never open SSH.
- Read `_plans/DECISIONS.md` before you design.
- Score `_eval/GOLD.csv`. Do not score the example gold file.
- Do not run `/eval-loop` until `GOLD.csv` has at least 20 labelled rows.
- Ignore Postgres MCP connection failures unless the user asked for
  `/eval-loop`, `/mount-s3-db`, or sidecar SQL.
