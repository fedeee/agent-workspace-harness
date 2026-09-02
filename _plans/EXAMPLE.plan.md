---
status: draft
created: 2026-08-31
---

# Plan: Example OAuth login (format only)

## Context

Show the plan file shape. This is not a live task. Copy the structure.
Replace the files and steps with the real work.

## Code context

- `src/components/LoginForm.tsx` — current login UI
- Exports: `LoginForm`, `useAuth`
- `POST /api/auth/login` -> `{ token, refreshToken }`
- Type: `AuthResponse { token: string, expires: number }`

## Decisions ledger

Cite live IDs from `_plans/DECISIONS.md` when that file exists. This
example cites the public format file only.

| ID | How this plan respects it |
|---|---|
| D1 (example) | No second budget dial. |
| D3 (example) | Validation uses a test, not a vibe check. |

## Steps

- [ ] Step 1: Backend OAuth endpoint
  - **Task**: Add a Google OAuth client and create POST /api/auth/google
  - **Files**: `src/routes/auth.ts` (example path)
  - **Depends on**: none
  - **Pseudocode**: Validate Google token, exchange for session, return AuthResponse

- [ ] Step 2: Frontend OAuth UI
  - **Task**: Add a Google sign-in button and wire the redirect flow
  - **Files**: `src/components/LoginForm.tsx` (example path)
  - **Depends on**: none
  - **Pseudocode**: Render Google button, handle OAuth callback, store token

- [ ] Step 3: Validate
  - **Task**: Run the application and tests. Confirm the full OAuth flow.
  - **Files**: `tests/auth.test.ts` (example path)
  - **Depends on**: all
