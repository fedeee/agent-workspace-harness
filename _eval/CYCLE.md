---
cycle: NNN
date: YYYY-MM-DD
dump_uri: s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
slice_ids: []
hypothesis_id: H?
verdict: keep | kill | need-labels | baseline
---

# Cycle NNN — <short slug>

## Dump

- **URI**:
- **Sidecar port**:
- **MCP user**: eval_ro

## Baseline

Paste a read-only query against your dump. Record the counts here.

| slice_id | n_rows | n_labelled | n_qualified | n_error | n_excluded |
|----------|--------|------------|-------------|---------|------------|
| | | | | | |

Write the qualified-row predicate in this file. Recompute it each cycle.

## Hypothesis

One sentence.

## Predicted metric

One number. Name the metric (precision error, recall error, or qualified yield).

## Test method

sql | eval CLI | local replay

Command or query:

```
```

## Result vs baseline

| Metric | Baseline | This cycle | Delta |
|--------|----------|------------|-------|
| precision error | | | |
| recall error | | | |

## Verdict

keep | kill | need-labels

Why, in two sentences or fewer.

## Follow-up

Optional. Do not run it in this cycle.
