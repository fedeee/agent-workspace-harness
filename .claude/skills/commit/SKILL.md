---
name: commit
description: Stage and commit changes in this git tree. Never push.
user-invocable: true
origin: template
---

# Commit

Stage and commit changes in this git tree.

**Never push. Never use ssh.** The user pushes manually — agents are not granted those rights.

## Scope

- Stage and commit files in this repository
- **Exclude** `_local/eval.env` and other secrets. Gitignore covers this.
- Do not restore a `repos/` clone manager. If leftover `repos/` files appear, do not commit them.

## Instructions

1. Run `git status` (never use `-uall`) and `git diff` to review changes
2. Run `git log --oneline -5` to match recent commit message style
3. Follow the commit message guidelines in `.claude/prompt-snippets/commit-message.md`
4. Stage files with explicit paths — never `git add -A`
5. Create the commit
6. Run `git status` to verify — do **not** push; tell the user the commit is ready to push

If there are no changes to commit, say so and stop.
