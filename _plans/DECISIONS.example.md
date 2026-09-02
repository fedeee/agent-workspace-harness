# Decisions ledger — example format

This file shows the **shape** of a negative ADR ledger. It is not this
workspace's live ledger.

The live ledger is `_plans/DECISIONS.md`. The template ships that file
empty. Agents read it before they design. If it is missing, use this
file only as a format guide. Do not treat these example IDs as settled
product decisions. Do not copy this file onto `DECISIONS.md`.

## Decisions Index

| Subsystem | Key Decision IDs | Core invalidation summary |
|---|---|---|
| [Budget](#budget) | D1 | Keep one user-visible meter. |
| [Classifier](#classifier) | D2 | Keep vertical words in settings, not in engine source. |
| [Eval](#eval) | D3 | Measure one hypothesis against a frozen gold set. |
| [Search](#search) | D4 | Keep one read path for the same list. |

## How to read a status

| Status | Meaning |
|---|---|
| **settled** | Decided against. Do not re-propose without new evidence. |
| **reversed** | Was decided one way, then overturned. The current answer is stated. |
| **open** | Named, not settled. Fair to raise — but read the entry first. |

## How to add an entry

Append at the bottom of the relevant section with the next free ID. Never
renumber.

---

## Budget

### D1 — Extra budget dials
- **Status**: settled (example)
- **Was**: Credits, a row cap, and a per-round pot as three user-visible numbers.
- **Why**: The extra dials stranded capacity and taught the agent to add more knobs.
- **Do not** add a second user-visible budget number.

## Classifier

### D2 — Hardcoded keyword lists in engine source
- **Status**: settled (example)
- **Was**: A vertical word list (or regex) compiled into the classifier.
- **Why**: The list overfit one slice and leaked precision on the next.
- **Do not** put class names, category lists, or brand lists in engine code.
  Those facts belong in per-run settings.

## Eval

### D3 — Ship a prompt change after a vibe check
- **Status**: settled (example)
- **Was**: Judge a classifier tweak by reading a few rows and deciding it "looks better."
- **Why**: One edge case improved while recall error rose on the frozen gold set.
- **Do not** keep a change unless precision error drops and recall error does not rise.

## Search

### D4 — Second read model for the same list
- **Status**: settled (example)
- **Was**: Add a search index beside the primary store for one list page.
- **Why**: Two sources of truth. The list drifted. Joiners did not know
  which query was canonical.
- **Do not** add a second read path for the same list until a cycle
  keeps it.
