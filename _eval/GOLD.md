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
(`true_icp` or `false_icp`). `unsure` does not count. You also need at
least one labelled qualified row and one labelled excluded row.

Copy the protocol shape from `_eval/GOLD.example.md`.
Do not copy the fake domains from `_eval/GOLD.example.csv`.

## How to label

1. Open `_eval/GOLD.csv` in Numbers, Excel, or Sheets.
2. Open `url`. Decide against the class definition in this file.
3. Set `gold` to `true_icp`, `false_icp`, or `unsure`.
4. Fill `why` only when you change `gold`, or when you keep `unsure`.
5. Save as CSV (UTF-8).

`gold` ∈ `true_icp` | `false_icp` | `unsure`

## Class definition

Replace this row when you freeze a dump.

| slice_id | Class |
|----------|-------|
| | |

## Metrics

These are classification error rates. They are not data leakage.

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False positive rate on qualified rows | false_icp / labelled_qualified |
| Recall error (also: recall leak) | False negative rate on excluded rows | true_icp / labelled_excluded |

`labelled_*` ignores `unsure`. Recalculate from `GOLD.csv`.
