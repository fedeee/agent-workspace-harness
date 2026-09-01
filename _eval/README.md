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
| `_eval/GOLD.example.csv` | tracked | Gold-row shape with fake ids |
| `_eval/GOLD.example.md` | tracked | Gold protocol shape |
| `_eval/BACKLOG.example.md` | tracked | Hypothesis backlog shape |
| `_eval/NNN-<slug>.md` | tracked | Cycle verdict |
| `_eval/GOLD.md` | tracked | Class rules for this workspace |
| `_eval/GOLD.csv` | tracked | Frozen list + labels |
| `_eval/BACKLOG.md` | tracked | Hypotheses not yet tested |
| `_scratch/eval-loop/*.csv` | ignored | Raw eval output |

## Eval rules

Write the rules in `GOLD.md` before the first cycle.

1. **Target class.** One sentence. What does `in_class` mean here?
2. **Qualified-row predicate.** One dump check. What does the model
   treat as a hit? Recompute it from the fact table each cycle.
3. **Gold labels.** In `GOLD.csv`, set `gold` to `in_class`,
   `out_class`, or `unsure`.

There is no skill that writes these rules. You write `GOLD.md`.
`/eval-loop` then scores against them.

## Hypotheses

Write each idea in `BACKLOG.md`. One sentence. One predicted metric.
Give it the next free id (`H1`, `H2`, …). Set status to `open`.

The skill that tests a hypothesis is `/eval-loop`. Pass the id:

```
/eval-loop H1
```

That runs one cycle against `H1` in `BACKLOG.md`.

| Command | Action |
|---------|--------|
| `/eval-loop` | One cycle. Pick an open item, or write a new one. |
| `/eval-loop H1` | Test hypothesis `H1` this cycle. |
| `/eval-loop observe` | Refresh the baseline. Write no hypothesis. |
| `/eval-loop continue` | One more cycle after the last one. |

Do not implement the change until a cycle keeps it.

## How to run a cycle

1. Confirm `/mount-production-db` is up. Postgres MCP user is `eval_ro`.
2. Tell the agent `/eval-loop H1` (or the id you want to test).
3. Read this folder's latest `NNN-*.md`, or `EXAMPLE.cycle.md` on the first run.
4. Follow `.claude/skills/eval-loop/SKILL.md` (Cursor mirror is identical).
5. Copy `CYCLE.md` to the next `NNN-<slug>.md` and fill it.
6. Stop after one cycle unless the user says continue.

## Qualified row

Define one predicate on your dump. Write it in `GOLD.md` and in the
cycle file. Recompute from the fact table. Do not trust a cached
counts column.

## Gold metrics

These are classification error rates. They are not data leakage
(train/test contamination).

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | out_class on qualified / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | in_class on excluded / labelled_excluded |

`in_class` means "in the target class". `out_class` means "not in the
target class". Keep these two gold values. Keep the two error rates.

- Qualified row + `out_class` = false positive.
- Excluded row + `in_class` = false negative (a miss).
- `labelled_*` ignores `unsure`.

Keep a change if precision error drops and recall error does not rise.

## Minimum gold set

Do not run `/eval-loop` until `_eval/GOLD.csv` has at least **20**
rows with `gold` set to `in_class` or `out_class`. `unsure` does not
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
