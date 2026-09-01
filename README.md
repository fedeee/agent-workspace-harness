# Agentic Workspace with Anti-Regression Harness

This is a layered workspace harness combining Negative ADRs, Spec-first workflows and Offline empirical eval loops.

## The problem

LLM context windows reset. Across chat sessions, agents repeat the same
flawed patterns: hardcoded keyword lists, brittle regular expressions,
and extra configuration dials.

Prompt rules are not memory. A new chat session repeats last week's
failure unless that failure is on disk.

## The solution

This harness adds three durable layers to your repository:

1. **Plan then implement** (`_plans/`): The agent maps dependencies and
   writes pseudocode before it edits source files.
2. **Negative ADRs** (`_plans/DECISIONS.md`): Classic ADRs record what
   you adopted. This ledger records what you disproved. Agents then skip
   those dead ends.
3. **Offline eval** (`_eval/`): Test one hypothesis against a frozen
   gold set on a local, read-only database sidecar.

```
                  ┌────────────────────────┐
                  │   Agent chat session   │
                  └───────────┬────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
  1. Plan then implement   2. Negative ADRs    3. Offline eval
   (_plans/*.md)           (DECISIONS.md)      (_eval/ + sidecar)
  Map specs first          Skip recorded       Score the hypothesis
                           dead ends           on a frozen gold set
```

## Who's this for

The Agent Workspace Harness is built specifically for software engineers, data scientists, and technical founders who use AI coding agents (like Claude or Cursor) to build, refactor, or maintain data-intensive systems, search pipelines, and classification logic.

## How to use the three layers

### 1. Plan then implement

The agent writes a spec before it edits product code.

Run `/create-plan <description>`. Example:
`/create-plan add-fuzzy-search-fallback`.
The agent writes a markdown file in [`_plans/`](_plans/).

After you review the spec, run `/implement-plan`.
The agent executes the steps in order and checks them off.

### 2. Negative ADRs

The ledger is [`_plans/DECISIONS.md`](_plans/DECISIONS.md).
Classic ADRs record what you adopted. This file records what you disproved.

Memory is automatic. You do not tell the agent to memorize a failure.

- `/create-plan` reads the ledger before it designs.
- `/implement-plan` appends an entry when implementation kills an approach.
- `/eval-loop` appends an entry when a hypothesis is dead.

A new chat session reads that file first. It then skips those dead ends.

### 3. Offline eval

Score one hypothesis on a frozen gold set.
Do not implement the change until a cycle keeps it.

Do this setup once:

1. Write the class rules in [`_eval/GOLD.md`](_eval/GOLD.md).
2. Label at least **20** rows in [`_eval/GOLD.csv`](_eval/GOLD.csv).
   Set `gold` to `in_class` or `out_class`. Do not count `unsure` rows.
   Label one qualified row and one excluded row.
3. Copy `_local/eval.env.example` to `_local/eval.env`. Fill the dump
   fields.
4. Run `/mount-production-db`.

For each idea:

```
/create-plan  →  _eval/BACKLOG.md  →  /eval-loop H1  →  /implement-plan
```

1. Run `/create-plan` with the change you want to measure.
2. Add one open item to [`_eval/BACKLOG.md`](_eval/BACKLOG.md).
   Write one sentence. Name one predicted metric. Use the next free id
   (`H1`, `H2`, …).
3. Run `/eval-loop H1`.
4. If the verdict is keep, run `/implement-plan`.

Keep a change only if precision error drops and recall error does not
rise.

Do not score `GOLD.example.csv`.
See [`_eval/README.md`](_eval/README.md) for metrics and other commands.

## Workspace layout

```
.
├── CLAUDE.md                 # Primary system instructions for agents
├── AGENTS.md                 # IDE entry point (Cursor / Copilot)
├── _plans/                   # Specs + negative ADR ledger
├── _eval/                    # Eval protocol, cycles, gold schemas
├── _local/                   # Machine defaults (eval.env is gitignored)
├── .claude/ / .cursor/ / .github /
└── .mcp.json                 # Shared MCP tool definitions
```

## Quickstart

Agents follow [CLAUDE.md](CLAUDE.md).

```bash
cp _local/eval.env.example _local/eval.env
```

Fill the bucket, region, and database fields before `/mount-production-db`.
Label at least 20 gold rows before `/eval-loop`.

### Commands

| Command                  | Action                                                    |
| ------------------------ | --------------------------------------------------------- |
| `/create-plan <desc>`    | Draft a spec with steps and pseudocode.                   |
| `/implement-plan [file]` | Execute a spec. Check off tasks. Record new dead ends.    |
| `/mount-production-db`   | Restore a production dump into a local sidecar container. |
| `/eval-loop`             | One observe → hypothesize → test → keep/kill cycle.       |
| `/eval-loop H1`          | Test hypothesis `H1` this cycle.                          |
| `/commit`                | Stage and commit this repo. Agents never run `git push`.  |

## Tooling

This design keeps bash small. Most rules live in markdown and skills.

| Path                                  | Role                                                                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/mount-production-db/` | Docker Postgres sidecar: fetch the S3 dump, create `eval_ro`, tear down. Keep the Cursor mirror in `.cursor/skills/` identical. |

Use `git worktree` for parallel agent experiments. Do not change files
in the main checkout.

Use `psql` with the sidecar `DATABASE_URL` to export gold candidates.

## MCP servers

Shared configuration in `.mcp.json`, `.cursor/mcp.json`, and
`.vscode/mcp.json`:

| Server                                                    | Purpose                                        |
| --------------------------------------------------------- | ---------------------------------------------- |
| [Context7](https://github.com/upstash/context7)           | Library and framework docs                     |
| [Playwright](https://github.com/microsoft/playwright-mcp) | Browser automation and end-to-end checks       |
| Postgres sidecar                                          | Read-only database from `/mount-production-db` |

The Postgres MCP server fails on a fresh workspace until you run
`/mount-production-db`. That error is expected. Agents must ignore it unless
the user asked for `/eval-loop`, `/mount-production-db`, or sidecar SQL.
Do not edit `.mcp.json` to hide it.

## Further reading

| Topic            | Where                                 |
| ---------------- | ------------------------------------- |
| Eval protocol    | [\_eval/README.md](_eval/README.md)   |
| Gold rules       | [\_eval/GOLD.md](_eval/GOLD.md)       |
| Hypothesis list  | [\_eval/BACKLOG.md](_eval/BACKLOG.md) |
| Plan format      | [\_plans/README.md](_plans/README.md) |
| Machine defaults | [\_local/README.md](_local/README.md) |

## License

MIT
