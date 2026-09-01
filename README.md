# Agentic Workspace with Anti-Regression Harness

An agent **harness**, not an autonomous agent. Copy these files into your
product repository. Coding agents then keep a record of past failures.
They also measure pipeline changes against a frozen gold set.

## The problem

LLM context windows reset. Across chat sessions, agents repeat the same
flawed patterns: hardcoded keyword lists, brittle regular expressions,
and extra configuration dials.

Prompt rules are not memory. A new chat session does not avoid last
week's failure unless you record that failure.

A vibe check is not evaluation. A prompt change can fix one edge case.
It can also raise recall error on the rest of the gold set.

## The solution

This harness adds three durable layers to your repository:

1. **Plan then implement pattern** (`_plans/`): The agent maps dependencies and
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
  1. Plan then implement        2. Negative ADRs      3. Offline eval
   (_plans/*.md)       (DECISIONS.md)       (_eval/ + sidecar)
  Map dependencies     Read past dead ends  Measure the hypothesis
  before you edit      so you do not loop   on a frozen gold set
```

Copy this harness into an existing app, or add product code here.
Do not wrap other remotes in a `repos/` folder.

## Keep / kill protocol

Score a proposed prompt or pipeline change on a frozen gold set. Run
the score on an isolated, read-only sidecar (`eval_ro`).

These rates are classification error rates. They are not data leakage
(train/test contamination).

| Name in this repo                      | Standard term                         | Formula                          |
| -------------------------------------- | ------------------------------------- | -------------------------------- |
| Precision error (also: precision leak) | False positive rate on qualified rows | `false_icp / labelled_qualified` |
| Recall error (also: recall leak)       | False negative rate on excluded rows  | `true_icp / labelled_excluded`   |

- Qualified row + `false_icp` = false positive (tagged in-class; gold says no).
- Excluded row + `true_icp` = false negative (gold says in-class; the model missed it).
- `labelled_*` ignores `unsure`.

Keep a change only if precision error drops and recall error does not
rise. Work on one hypothesis per cycle.

Do not run `/eval-loop` until `_eval/GOLD.csv` has at least **20** rows
with `gold` set to `true_icp` or `false_icp`. `unsure` does not count.
The file must also have at least one labelled qualified row and one
labelled excluded row. A header-only `GOLD.csv` is not valid for
`/eval-loop`.

See [\_eval/README.md](_eval/README.md) for the full protocol.

## Workspace layout

```
.
├── CLAUDE.md                 # Primary system instructions for agents
├── AGENTS.md                 # IDE entry point (Cursor / Copilot)
├── ONBOARDING.md             # Human setup guide
├── _plans/                   # Specs + negative ADR ledger
├── _eval/                    # Eval protocol, cycles, gold schemas
├── _local/                   # Machine defaults (eval.env is gitignored)
├── .claude/ / .cursor/ / .github /
└── .mcp.json                 # Shared MCP tool definitions
```

## What git tracks

Git tracks the harness, the live ledger, dated plans, and gold labels.
Git ignores machine secrets and scratch files.

| Tracked | Gitignored |
|---|---|
| Agent instructions, skills, and rules | `_local/eval.env` (bucket, DB password) |
| `_plans/DECISIONS.md` and dated plans | `_scratch/`, `_worktrees/` |
| `_eval/GOLD.csv`, `GOLD.md`, `BACKLOG.md`, cycle files | `.claude/settings.local.json` |
| Environment template (`eval.env.example`) | |

Do not copy `DECISIONS.example.md` or `GOLD.example.csv` onto the live
paths. Those files are format only.

Copy `_local/eval.env.example` to `_local/eval.env` on each machine.
Do not commit `eval.env`.

## Quickstart

Humans start at [ONBOARDING.md](ONBOARDING.md). Agents follow
[CLAUDE.md](CLAUDE.md).

```bash
cp _local/eval.env.example _local/eval.env
```

Fill the bucket, region, and database fields before `/mount-s3-db`.
Label at least 20 gold rows before `/eval-loop`.

### Commands

| Command                  | Action                                                    |
| ------------------------ | --------------------------------------------------------- |
| `/create-plan <desc>`    | Draft a spec with steps and pseudocode.                   |
| `/implement-plan [file]` | Execute a spec. Check off tasks. Record new dead ends.    |
| `/mount-s3-db`           | Restore a production dump into a local sidecar container. |
| `/eval-loop`             | Run one observe → hypothesize → test → keep/kill cycle.   |
| `/commit`                | Stage and commit this repo. Agents never run `git push`.  |

## Tooling

This design keeps bash small. Most rules live in markdown and skills.

| Path | Role |
|------|------|
| `.claude/skills/mount-s3-db/` | Docker Postgres sidecar: fetch the S3 dump, create `eval_ro`, tear down. Keep the Cursor mirror in `.cursor/skills/` identical. |

Use `git worktree` for parallel agent experiments. Do not change files
in the main checkout.

Use `psql` with the sidecar `DATABASE_URL` to export gold candidates.

## MCP servers

Shared configuration in `.mcp.json`, `.cursor/mcp.json`, and
`.vscode/mcp.json`:

| Server                                                    | Purpose                                  |
| --------------------------------------------------------- | ---------------------------------------- |
| [Context7](https://github.com/upstash/context7)           | Library and framework docs               |
| [Playwright](https://github.com/microsoft/playwright-mcp) | Browser automation and end-to-end checks |
| Postgres sidecar                                          | Read-only database from `/mount-s3-db`   |

The Postgres MCP server fails on a fresh workspace until you run
`/mount-s3-db`. That error is expected. Agents must ignore it unless
the user asked for `/eval-loop`, `/mount-s3-db`, or sidecar SQL.
Do not edit `.mcp.json` to hide it.

## Further reading

| Topic            | Where                                 |
| ---------------- | ------------------------------------- |
| Human day-1      | [ONBOARDING.md](ONBOARDING.md)        |
| Eval protocol    | [\_eval/README.md](_eval/README.md)   |
| Plan format      | [\_plans/README.md](_plans/README.md) |
| Machine defaults | [\_local/README.md](_local/README.md) |

## Upstream

The layout started from
[raffertyuy/repo-of-repos](https://github.com/raffertyuy/repo-of-repos).
This tree does not clone inner remotes. It is a single-repo eval harness.

## License

MIT
