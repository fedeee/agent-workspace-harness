# Plans

Plan files drive the plan-implement workflow. Each plan embeds context
and uses markdown task lists (`- [ ]`) to track progress.

## Workflow

1. **`/create-plan`** — create a plan with steps, context, and pseudocode
2. **`/implement-plan`** — execute the plan, check off steps, document fixes

## File Naming

Format: `YYYYMMDD-<plan-name>.plan.md`

- Date prefix is today's date (e.g., `20260409`)
- Plan name is 2-4 words, lowercase, hyphen-separated
- Examples: `20260409-google-oauth.plan.md`, `20260410-schema-migration.plan.md`

## Plan File Format

```markdown
---
status: draft | in-progress | completed
created: 2026-04-09
---

# Plan: Feature Name

## Context
What and why. Keep it brief.

## Code context
- `src/components/Auth.tsx` — current auth UI
- Exports: `LoginForm`, `useAuth` hook
- `POST /api/auth/login` -> `{ token, refreshToken }`
- Type: `AuthResponse { token: string, expires: number }`

## Steps

- [ ] Step 1: Backend OAuth endpoint
  - **Task**: Add Google OAuth client and create POST /api/auth/google
  - **Files**: `src/routes/auth.ts`, `src/config/oauth.ts`
  - **Pseudocode**: Validate Google token, exchange for session, return AuthResponse

- [ ] Step 2: Frontend OAuth UI
  - **Task**: Add Google sign-in button and wire redirect flow
  - **Files**: `src/components/LoginForm.tsx`
  - **Pseudocode**: Render Google button, handle OAuth callback, store token

- [ ] Step 3: Integration tests
  - **Task**: Add tests for the full OAuth flow
  - **Files**: `tests/auth.test.ts`
```

## Status Lifecycle

| Status | Meaning |
|--------|---------|
| `draft` | Plan created, not yet implemented |
| `in-progress` | `/implement-plan` is actively executing steps |
| `completed` | All steps done, tested, verified |

## How /implement-plan Updates the Plan

When `/implement-plan` runs against a plan:

1. Sets `status: in-progress`
2. Works through each unchecked step sequentially
3. Marks `- [ ]` to `- [x]` as each step completes
4. Adds `**Notes**` under steps if anything unexpected is discovered
5. Runs the app and tests after implementation
6. Documents any fixes as new checked-off steps
7. Sets `status: completed` when all steps pass

The plan becomes a living document — a record of what was planned AND what actually happened.

## DECISIONS.md — the ledger

`DECISIONS.md` sits alongside the plans and holds every direction that was
proposed, evaluated and **rejected** — plus the ones that shipped and were
reversed.

The live ledger is `_plans/DECISIONS.md`.
`_plans/DECISIONS.example.md` shows the format with fake product
entries. Do not copy the example file onto `DECISIONS.md`. Those IDs
are not this workspace's ledger.

- **Read it before designing.** `/create-plan` reads `_plans/DECISIONS.md`
  when that file exists. If it is missing, read the example file for
  format only. Cite the entry ID (`D16`) when a plan touches one.
- **Append when something is ruled out.** `/create-plan` records what the plan
  decides against; `/implement-plan` records what implementation disproved.
- **Never renumber.** A reversed entry keeps its ID, changes status to
  `reversed`, and states the current answer in the claim.

Plans are long and each one is read for its own work. The ledger is the one file
read *before* the work, which is why it exists separately.

Dated `*.plan.md` files live in this git tree. Git also tracks
`EXAMPLE.plan.md` as format only.

## Eval loop

The living eval ledger is **`_eval/`**, not this folder.

`_plans/` holds dated implementation plans and `DECISIONS.md`.
`_eval/` holds gold labels, cycle verdicts, and the hypothesis backlog.
See [_eval/README.md](../_eval/README.md).
Raw eval CSVs stay in `_scratch/eval-loop/` (gitignored).

## Why

1. **Session continuity** — fresh agents get full context from the plan, no re-explaining
2. **Trackable progress** — checkboxes show exactly where implementation stands
3. **Self-documenting** — the plan records decisions, discoveries, and fixes as they happen
4. **No repeated dead ends** — `DECISIONS.md` is what stops an invalidated direction being proposed again
