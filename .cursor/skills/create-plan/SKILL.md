---
name: create-plan
description: Create an implementation plan in _plans/ with embedded code context and step-by-step task lists
user-invocable: true
origin: template
---

# Create Plan

Create a detailed implementation plan before any coding begins. The plan is a markdown file with checkboxes that `/implement-plan` will later execute and update.

## Arguments

The user provides a description of the work to be done. For example:
- `/create-plan Add Google OAuth to the login flow`
- `/create-plan Migrate user table to new schema`
- `/create-plan Update API rate limiting`

## Steps

### 1. Determine Scope

Based on the user's description, determine which paths are involved:

1. This harness is one git tree. Do not look for `repos/repos.yaml`.
2. Identify the files and directories that the work touches.
3. Ask the user to clarify scope only if it is genuinely ambiguous.

### 2. Generate the Filename

Format: `YYYYMMDD-<plan-name>.plan.md`

- Use today's date as the prefix (e.g., `20260409`)
- Create a short, descriptive plan name from the description:
  - Lowercase, hyphen-separated
  - 2-4 words maximum
  - Example: "Add Google OAuth to login" -> `20260409-google-oauth.plan.md`

### 3. Check the Decisions Ledger — before designing anything

Read `_plans/DECISIONS.md` when that file exists. It lists product
directions already proposed, evaluated and rejected, plus ones that
shipped and were reversed.

If `_plans/DECISIONS.md` is missing, read `_plans/DECISIONS.example.md`
for format only. Do not treat example IDs as this workspace's ledger.

Do not record harness-internal planning. Standing harness rules live
in `CLAUDE.md`, skills, and `.claude/prompt-snippets/`. The live
ledger is for the product in this git tree.

1. Scan the relevant subsystem rows in the Decisions Index.
2. Verify each specific entry before you design the change.

- If the work touches an entry, **say so in the plan** and cite the ID (`D16`).
  Either respect the decision, or state what new evidence overturns it. Never
  silently re-propose an invalidated direction — that is the failure this file
  exists to prevent.
- Entries marked **open** are fair game. Entries marked **drifted** must be
  verified against the code before you rely on them.
- If the plan settles something new, note it — Step 7 records it.

### 4. Gather Context

Read the code in this git tree. Do not invent API surfaces or types.

Follow `.claude/prompt-snippets/session-execution.md`.

1. Search first (grep, glob, definition or caller lookup). Identify:
   - API endpoints or routes relevant to the work
   - Type definitions, interfaces, or schemas involved
   - Key files that will need changes
   - Any existing tests for the affected code
2. Issue independent reads and searches in one turn. Read only the
   span you need.
3. Distill this into compact summaries — don't paste entire files

### 5. Write the Plan File

Create `_plans/YYYYMMDD-<plan-name>.plan.md` with this structure:

```markdown
---
status: draft
created: <today's date>
---

# Plan: <descriptive title>

## Context
<1-3 sentences: what needs to happen and why>

## Code context
- <key files with brief descriptions>
- <exported types or endpoints relevant to this work>
- <architectural constraints or patterns to follow>

## Steps

- [ ] Step 1: <brief title>
  - **Task**: <detailed explanation of what to do>
  - **Files**: <list of files to create or modify, with full paths>
  - **Depends on**: none
  - **Pseudocode**: <high-level pseudocode, NOT real code>

- [ ] Step 2: <brief title>
  - **Task**: <detailed explanation>
  - **Files**: <file list>
  - **Depends on**: Step 1
  - **Pseudocode**: <pseudocode>

(continue for all steps)

- [ ] Step N: Validate
  - **Task**: Run the application and tests, verify everything works
  - **Files**: <test files>
  - **Depends on**: all
```

`/implement-plan` reads `Depends on` and `Files` to group steps into
waves. Steps in one wave run as parallel workers, each in its own git
worktree. This is the default. There is no flag. To force serial order,
add a `Depends on` edge.

Rules for `Depends on`:

- `none` — the step needs no earlier step.
- `Step 1, Step 3` — the step needs those steps merged first.
- `all` — use on the Validate step.
- Two steps that list the same file are serial. Put the edge in anyway.
- A step that touches a serial file stands alone: a database migration,
  a lockfile or package manifest, `.env`, anything under `_plans/` or
  `_eval/`. Give every later step an edge to it.

### 6. Plan Quality Checklist

Before finishing, verify the plan:
- [ ] Steps are ordered by dependency (do X before Y if Y depends on X)
- [ ] Every step has a `Depends on` line (`none`, step list, or `all`)
- [ ] Steps with no edge between them list disjoint `Files`
- [ ] Steps that touch a serial file (migration, lockfile, `.env`,
      `_plans/`, `_eval/`) stand alone
- [ ] Independent context reads are listed as parallel tool calls
- [ ] Each step is small enough to implement and verify independently
- [ ] Pseudocode is used, not real code — implementation details are for `/implement-plan`
- [ ] Files listed actually exist (or are clearly marked as "new file")
- [ ] A validation step exists at the end
- [ ] Any user intervention points are called out
- [ ] `_plans/DECISIONS.md` was read, and any entry the plan touches is cited
- [ ] The plan is product work, not a harness-internal design debate

### 7. Record new decisions

If the plan rules an approach out — or reverses an existing entry — append it to
`_plans/DECISIONS.md` using the next free ID in the relevant section. One entry
per decision: the claim as a heading, then **Status**, **Why**, and a link back
to this plan. Never renumber existing entries.

Only record directions that product work considered and rejected. A list of
everything not built is noise; the ledger is for things someone would otherwise
propose again.

Do not append harness-internal planning, template design debates, or
standing harness rules. Those do not belong in `_plans/DECISIONS.md`.

### 8. Report

Tell the user:
- The plan file path
- A brief summary of the steps
- Which paths are in scope
- Suggested next step: "Run `/implement-plan _plans/<filename>` when ready to build."

## Notes

- Always read the code to gather real context — don't fabricate API surfaces or types
- If the tree has no product code yet, note that in the context section
- Keep it simple — avoid over-architecture. The plan should be the simplest path to done.
- Split work into steps that own disjoint files where the work allows it.
  That is what lets `/implement-plan` run them in parallel. Do not split
  a step only to make a wave bigger.
- Use pseudocode only, not real code
- Call out any points where user input or decisions are needed
- Dated plans live in this git tree. Git also tracks `EXAMPLE.plan.md`
  as format only. Dated plans are product work. Do not add a dated plan
  for a harness-internal design debate.
- Review the plan with the user before they run `/implement-plan`
