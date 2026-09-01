# Coding Standards

- Write clean, readable, and maintainable code
- Follow language-specific conventions and idioms
- Use meaningful variable and function names
- Keep functions small and focused on a single responsibility
- Add comments only where the logic isn't self-evident
- Follow established patterns
- Never use ssh directly to connect; let the user handle this
- Never git push automatically by yourself

## Imports

**Imports go at the top of the file.** A function-local import is a deliberate
exception. It needs an explanatory comment and, in Python, `# noqa: PLC0415`.

Valid reasons:

- Breaking a **real** import cycle (verify it; do not assume)
- An optional dependency that is not in the base install
- Deferring a genuinely expensive import off a hot startup path

Anything else is a reflex. Hoist it.

A top-level import fails at import time, in every test collection. A
function-local one fails on the first call.

Prefer a linter over a prompt. In Python, enable Ruff rules `E402`,
`PLC0415`, and `I` in this repo.

## Database Migrations

**Never edit a migration that has been applied anywhere.** Add a new one.

Tracking is by name, not by content. Editing an applied file changes
nothing on every database that already recorded it. Those databases stay
silently wrong.

- Make repair migrations idempotent
- Prefer additive changes
- Never renumber or reorder existing files
