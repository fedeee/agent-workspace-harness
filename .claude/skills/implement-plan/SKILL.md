---
name: implement-plan
description: Execute a plan from _plans/, implementing steps, checking off tasks, running tests, and documenting fixes
user-invocable: true
origin: template
---

# Implement Plan

Execute an implementation plan from `_plans/`, working through each step, updating the plan as you go, and running tests to verify.

This skill combines the "implement" and "run" phases into one — you build it, run it, test it, fix it, and the plan documents everything that happened.

Flow: load plan → analyze dependencies → run waves (parallel workers in
worktrees where steps are independent) → merge → test → auto review →
human. The orchestrator (you) is the scheduler. There is no engine. See
D5 in `_plans/DECISIONS.md`.

## Arguments

The user provides the plan file to implement. For example:
- `/implement-plan _plans/20260409-auth-ui.plan.md`
- `/implement-plan auth-ui` (shorthand — resolve to the matching `.plan.md` file in `_plans/`)
- `/implement-plan` (no argument — if only one plan has `status: draft` or `status: in-progress`, use that)

## Steps

### 1. Load the Plan

1. Read the plan file from `_plans/`
2. If the user gave a shorthand (no path or partial name), find the matching `.plan.md` file
3. If no argument and multiple draft/in-progress plans exist, ask the user which one
4. Parse the frontmatter and step list
5. Identify which steps are already checked (`- [x]`) and which are pending (`- [ ]`)

### 2. Read Local Instructions

1. Read `CLAUDE.md` at the workspace root
2. Read `AGENTS.md` if it exists
3. Follow coding standards in `.claude/prompt-snippets/coding-standards.md`
4. Follow session execution in `.claude/prompt-snippets/session-execution.md`

### 3. Set Status to In-Progress

Update the plan file's frontmatter:
```yaml
status: in-progress
```

Record the current `HEAD` commit. The auto review in step 7 diffs
against it.

### 4. Analyze Dependencies

This is the analyzer node. Run it before any code, every time, including
on resume. It reads the plan and writes a wave table. It does not spawn
anything.

1. List the unchecked steps.
2. For each step read `**Depends on**` and `**Files**`.
3. Add implied edges:
   - Two steps list the same file → the later step depends on the earlier.
   - A step has no `Depends on` line and no `Files` line → it depends on
     the step before it.
   - A step touches a serial file (migration, lockfile or package
     manifest, `.env`, `_plans/`, `_eval/`) → it stands alone. Every
     later step depends on it.
   - The Validate step depends on all other steps.
4. Wave 1 is every step with no open dependency. Wave k is every step
   whose dependencies are all in waves below k.
5. Mode is `workers` when the wave has two or more steps and this
   session can spawn subagents. Otherwise `inline`. If the session
   cannot spawn subagents (for example GitHub Copilot), every wave is
   `inline`.
6. Write the table into the plan under `## Waves`. Replace an existing
   table. Include the base commit.

   ```markdown
   ## Waves

   Base: <sha>

   | Wave | Steps | Mode |
   |---|---|---|
   | 1 | 1, 2 | workers |
   | 2 | 3 | inline |
   | 3 | 4 (Validate) | inline |
   ```

7. Report the table to the user in one line per wave. Do not wait for
   approval unless the user asked to review it. To force serial order
   the user edits `Depends on` in the plan. There is no flag.

### 5. Implement Each Wave

Run waves in order. Finish and merge wave k before wave k+1 starts. The
next wave's workers branch from the merged tree.

#### Inline wave (one step)

1. **Read the step** — understand the task, files, and pseudocode
2. **Implement it** — write the actual code
   - Follow the plan as guidance, not strict requirements
   - If the plan's approach won't work, adapt — but document why
   - Follow the coding standards
   - Search, then read a span. Do not dump whole files.
3. **Mark it done** — update the plan file: change `- [ ]` to `- [x]`
4. **Add notes if needed** — if you discovered something unexpected, adapted the approach, or made a decision not in the original plan, add a `**Notes**` line under the step:
   ```markdown
   - [x] Step 3: Add OAuth endpoint
     - **Task**: Create POST /api/auth/google
     - **Files**: `src/routes/auth.ts`
     - **Pseudocode**: Validate token, create session
     - **Notes**: Used existing session middleware instead of creating new one. Added rate limiting per security best practice.
   ```

#### Workers wave (two or more steps)

1. **Create one worktree per step**, all in one turn:
   `scripts/worktree_agent.sh plan/<plan-name>/step-<N>`.
   The script prints the worktree path.
2. **Spawn one subagent per step**, all in one turn. Give each worker:
   the worktree path, the full step text, the plan `Context` and
   `Code context` sections, the coding standards path, and the worker
   rules below. Do not give it the whole plan file.
3. **Wait for every worker in the wave.** You need all results to merge.
4. **Merge in step order** into the current branch of the main tree:
   `git merge --no-ff plan/<plan-name>/step-<N>`. Resolve a clear
   conflict. On an unclear conflict, stop and ask the user.
5. **Clean up**: `scripts/worktree_agent.sh --clean plan/<plan-name>/step-<N>`,
   then `git branch -d` the merged branch.
6. **Mark each step done** and copy the worker's notes into `**Notes**`.
7. A worker that reports failure is not a flake. Do not respawn it.
   Run that step inline in the main tree, or stop and report.

Worker rules. Put these in every worker prompt:

