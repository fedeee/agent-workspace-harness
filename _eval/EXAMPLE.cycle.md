---
cycle: 000
date: 2026-08-31
dump_uri: s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
slice_ids: [1]
hypothesis_id: H2
verdict: keep
---

# Cycle 000 — example wholesale-evidence prompt

This file shows a filled cycle. It uses the fake gold rows in
`GOLD.example.csv`. Do not treat these numbers as a real dump.

## Dump

- **URI**: `s3://YOUR_BACKUP_BUCKET/db/latest/app.dump`
- **Sidecar port**: 55442
- **MCP user**: `eval_ro`

## Baseline

Qualified = `status = 'labelled'` and `fit IN ('strong', 'possible')`.

| slice_id | n_rows | n_labelled | n_qualified | n_error | n_excluded |
|----------|--------|------------|-------------|---------|------------|
| 1 | 4 | 4 | 2 | 0 | 2 |

## Hypothesis

A prompt block that requires wholesale evidence will drop precision error
on `example-false.com` without raising recall error.

## Predicted metric

Precision error 0.50 → 0.00. Recall error stays 0.50.

## Test method

sql + frozen gold CSV. No write to the dump.

Command or query:

```
Score GOLD.example.csv against the qualified-row predicate.
```

## Result vs baseline

| Metric | Baseline | This cycle | Delta |
|--------|----------|------------|-------|
| precision error | 0.50 | 0.00 | -0.50 |
| recall error | 0.50 | 0.50 | 0.00 |

`example-false.com` left the qualified set. `example-miss.com` stayed
excluded.

## Verdict

keep

Precision error dropped. Recall error did not rise. Apply the prompt
change in this git tree after the cycle. Record D2 if someone later
re-proposes a keyword list.

## Follow-up

Harvest more ambiguous rows before the next cycle. Do not do that in
this cycle.
