---
cycle: NNN
date: YYYY-MM-DD
dump_uri: s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
slice_ids: []
hypothesis_id: H?
verdict: keep | kill | need-labels | baseline
---

# Cycle NNN — <short slug>

## Workflow and evidence

- **Workflow**: classifier | pipeline
- **Input snapshot and SHA-256**:
- **Result report and SHA-256**:
- **Baseline and candidate code revisions**:
- **Model/runtime config and prompt hashes**:
- **Exact commands**:
- **Dirty patch or durable artifact location**:

## Dump (database workflows only)

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

Use the rows for the chosen workflow. Remove unrelated metric rows.

| Metric | Baseline | This cycle | Delta |
|--------|----------|------------|-------|
| precision error | | | |
| false omission rate (classifier) | | | |
| declared pipeline metric (pipeline) | | | |

## Verdict

keep | kill | need-labels

Why, in two sentences or fewer.

## Follow-up

Optional. Do not run it in this cycle.
