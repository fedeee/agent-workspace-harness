# Agent Workspace Harness

A layered harness for AI coding agents: Negative ADRs, spec-first plan-then-implement with parallel execution in git worktrees, and offline empirical eval loops.

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
   gold set or database dump to evaluate models and debug pipeline issues.

<img src="docs/assets/harness-layers.svg" width="760" alt="The harness adds three durable layers to an agent chat session: plan then implement, negative ADRs, and offline eval." />

## Who's this for

The Agent Workspace Harness is built specifically for software engineers, data scientists, and technical founders who use AI coding agents (like Codex, Claude Code, or Cursor) to build, refactor, or maintain data-intensive systems, search pipelines, and classification logic.

It provides a lightweight, local operating system for working with AI coding agents. Rather than running a heavyweight external control plane, it relies on files in the repo to keep agents aligned, prevent repeated mistakes, and coordinate parallel execution.

*Comparison: Repo-native harness vs. enterprise agent infrastructure*

| | This harness | Enterprise agent infra |
|---|---|---|
| Control plane | The LLM, reading the plan | A scheduler/runtime |
| State | Markdown files in git | Databases, checkpoint stores |
| Failure handling | Agent reads the error, fixes the plan | Retry policies, dead-letter queues |
| Isolation | git worktrees + a deny hook | Containers, VMs, network policy |
| Trust model | Human reviews before push | System enforces without a human |
| Cost to run | A repo and an agent | A platform team |

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
The template ships it empty. Example entries live in
[`DECISIONS.example.md`](_plans/DECISIONS.example.md).

Memory is automatic. You do not tell the agent to memorize a failure.

- `/create-plan` reads the ledger before it designs.
- `/implement-plan` appends an entry when implementation kills an approach.
- `/eval-loop` appends an entry when a hypothesis is dead.

A new chat session reads that file first. It then skips those dead ends.

### 3. Offline eval

Test one hypothesis against a mounted dump or a frozen gold set.
Use the eval loop for classifier evaluation and pipeline debugging.
Do not implement the change until a cycle keeps it.

The eval loop handles two tasks:

- **Pipeline and platform debugging**: Diagnose crawl errors, rate limits (HTTP 429), timeouts, and system bottlenecks. Test a fix against dump error distributions with a target recovery metric.
- **Classifier evaluation**: Measure precision error and recall error on a frozen gold set in [`_eval/GOLD.csv`](_eval/GOLD.csv).

For database evaluation, the agent prepares a temporary copy, connects, evaluates, and cleans up.
MCP is optional. Frozen-file evaluation skips database setup.

Database setup:

1. Copy `_local/eval.env.example` to `_local/eval.env`. Fill the dump fields.
2. Run `/mount-production-db` to restore the dump into the local sidecar.
3. For classifier evaluations, write class rules in [`_eval/GOLD.md`](_eval/GOLD.md) and label at least **20** rows in [`_eval/GOLD.csv`](_eval/GOLD.csv).

For each idea:

```
/create-plan  →  _eval/BACKLOG.md  →  /eval-loop H1  →  /implement-plan
```

1. Run `/create-plan` with the change you want to measure.
2. Add one open item to [`_eval/BACKLOG.md`](_eval/BACKLOG.md). Write one sentence. Name one predicted metric. Use the next free id (`H1`, `H2`, …).
3. Run `/eval-loop H1`.
4. If the verdict is keep, run `/implement-plan`.

Keep rules:

- **Pipeline debugging**: Keep a change if it meets the predicted recovery metric without new errors.
- **Classifier evaluation**: Keep a change only if precision error drops and recall error does not rise.

Do not score `GOLD.example.csv`.
See [`_eval/README.md`](_eval/README.md) for metrics and other commands.

