---
labels_status: example
date: 2026-08-31
dump_uri: s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
campaign_ids: [1]
working_file: GOLD.csv
---

# Gold sample — example protocol

This file shows the gold-protocol shape. Do not copy this example onto
`GOLD.md`. Do not copy the fake domains into `GOLD.csv`.

The working file is **`GOLD.csv`** in this folder. Edit that CSV.
Do not edit domain tables here.

Keep one rule:

- During a cycle, freeze `GOLD.csv`. Do not add or remove rows.
- Between cycles, export candidates with `psql` and the sidecar
  `DATABASE_URL`. Review them in a separate file.
  Append a labelled cohort only after that review. Then update this
  file with the new slice IDs, cohort size, label status, and metrics.

Do not run `/eval-loop` on this example file. A live gold set needs at
least 20 labelled rows (`true_icp` or `false_icp`). This example has
four fake rows for format only.

## How to label

1. Open `_eval/GOLD.csv` in Numbers, Excel, or Sheets.
2. Open `url`. Decide against the class definition (`icp`).
3. Set `gold` to `true_icp`, `false_icp`, or `unsure`.
4. Fill `why` only when you change `gold`, or when you keep `unsure`.
5. Save as CSV (UTF-8).

`gold` ∈ `true_icp` | `false_icp` | `unsure`

| You decide | Write this |
|------------|------------|
| Yes, in class | `true_icp` |
| No, not in class | `false_icp` |
| Cannot tell | `unsure` |

Ignore `db_fit` and `db_tier`. Those are the model's guess.

- Qualified row + `false_icp` = precision error (false positive).
- Excluded row + `true_icp` = recall error (false negative / miss).
- `unsure` does not enter the metric.

## Class definition (example)

| campaign_id | Class |
|-------------|-------|
| 1 | B2B distributors of industrial equipment |

## Metrics

These are classification error rates. They are not data leakage.

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | false_icp / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | true_icp / labelled_excluded |

`labelled_*` ignores `unsure`. Recalculate from `GOLD.csv`.

## Leak so far (example numbers)

| Campaign | labelled_qualified | false_icp on qualified | precision error | labelled_excluded | true_icp on excluded | recall error |
|----------|--------------------|------------------------|-----------------|-------------------|----------------------|--------------|
|----------|--------------------|------------------------|----------------|-------------------|----------------------|-------------|
| 1 | 2 | 1 | 0.50 | 2 | 1 | 0.50 |

Example precision error: `example-false.com`.
Example recall error: `example-miss.com`.
