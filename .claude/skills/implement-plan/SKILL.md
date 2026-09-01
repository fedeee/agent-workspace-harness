---
name: implement-plan
description: Execute a plan from _plans/, implementing steps, checking off tasks, running tests, and documenting fixes
user-invocable: true
origin: template
---

# Implement Plan

Execute an implementation plan from `_plans/`, working through each step, updating the plan as you go, and running tests to verify.

This skill combines the "implement" and "run" phases into one — you build it, run it, test it, fix it, and the plan documents everything that happened.

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

### 3. Set Status to In-Progress

Update the plan file's frontmatter:
```yaml
status: in-progress
```

### 4. Implement Each Step

For each unchecked step (`- [ ]`), in order:

1. **Read the step** — understand the task, files, and pseudocode
2. **Implement it** — write the actual code
   - Follow the plan as guidance, not strict requirements
   - If the plan's approach won't work, adapt — but document why
   - Follow the coding standards
3. **Mark it done** — update the plan file: change `- [ ]` to `- [x]`
4. **Add notes if needed** — if you discovered something unexpected, adapted the approach, or made a decision not in the original plan, add a `**Notes**` line under the step:
   ```markdown
   - [x] Step 3: Add OAuth endpoint
     - **Task**: Create POST /api/auth/google
     - **Files**: `src/routes/auth.ts`
     - **Pseudocode**: Validate token, create session
     - **Notes**: Used existing session middleware instead of creating new one. Added rate limiting per security best practice.
   ```

**IMPORTANT**: Update the plan file after EACH step, not at the end. If the session is interrupted, the plan shows exactly where things stand.

### 5. Run and Test

After all implementation steps are complete:

1. **Run the application** — start it up, verify it launches without errors
2. **Run existing tests** — make sure nothing is broken
3. **Run new tests** — if the plan included test steps, verify they pass
4. **If using Playwright MCP** — for frontend work, use browser automation to verify UI changes

### 6. Fix Issues

If tests fail or the app has issues:

1. **Diagnose** — read errors, check logs, identify root cause
2. **Fix** — make the necessary changes
3. **Document in the plan** — add new checked steps at the end:
   ```markdown
   - [x] Fix: Corrected token validation logic
     - **Notes**: The OAuth token response format changed in v2. Updated parser to handle both formats.
   ```
4. **Re-run tests** — verify the fix works
5. Repeat until everything passes

### 7. Record What Was Invalidated

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

### 8. Complete the Plan

When all steps pass and tests are green:

1. Update the plan file's frontmatter:
   ```yaml
   status: completed
   ```
2. Report to the user:
   - Summary of what was implemented
   - Any deviations from the original plan (with reasons)
   - Any fixes that were needed
   - Any decisions ledger entries added or reversed
   - Test results
   - Suggested next step (e.g., "Ready for code review" or "Run `/commit` to commit")

## Error Handling

- **Plan file not found**: List available plans in `_plans/` and ask the user to pick one
- **All steps already checked**: Tell the user the plan is already implemented. Ask if they want to re-run validation.
- **Blocked on user decision**: If a step says user intervention is needed, stop and ask. Add the decision to the plan once resolved.
- **Implementation diverges significantly from plan**: Pause and inform the user. Let them decide whether to continue or revise the plan first.

## Notes

- Treat the plan as guidance, not gospel — adapt when reality doesn't match the plan
- The plan is a living document. Update it as you go, not after the fact.
- Every decision, deviation, and fix should be documented in the plan
- Decisions that rule an approach *out* also go in `_plans/DECISIONS.md` — the
  plan records what happened, the ledger is what gets read before the next plan
- When complete, the plan serves as a record of what happened — useful for code reviews and future reference