Use `scripts/eval_score.py` to validate labels and record reproducible classifier or pipeline results.
See [formats and commands](_eval/README.md#reproducible-classifier-scoring).
Each settled decision needs scope, evidence, and a condition for reconsideration.

## Workspace layout

```
.
├── CLAUDE.md                 # Primary system instructions for agents
├── AGENTS.md                 # Entry point (Codex / Cursor / Copilot)
├── _plans/                   # Specs + negative ADR ledger
├── _eval/                    # Eval protocol, cycles, gold schemas
├── _local/                   # Machine defaults (eval.env is gitignored)
├── install.sh                # One-line installer. Clones, then runs adopt
├── scripts/adopt.sh          # Copy this harness into an existing repo
├── scripts/worktree_agent.sh # Isolated git worktrees of this tree
├── .cursor/hooks.json        # Blocks git push, ssh, commit --no-verify
├── .agents/skills/           # Codex skills (mirror of .claude/skills/)
├── .codex/                   # Codex MCP config and shell hooks
├── .claude/ / .cursor/ / .github/
└── .mcp.json                 # Shared MCP tool definitions
```

## Adopt into an existing repo

Copy this harness into an app repository. Do not clone the app into this tree.

Codex, Cursor, Claude Code, and GitHub Copilot are supported.

One line, from inside your app repository:

```bash
curl -fsSL https://raw.githubusercontent.com/fedeee/agent-workspace-harness/main/install.sh | bash
```

This clones the harness into a temp directory and runs `scripts/adopt.sh`
against the current directory. You pipe a script to bash. Read it first
with `curl -fsSL <url>`.

Or clone this repo once and run the CLI yourself:

```bash
bash /path/to/coding_harness_repo/scripts/adopt.sh /path/to/your-app
```

The CLI needs Bash and Git. MCP and existing hook merges need `jq`.
Codex MCP merges also need Python 3.11 or newer.
Set `HARNESS_PYTHON=/path/to/python3.11` if `python3` is older.

The CLI detects Codex, Cursor, Claude Code, and GitHub Copilot files in the
target repo. It then asks:

1. Which agents to install for.
2. Whether to copy the eval loop.
3. Whether to copy the Postgres sidecar.
4. Whether to install MCP servers.
5. Whether to install the deny-push hook.

It copies matching skills and rules. It does not overwrite
`_plans/DECISIONS.md`. If `CLAUDE.md` or `AGENTS.md` already exist, it
appends a short harness section.

Non-interactive example (Cursor only, no eval, no hook):

```bash
bash /path/to/coding_harness_repo/scripts/adopt.sh /path/to/your-app \
  --yes --agents cursor --no-eval --no-sidecar --no-mcp --no-hooks
```

Do not copy this template `README.md` over the app README.

## Codex

Install the core negative memory harness:

```bash
bash scripts/adopt.sh /path/to/your-app --yes --agents codex
```

Add `--eval`, `--sidecar`, `--mcp`, and `--hooks` as needed.
Existing instructions, decisions, MCP server entries, and hook settings stay intact.
The shared source remains under `.claude/`; Codex does not need Claude Code installed.

Codex reads `AGENTS.md`. Skills live in `.agents/skills/`.
Use `$create-plan`, `$implement-plan`, `$eval-loop`, or `$commit` in Codex.
The slash commands below name the same skills in Cursor and Claude Code.
See the [official skill documentation](https://learn.chatgpt.com/docs/build-skills).

Codex uses `.codex/config.toml` for project MCP servers.
Trust the repository to load project config. Restart Codex after installation.
See the [official MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

With `--hooks`, Codex uses `.codex/hooks.json` for the shared shell guard.
Review and trust the hook through `/hooks` before it runs.
See the [official hook documentation](https://learn.chatgpt.com/docs/hooks).
Hooks guard common commands. They do not inspect every script or replace a sandbox.
Copilot follows the written prohibition; this harness does not install a Copilot shell hook.

## Checks

```bash
bash tests/test_adopt.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

Use Python 3.11+ for TOML merge tests. Tests use temporary repos and mock commands.
They do not fetch dumps or run the eval loop.

## Quickstart

Agents follow [CLAUDE.md](CLAUDE.md).

```bash
cp _local/eval.env.example _local/eval.env
```

Fill the bucket, region, and database fields before `/mount-production-db`.
Label at least 20 gold rows before classifier `/eval-loop`.

### Commands

| Command                  | Action                                                                                   |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| `/create-plan <desc>`    | Draft a spec with steps, `Depends on` edges, and pseudocode.                             |
| `/implement-plan [file]` | Execute a spec. Independent steps run as parallel worktree workers. Merge, test, review. |
| `/mount-production-db`   | Restore a production dump into a local sidecar container.                                |
| `/eval-loop`             | One observe → hypothesize → test → keep/kill cycle.                                      |
| `/eval-loop H1`          | Test hypothesis `H1` this cycle.                                                         |
| `/commit`                | Stage and commit this repo. Agents never run `git push`.  |
| `scripts/adopt.sh`       | Copy this harness into an existing git repository.        |

A hook also blocks `git push`, `ssh`, and `git commit --no-verify`.

Isolated worktrees:

```bash
scripts/worktree_agent.sh <branch>
scripts/worktree_agent.sh --clean <branch>
```

## Tooling

This design keeps bash small. A hook blocks forbidden git and ssh
commands. Most other rules live in markdown and skills.

| Path                                  | Role                                                                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `.cursor/hooks/deny-shell.py`         | Deny `git push`, `ssh`, and `git commit --no-verify`. Cursor, Claude Code, and Codex run this script.                              |
| `scripts/adopt.sh`                    | Copy this harness into an existing git repository. Asks which agents to install.        |
| `install.sh`                          | One-line installer. Clones this repo into a temp directory, then runs `scripts/adopt.sh`. |
| `scripts/worktree_agent.sh`           | Isolated git worktree of this tree. No `repos/` name. Copies `_local/eval.env` when it exists.                                  |
| `.claude/skills/mount-production-db/` | Docker Postgres sidecar: fetch the S3 dump, create `eval_ro`, tear down. Keep `.cursor/skills/` and `.agents/skills/` mirrors identical. |

## MCP servers

Shared configuration in `.mcp.json`, `.cursor/mcp.json`, and
`.vscode/mcp.json`, and `.codex/config.toml`:

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
