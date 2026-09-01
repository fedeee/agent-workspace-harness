---
name: update-all-md-docs
description: Review and update all markdown docs in this harness
user-invocable: true
origin: template
---

Review and update all `.md` files in this harness to ensure they are
accurate and consistent with the current state of the project.

## Scope

- **Include**: All `*.md` files in the root and its subdirectories
  (`.claude/`, `.cursor/`, `.github/`, `_eval/`, `_plans/`, `_local/`)
- **Keep `.claude/skills/` and `.cursor/skills/` identical**

## Steps

1. **Discover** all in-scope `.md` files using glob patterns.

2. **Read each file** and check for:
   - Outdated references to files, directories, or features that no longer exist
   - Missing references to new files, directories, or features that have been added
   - Inconsistencies between documents (e.g., README.md describes a structure that doesn't match the actual file tree)
   - Stale MCP server lists, skill lists, agent lists, or config tables
   - Broken relative links
   - Product names that do not belong in the public harness
   - Any leftover `repos/` clone-manager language
   - Any leftover ceremony scripts (`check-onboard.sh`, `check-public-tree.sh`,
     `worktree_agent.sh`, `harvest_eval_candidates.py`,
     `bootstrap-overlay.sh`)

3. **Update each file** to reflect the current state:
   - Sync the file tree in README.md with the actual directory structure
   - Ensure MCP server tables match `.mcp.json`, `.vscode/mcp.json`, and
     `.cursor/mcp.json`
   - Ensure skill/agent/rule references are complete and accurate
   - Keep the existing tone and structure of each file — don't rewrite from scratch

4. **Report** a summary of what was changed and why.
