# Decisions ledger — example format

This file shows the **shape** of a negative ADR ledger. It is not this
workspace's live ledger.

The live ledger is `_plans/DECISIONS.md`. Agents read it before they
design. If it is missing, use this file only as a format guide. Do not
treat these example IDs as settled product decisions.

## Decisions Index

| Subsystem | Key Decision IDs | Core invalidation summary |
|---|---|---|
| [Budget](#budget) | D1 | Keep one user-visible meter. |
| [Classifier](#classifier) | D2 | Keep vertical words in settings, not in engine source. |
| [Eval](#eval) | D3 | Measure one hypothesis against a frozen gold set. |
| [Harness](#harness) | D4 | Do not wrap product remotes in a clone manager. |

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
- **Why**: The list overfit one campaign and leaked precision on the next.
- **Do not** put industry names, product categories, or brand lists in engine code.
  Those facts belong in campaign settings.

## Eval

### D3 — Ship a prompt change after a vibe check
- **Status**: settled (example)
- **Was**: Judge a classifier tweak by reading a few rows and deciding it "looks better."
- **Why**: One edge case improved while recall error rose on the frozen gold set.
- **Do not** keep a change unless precision error drops and recall error does not rise.

## Harness

### D4 — Clone manager around the product tree
- **Status**: settled (example)
- **Was**: Inner remotes under `repos/` plus `/add-repository`.
- **Why**: Joiners had to invent remotes. The clone layer hid the eval loop.
- **Do not** add a `repos/` clone manager to this harness. Put product
  code in this git tree.
