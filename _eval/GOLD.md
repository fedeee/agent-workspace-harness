---
labels_status: empty
date: 2026-09-01
dump_uri:
slice_ids: []
working_file: GOLD.csv
---

# Gold sample

The working file is `_eval/GOLD.csv`. This file has no labelled rows yet.
Do not run `/eval-loop` until it has at least **20** labelled rows
(`in_class` or `out_class`). `unsure` does not count. You also need at
least one labelled qualified row and one labelled excluded row.

Copy the protocol shape from `_eval/GOLD.example.md`.
Do not copy the fake rows from `_eval/GOLD.example.csv`.

## How to label

1. Open `_eval/GOLD.csv` in Numbers, Excel, or Sheets.
2. Open `url` (or the row id). Decide against the class definition.
3. Set `gold` to `in_class`, `out_class`, or `unsure`.
4. Fill `why` only when you change `gold`, or when you keep `unsure`.
5. Save as CSV (UTF-8).

`gold` ∈ `in_class` | `out_class` | `unsure`

## Class definition

Replace this row when you freeze a dump.

| slice_id | Class |
|----------|-------|
| | |

## Qualified-row predicate

Write one dump check here. Recompute it each cycle.

```
(replace this)
```

## Metrics

These are classification error rates. They are not data leakage.

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | out_class on qualified / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | in_class on excluded / labelled_excluded |

`labelled_*` ignores `unsure`. Recalculate from `GOLD.csv`.