- Work only inside your worktree path. Do not touch the main tree.
- Edit only the files in your step's `Files` list, plus new files the
  step needs. If you need to edit a file another step owns, stop and report.
- Read your step's files and their direct dependencies. Search first,
  then read the span you need. Do not read the whole tree. Do not read
  files owned by other steps in this wave.
- Do not edit the plan file, `_plans/DECISIONS.md`, or anything under
  `_eval/`. The orchestrator writes those.
- Do not run database migrations. Do not write to a shared local DB.
  Do not start a service on a shared port.
- Run only the tests that cover your files.
- Commit on your branch with a clear message. Never push.
- Return: files changed, tests run and their result, notes for the plan,
  and any dead end that belongs in the ledger. The orchestrator decides
  what to record.

**IMPORTANT**: Update the plan file after EACH wave, not at the end. If the session is interrupted, the plan shows exactly where things stand.

### 6. Run and Test

After the last wave is merged:

1. **Run the application** — start it up, verify it launches without errors
2. **Run existing tests** — make sure nothing is broken
3. **Run new tests** — if the plan included test steps, verify they pass
4. **If using Playwright MCP** — for frontend work, use browser automation to verify UI changes

Run the full suite once, on the merged main tree. Worker tests cover one
slice each. Only the merged tree shows interactions between slices.

Start a full test suite or a long compile in the background. Do other
independent work while it runs. Do not sit idle on a job that will take
minutes.

### 7. Auto Review

After the suite is green, review the diff from the base commit recorded
in `## Waves`:

1. Run the review subagent your tool provides. In Cursor that is the
   Bugbot subagent. In Claude Code spawn a reviewer subagent with the
   diff and the plan. If no review subagent exists, read the diff
   yourself against the plan's steps.
2. Fix a finding the review substantiates. Add each fix as a checked
   step (see step 8). Drop a finding you can show is wrong, and say why
   in the report.
3. Re-run the tests the fix touches.

The human reviews after this. Commits stay local. Never push.

### 8. Fix Issues

If tests fail or the app has issues:

1. **Diagnose** — read errors, check logs, identify root cause
2. **Fix** — make the necessary changes
3. **Document in the plan** — add new checked steps at the end:
   ```markdown
   - [x] Fix: Corrected token validation logic
     - **Notes**: The OAuth token response format changed in v2. Updated parser to handle both formats.
   ```
4. **Re-run tests** — verify the fix works
5. Repeat the diagnose → fix → re-run cycle. Do not retry the same
   failing command as a flake retry. A red test is a logic failure.

Retry a tool call only for a flake (timeout, dead subagent, lock). Cap
that retry at two attempts. Then stop and report.

### 9. Record What Was Invalidated

Implementation is where most decisions actually get settled — the plan's
approach fails, a measurement kills an idea, or the operator reverses a call.
Those are exactly what gets re-proposed months later.

Append to `_plans/DECISIONS.md` when that file exists and implementation:

- **proved an approach wrong** — the plan's pseudocode didn't work and you found
  out why (e.g. a timeout mechanism that cannot bound the failure it targets)
- **killed an option on measurement** — a probe or live run settled a question
  the plan had left open
- **was reversed** — the operator overturned a shipped decision, or the plan
  overturned an earlier plan's entry. Edit that entry's status to **reversed**
  and rewrite the claim to the current answer; keep the history in *Why*.

If `_plans/DECISIONS.md` is missing, create it from
`_plans/DECISIONS.example.md` first, then append. Commit the live
ledger with the rest of this git tree.

Use the next free ID in the relevant section. Never renumber. Skip the ordinary
stuff — a step you skipped for time is not a decision, it is a to-do.

### 10. Complete the Plan

When all steps pass and tests are green:

1. Update the plan file's frontmatter:
   ```yaml
   status: completed
   ```
2. Report to the user:
   - Summary of what was implemented
   - The wave table, and how many steps ran as workers
   - Auto review findings: fixed, or dropped with the reason
   - Any deviations from the original plan (with reasons)
   - Any fixes that were needed
   - Any decisions ledger entries added or reversed
   - Test results
   - Suggested next step (e.g., "Ready for code review" or "Run `/commit` to commit")

## Error Handling

- **Plan file not found**: List available plans in `_plans/` and ask the user to pick one
- **All steps already checked**: Tell the user the plan is already implemented. Ask if they want to re-run validation.
- **Blocked on user decision**: If a step says user intervention is needed, stop and ask. Add the decision to the plan once resolved.
- **Merge conflict between workers**: Two steps in one wave touched the same file. Resolve if clear. Otherwise stop, ask, and add a `Depends on` edge between those steps so the next run keeps them serial.
- **Worktree already exists**: A previous run was interrupted. Run `--clean` on that branch, then recreate it.
- **Implementation diverges significantly from plan**: Pause and inform the user. Let them decide whether to continue or revise the plan first.

## Notes

- Treat the plan as guidance, not gospel — adapt when reality doesn't match the plan
- The plan is a living document. Update it as you go, not after the fact.
- Parallel is the default, not a mode. The analyzer decides from the plan. A plan whose steps all chain gives one step per wave, and that is fine.
- The plan file, `_plans/DECISIONS.md`, and `_eval/` are single-writer. Only the orchestrator edits them.
- Every decision, deviation, and fix should be documented in the plan
- Decisions that rule an approach *out* also go in `_plans/DECISIONS.md` — the
  plan records what happened, the ledger is what gets read before the next plan
- When complete, the plan serves as a record of what happened — useful for code reviews and future reference
