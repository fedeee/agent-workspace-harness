---
labels_status: example
date: 2026-08-31
dump_uri: s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
slice_ids: [1]
working_file: GOLD.csv
---

# Gold sample — example protocol

This file shows the gold-protocol shape. Do not copy this example onto
`GOLD.md`. Do not copy the fake rows into `GOLD.csv`.

The working file is **`GOLD.csv`** in this folder. Edit that CSV.
Do not edit row tables here.

Keep one rule:

- During a cycle, freeze `GOLD.csv`. Do not add or remove rows.
- Between cycles, export candidates with `psql` and the sidecar
  `DATABASE_URL`. Review them in a separate file.
  Append a labelled cohort only after that review. Then update this
  file with the new slice IDs, cohort size, label status, and metrics.

Do not run `/eval-loop` on this example file. A live gold set needs at
least 20 labelled rows (`in_class` or `out_class`). This example has
four fake rows for format only.

## How to label

1. Open `_eval/GOLD.csv` in Numbers, Excel, or Sheets.
2. Open `url` (or the row id). Decide against the class definition.
3. Set `gold` to `in_class`, `out_class`, or `unsure`.
4. Fill `why` only when you change `gold`, or when you keep `unsure`.
5. Save as CSV (UTF-8).

`gold` ∈ `in_class` | `out_class` | `unsure`

| You decide | Write this |
|------------|------------|
| Yes, in class | `in_class` |
| No, not in class | `out_class` |
| Cannot tell | `unsure` |

Ignore `predicted`. That is the model's guess.

- Qualified row + `out_class` = precision error (false positive).
- Excluded row + `in_class` = recall error (false negative / miss).
- `unsure` does not enter the metric.

## Class definition (example)

| slice_id | Class |
|----------|-------|
| 1 | Industrial equipment distributors |

## Qualified-row predicate (example)

```
status = 'labelled' AND fit IN ('strong', 'possible')
```

Replace this with one check on your dump.

## Metrics

These are classification error rates. They are not data leakage.

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | out_class on qualified / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | in_class on excluded / labelled_excluded |

`labelled_*` ignores `unsure`. Recalculate from `GOLD.csv`.

## Error so far (example numbers)

| Slice | labelled_qualified | out_class on qualified | precision error | labelled_excluded | in_class on excluded | recall error |
|-------|--------------------|------------------------|-----------------|-------------------|----------------------|--------------|
| 1 | 2 | 1 | 0.50 | 2 | 1 | 0.50 |

Example precision error: `example-false.com`.
Example recall error: `example-miss.com`.
