# Decisions ledger

This is the live negative ADR ledger for this workspace.
Agents read it before they design.

If this file has no entries, do not treat
`_plans/DECISIONS.example.md` IDs as settled here.

## Decisions Index

| Subsystem           | Key Decision IDs | Core invalidation summary                                                                                                                                          |
| ------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Harness](#harness) | D1, D2, D3, D4   | Do not restore a `repos/` clone manager. Do not add ceremony scripts. Track the ledger and gold set in git. Name the mount skill after the job, not the transport. |

## How to read a status

| Status       | Meaning                                                             |
| ------------ | ------------------------------------------------------------------- |
| **settled**  | Decided against. Do not re-propose without new evidence.            |
| **reversed** | Was decided one way, then overturned. The current answer is stated. |
| **open**     | Named, not settled. Fair to raise — but read the entry first.       |

## How to add an entry

Append at the bottom of the relevant section with the next free ID. Never
renumber. Create the section if it does not exist.
