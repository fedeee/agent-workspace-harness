# Eval-loop ledger

Operator cycle files for offline evaluation. One file per cycle.

The loop measures a mounted dump. It does not write the dump.
The operator applies a kept change in this git tree.

`_plans/` holds dated implementation plans. This folder holds the
eval ledger.

Do not copy `GOLD.example.csv` onto `GOLD.csv`. Do not score the
example rows.

Write your own read-only SQL against the dump. This folder does not
ship a schema.

## Layout

| Path | Git | Role |
|------|-----|------|
| `_eval/README.md` | tracked | This protocol |
| `_eval/CYCLE.md` | tracked | Empty cycle template |
| `_eval/EXAMPLE.cycle.md` | tracked | One filled cycle (fake data) |
| `_eval/GOLD.example.csv` | tracked | Gold-row shape with fake domains |
| `_eval/GOLD.example.md` | tracked | Gold protocol shape |
| `_eval/BACKLOG.example.md` | tracked | Hypothesis backlog shape |
| `_eval/NNN-<slug>.md` | tracked | Cycle verdict |
| `_eval/GOLD.md` | tracked | Gold protocol for this workspace |
| `_eval/GOLD.csv` | tracked | Frozen list + labels |
| `_eval/BACKLOG.md` | tracked | Hypotheses not yet tested |
| `_scratch/eval-loop/*.csv` | ignored | Raw eval output |

## How to run a cycle

1. Confirm `/mount-s3-db` is up. Postgres MCP user is `eval_ro`.
2. Read this folder's latest `NNN-*.md`, or `EXAMPLE.cycle.md` on the first run.
3. Follow `.claude/skills/eval-loop/SKILL.md` (Cursor mirror is identical).
4. Copy `CYCLE.md` to the next `NNN-<slug>.md` and fill it.
5. Stop after one cycle unless the user says continue.

## Qualified row

Define one predicate on your dump. Write it in the cycle file. Recompute
from the fact table. Do not trust a cached counts column.

## Gold metrics

These are classification error rates. They are not data leakage
(train/test contamination).

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | false_icp / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | true_icp / labelled_excluded |

`true_icp` means "in the target class". `false_icp` means "not in the
target class". Rename the labels if your domain uses other words. Keep
the two error rates.

- Qualified row + `false_icp` = false positive.
- Excluded row + `true_icp` = false negative (a miss).
- `labelled_*` ignores `unsure`.

Keep a change if precision error drops and recall error does not rise.

## Minimum gold set

Do not run `/eval-loop` until `_eval/GOLD.csv` has at least **20**
rows with `gold` set to `true_icp` or `false_icp`. `unsure` does not
count. You also need at least one labelled qualified row and one
labelled excluded row so both rates have a denominator.

A header-only `GOLD.csv` is not valid for `/eval-loop`. Do not score
`GOLD.example.csv`.

## Harvest the next labeling candidates

Mount the sidecar first. Source the session `state.env` (or the MCP
pointer plus `localhost` in place of `host.docker.internal`). Refuse
ports 5432 and 5433. The user must be `eval_ro`.

Pass a query that prints CSV with the `GOLD.csv` headers:

```bash
psql "$DATABASE_URL" -c '\copy (YOUR_QUERY) to stdout csv header' \
  > _scratch/eval-loop/candidates.csv
```

Review candidates in a separate file. Do not append them during an active
eval cycle. After review, append a new cohort and update `_eval/GOLD.md`.
