# CLAUDE.md

You are the orchestrator for this **agent harness**. This git tree holds
rules, living plans, domain memory, measurement loops, and product code.

The purpose is a harness that remembers what already failed. It is not
a clone manager for other remotes. Do not add a `repos/` layer.

## This Workspace

One git repository. Put product code in this tree, or copy these harness
files into an existing app repo.

### Git Push / SSH — Forbidden

**Never run `git push` and never use `ssh`.** The user pushes. Commits
stay local. Report them as ready to push.

### Plan System

`_plans/` holds implementation plans.
`_eval/` holds the eval-loop ledger.

- `/create-plan` — create a plan with steps, context, and pseudocode
- `/implement-plan` — execute the plan, check off steps, run tests
- `/eval-loop` — one observe → hypothesize → test → keep/kill cycle
- `/mount-production-db` — restore a dump onto a throwaway sidecar Postgres

**`_plans/DECISIONS.md` is the ledger of directions already tried and
invalidated.** Read it before proposing an architecture change. Cite the
entry ID. Append when a plan or an implementation rules an approach out.

If `_plans/DECISIONS.md` is missing, read `_plans/DECISIONS.example.md`
for format only. Do not treat example IDs as this workspace's ledger.

The live ledger, dated plans, and gold labels live in this git tree.
The public vs local table is in [README.md](README.md).
Git ignores `_local/eval.env` only (sidecar secrets).

Score `_eval/GOLD.csv` when it exists. Do not score `GOLD.example.csv`.
Do not run `/eval-loop` until that file has at least 20 labelled rows
(`in_class` or `out_class`). `unsure` does not count.

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

## Commit Message Style

@.claude/prompt-snippets/commit-message.md
[Commit Message Guidelines](./.claude/prompt-snippets/commit-message.md)

## Prompt Snippets

`.claude/prompt-snippets/` is for `.md` instructions shared by at least
two agentic features. If an instruction is only used once, inline it.

## Agentic Configuration Sync

Keep Claude Code, Cursor, and GitHub Copilot in sync:

| What         | Claude Code       | Cursor                     | GitHub Copilot                    |
| ------------ | ----------------- | -------------------------- | --------------------------------- |
| MCP servers  | `.mcp.json`       | `.cursor/mcp.json`         | `.vscode/mcp.json`                |
| Skills       | `.claude/skills/` | `.cursor/skills/` (mirror) | —                                 |
| Agents       | `.claude/agents/` | —                          | `.github/agents/`                 |
| Instructions | `CLAUDE.md`       | `AGENTS.md`                | `.github/copilot-instructions.md` |

1. Any MCP server added to `.mcp.json` must also go in `.vscode/mcp.json`
   and `.cursor/mcp.json`.
2. Edit a skill in `.claude/skills/` first, then copy it to
   `.cursor/skills/`. The two trees must match.
3. Shared standards must stay consistent across tools.

## Self-Improvement

When the user provides feedback that should persist, update the harness
(this file, skills, rules, MCP config) in the same session.
