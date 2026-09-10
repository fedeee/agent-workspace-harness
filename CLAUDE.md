# CLAUDE.md

You are the orchestrator for this **agent harness**. This git tree holds
rules, living plans, domain memory, measurement loops, and product code.

The purpose is a harness that remembers what already failed. It is not
a clone manager for other remotes. Do not add a `repos/` layer.

## This Workspace

One git repository. Put product code in this tree, or copy these harness
files into an existing app repo:

```bash
bash scripts/adopt.sh /path/to/your-app
```

The CLI asks which agents the target repo uses: Cursor, Claude Code,
GitHub Copilot, or Codex. It then copies matching files.

### Git Push / SSH — Forbidden

**Never run `git push` and never use `ssh`.** The user pushes. Commits
stay local. Report them as ready to push.

A project hook blocks `git push`, `ssh`, and `git commit --no-verify`.
Cursor reads `.cursor/hooks.json`. Claude Code reads `.claude/settings.json`.
Codex reads `.codex/hooks.json`. All three run `.cursor/hooks/deny-shell.py`.
Codex requires project trust and hook review through `/hooks`.
Hooks guard common shell commands. They are not a complete security boundary.

### Worktrees

Use an isolated copy of this tree for experiments and parallel agent tasks:

```bash
scripts/worktree_agent.sh <branch>
scripts/worktree_agent.sh --clean <branch>
```

Do not pass a `repos/` name. This harness is one git repository.
Cleanup does not delete the branch. Scope the agent to the new path.

### Plan System

`_plans/` holds implementation plans.
`_eval/` holds the eval-loop ledger.

- `/create-plan` — create a plan with steps, context, and pseudocode
- `/implement-plan` — execute the plan, check off steps, run tests
- `/eval-loop` — one observe → hypothesize → test → keep/kill cycle
- `/mount-production-db` — restore a dump onto a throwaway sidecar Postgres

**`_plans/DECISIONS.md` is the ledger of product directions already
tried and invalidated.** Read it before you design. Cite the entry ID.
Append when product work rules an approach out.

This git tree is a shareable harness template. Do not record
harness-internal planning in `_plans/`, in `DECISIONS.md`, or in dated
plan files. Standing harness rules live in this file, in skills, and
in `.claude/prompt-snippets/`.

The template ships an empty ledger. Example entries live in
`_plans/DECISIONS.example.md`. Do not treat those IDs as this
workspace's ledger.

If `_plans/DECISIONS.md` is missing, read the example file for format
only.

Git ignores `_local/eval.env` only (sidecar secrets).

Score `_eval/GOLD.csv` when it exists. Do not score `GOLD.example.csv`.
Do not run classifier `/eval-loop` until that file has at least 20 labelled rows
(`in_class` or `out_class`). `unsure` does not count.

Pipeline evaluation needs frozen inputs and a declared metric, not classifier labels.
File evaluation needs no database or MCP.
See `_plans/README.md` and `_eval/README.md`.

### Postgres MCP — expected failure

The Postgres MCP server fails until `/mount-production-db` writes a pointer
file. Ignore that connection error. Do not retry it. Do not edit
`.mcp.json` to hide it.

Use Postgres MCP only when the user asked for `/eval-loop`,
`/mount-production-db`, or read-only SQL against the sidecar.

## Writing Style

@.claude/prompt-snippets/simplified-technical-english.md
[Simplified Technical English](./.claude/prompt-snippets/simplified-technical-english.md)

All docs, READMEs, task files, plans, commit messages, and responses use
**ASD-STE100 Simplified Technical English**.

## Coding Standards

@.claude/prompt-snippets/coding-standards.md
[Coding Standards](./.claude/prompt-snippets/coding-standards.md)

## Session execution

@.claude/prompt-snippets/session-execution.md
[Session execution](./.claude/prompt-snippets/session-execution.md)

## Commit Message Style

@.claude/prompt-snippets/commit-message.md
[Commit Message Guidelines](./.claude/prompt-snippets/commit-message.md)

## Prompt Snippets

`.claude/prompt-snippets/` is for `.md` instructions shared by at least
two agentic features. If an instruction is only used once, inline it.

## Agentic Configuration Sync

Keep Claude Code, Cursor, GitHub Copilot, and Codex in sync:

| What         | Claude Code              | Cursor                     | GitHub Copilot                    |
| ------------ | ------------------------ | -------------------------- | --------------------------------- |
| MCP servers  | `.mcp.json`              | `.cursor/mcp.json`         | `.vscode/mcp.json`                |
| Skills       | `.claude/skills/`        | `.cursor/skills/` (mirror) | —                                 |
| Agents       | `.claude/agents/`        | —                          | `.github/agents/`                 |
| Hooks        | `.claude/settings.json`  | `.cursor/hooks.json`       | —                                 |
| Instructions | `CLAUDE.md`              | `AGENTS.md`                | `.github/copilot-instructions.md` |

Codex uses `AGENTS.md`, `.agents/skills/`, `.codex/config.toml`, and `.codex/hooks.json`.
Use `$create-plan` and `$implement-plan` in Codex. The skill steps are shared.
Read linked prompt snippets explicitly; Claude `@` imports do not apply in Codex.

1. Any MCP server added to `.mcp.json` must also go in `.vscode/mcp.json`
   and `.cursor/mcp.json`. Keep `.codex/config.toml` server values in sync.
2. Edit a skill in `.claude/skills/` first, then copy it to
   `.cursor/skills/` and `.agents/skills/`. All three trees must match.
3. Shared standards must stay consistent across tools.
4. Shell deny hooks: keep `.cursor/hooks.json`, `.claude/settings.json`, and
   `.codex/hooks.json` pointed at the same script.

## Self-Improvement

When the user provides feedback that should persist, update the harness
(this file, skills, rules, MCP config) in the same session.
