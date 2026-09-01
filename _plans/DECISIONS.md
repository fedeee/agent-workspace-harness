# Decisions ledger

This is the live negative ADR ledger for this workspace.
Agents read it before they design.

If this file has no entries, do not treat
`_plans/DECISIONS.example.md` IDs as settled here.

## Decisions Index

| Subsystem | Key Decision IDs | Core invalidation summary |
|---|---|---|
| [Harness](#harness) | D1, D2, D3 | Do not restore a `repos/` clone manager. Do not add ceremony scripts. Track the ledger and gold set in git. |

## How to read a status

| Status | Meaning |
|--------|---------|
| **settled** | Decided against. Do not re-propose without new evidence. |
| **reversed** | Was decided one way, then overturned. The current answer is stated. |
| **open** | Named, not settled. Fair to raise — but read the entry first. |

## How to add an entry

Append at the bottom of the relevant section with the next free ID. Never
renumber. Create the section if it does not exist.

---

## Harness

### D1 — Outer clone manager
- **Status**: settled
- **Was**: Inner remotes under `repos/` with `/add-repository`,
  `/pull-all-repos`, `/commit-all-repos`, `/pr-all-repos`, and an
  explorer/worker split.
- **Why**: This tree had no inner clones. The clone layer hid the eval
  sidecar and the dead-end ledger. Joiners had to invent remotes.
- **Do not** add `repos/`, `/add-repository`, `/pull-all-repos`,
  `/commit-all-repos`, `/pr-all-repos`, or explorer/worker repo scope.
  Put product code in this git tree. Use `git worktree` for isolated
  experiments.

### D2 — Ceremony scripts around the harness
- **Status**: settled
- **Was**: Root scripts for onboard checks, public-tree greps, worktree
  wrappers, and gold harvest.
- **Why**: Gitignore already hides the overlay. ONBOARDING.md is the
  checklist. `git worktree` and `psql` already exist. Extra scripts hid
  the two that matter: overlay bootstrap and the sidecar mount.
- **Do not** add `check-onboard.sh`, `check-public-tree.sh`,
  `worktree_agent.sh`, or `harvest_eval_candidates.py`. Sidecar
  scripts stay under `/mount-s3-db`. See D3 for overlay tracking.

### D3 — Gitignore the live ledger and gold set
- **Status**: settled
- **Was**: Gitignore `_plans/DECISIONS.md`, dated plans, `_eval/GOLD.csv`,
  cycle files, and create them with `scripts/bootstrap-overlay.sh`.
- **Why**: Those files hold no dump passwords in this harness. The
  ignore list forced a bootstrap script and an overlay share step.
  A clone already needs the empty live files.
- **Do not** gitignore the live ledger, gold labels, dated plans, or
  cycle files. Do not add `bootstrap-overlay.sh`. Copy
  `_local/eval.env.example` to `_local/eval.env` (gitignored). Keep
  the `/mount-s3-db` scripts.
