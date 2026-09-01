# Agentic Workspace with Anti-Regression Harness

This is an agent **harness**, not an autonomous agent. Copy these files into your
product repository. Coding agents then keep a record of past failures.
They also measure pipeline changes against a frozen gold set.

## The problem

LLM context windows reset. Across chat sessions, agents repeat the same
flawed patterns: hardcoded keyword lists, brittle regular expressions,
and extra configuration dials.

Prompt rules are not memory. A new chat session repeats last week's
failure unless that failure is on disk.

A vibe check is not evaluation. A prompt change can fix one edge case.
It can also raise recall error on the rest of the gold set.

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

Copy this harness into an existing app, or add product code here.
Do not wrap other remotes in a `repos/` folder.

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

Do not keep a pipeline change after a vibe check.
Score the change on a frozen gold set.

There is no separate test-hypothesis skill. `/eval-loop` is that skill.
It runs one observe → hypothesize → test → keep or kill cycle.

#### Write the eval rules

Put the rules in [`_eval/GOLD.md`](_eval/GOLD.md) before the first cycle.

1. Write the target class in one sentence.
2. Write the qualified-row predicate. That is the model's "hit".
3. Label at least **20** rows in [`_eval/GOLD.csv`](_eval/GOLD.csv).
   Set `gold` to `in_class` or `out_class`. `unsure` does not count.
   You also need one labelled qualified row and one labelled excluded row.

A header-only `GOLD.csv` is not valid for `/eval-loop`.
Do not score `GOLD.example.csv`.

#### Write a hypothesis

Put each idea in [`_eval/BACKLOG.md`](_eval/BACKLOG.md).

1. Use the next free id (`H1`, `H2`, …).
2. Write one sentence. Name one predicted metric.
3. Set status to `open`.

`/eval-loop` can also add a new item when it hypothesizes.

#### Run it

Mount the dump first. Then tell the agent the hypothesis id:

```
/eval-loop H1
```

That scores `H1` on the frozen gold set for one cycle.

Other forms:

| Command               | Action                                     |
| --------------------- | ------------------------------------------ |
| `/eval-loop`          | Pick an open item, or write a new one.     |
| `/eval-loop H1`       | Test hypothesis `H1` this cycle.           |
| `/eval-loop observe`  | Refresh the baseline. Write no hypothesis. |
| `/eval-loop continue` | One more cycle after the last one.         |

1. Copy `_local/eval.env.example` to `_local/eval.env`. Fill the dump fields.
2. Run `/mount-production-db`. That restores the dump into a sidecar Postgres.
   The read-only user is `eval_ro`.
3. Run `/eval-loop H1` (or the id you wrote in the backlog).

Keep a change only if precision error drops and recall error does not rise.
Work on one hypothesis per cycle.

These rates are classification error rates. They are not data leakage
(train/test contamination).

| Name in this repo                      | Standard term                         | Formula                                       |
| -------------------------------------- | ------------------------------------- | --------------------------------------------- |
| Precision error (also: precision leak) | False positive rate on qualified rows | `out_class` on qualified / labelled_qualified |
| Recall error (also: recall leak)       | False negative rate on excluded rows  | `in_class` on excluded / labelled_excluded    |

- Qualified row + `out_class` = false positive (model hit; gold says no).
- Excluded row + `in_class` = false negative (gold says yes; the model missed it).
- `labelled_*` ignores `unsure`.

See [\_eval/README.md](_eval/README.md) for the full protocol.

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
