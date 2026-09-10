# Decisions ledger

This is the live negative ADR ledger for the product in this git tree.
Agents read it before they design.

The harness template ships this file empty. Append product decisions
here. Do not record harness-internal planning, template design
debates, or standing harness rules. Those live in `CLAUDE.md`,
skills, and `.claude/prompt-snippets/`.

If an ID has no body in this file, do not treat
`_plans/DECISIONS.example.md` as the live text for that ID.

## Decisions Index

No entries yet. After you append the first entry, add a row here.

## How to read a status

| Status       | Meaning                                                             |
| ------------ | ------------------------------------------------------------------- |
| **settled**  | Decided against. Do not re-propose without new evidence.            |
| **reversed** | Was decided one way, then overturned. The current answer is stated. |
| **open**     | Named, not settled. Fair to raise — but read the entry first.       |

## How to add an entry

Append at the bottom of the relevant section with the next free ID. Never
renumber. Create the section if it does not exist.

Record a direction the product work considered and rejected. A list of
everything not built is noise.

Each entry must include:

- **Status**: open, settled, or reversed.
- **Scope**: affected subsystem, versions, data, and conditions. Avoid universal claims from one test.
- **Was**: the approach tested or previously adopted.
- **Evidence**: a durable test, cycle, issue, or commit reference and the observed result.
- **Decision**: what the evidence rules out within that scope.
- **Reconsider when**: a specific change or new evidence that justifies another test.

Use **open** if evidence is missing. Do not invent results or links.
For a reversal, preserve prior evidence and add the date, new evidence, and current decision.
