---
cycle: 003
date: 2026-08-19
dump_uri: s3://pregtm-db-backups/db/latest/icp.dump
campaign_ids: [6, 12]
hypothesis_id: H7
verdict: kill
---

# Cycle 003 — qualification floor

## Dump

- **URI**: `s3://pregtm-db-backups/db/latest/icp.dump`
- **Sidecar host port**: 55442
- **MCP user**: `eval_ro`
- **Database**: `icp`
- **Leads**: 4518

## Baseline (from `leads`)

Qualified = `status = 'enriched'` and `fit IN ('strong', 'possible')`.

The baseline matches cycles 000–002. The dump did not change.

| campaign_id | n_leads | n_enriched | n_qualified | n_tier_a | n_error | n_excluded | n_seeds | qualified_per_100_seeds |
|-------------|---------|------------|-------------|----------|---------|------------|---------|-------------------------|
| 6 | 650 | 152 | 145 | 41 | 81 | 417 | 1067 | 13.6 |
| 12 | 650 | 138 | 138 | 52 | 45 | 467 | 663 | 20.8 |

`checks`: 18 checks, 0 failing, 4 warnings. The result matches prior cycles.

Decay also matches prior cycles.

- Campaign 6 discovery: 5.7% → 8.9% Tier A.
- Campaign 6 harvest: 0 Tier A of 90.
- Campaign 12 discovery: 6.3% → 4.9% Tier A.
- Campaign 12 expansion: 12.6% → 7.1% Tier A.

## Hypothesis

A second verifier enforces the campaign's minimum Tier B definition before delivery.

## Predicted metric

Combined precision leak falls from 0.20 to 0.08 or less.

Recall leak must not rise above 0.04.

## Test method

The test used the 50 frozen qualified rows from campaigns 6 and 12.

The production crawler fetched each account. The verifier used current campaign settings.

The verifier returned `pass`, `fail`, or `unknown`. Each positive or negative check required an exact page quote.

Only `pass` stayed qualified. `fail` and `unknown` moved to excluded for scoring.

Command:

```
DATABASE_URL=postgresql://eval_ro:eval_ro@localhost:55442/icp \
H7_PROVIDER=moonshot \
uv run python _scratch/eval-loop/h7_qualification_floor.py
```

The first provider attempt used `anthropic/claude-sonnet-5`. Anthropic returned HTTP 403 before classification.

The completed run used `moonshot/kimi-k3`. Verifier cost was `$0.7474`.

Raw files:

- `_scratch/eval-loop/h7-qualification-floor.csv`
- `_scratch/eval-loop/h7-qualification-floor-crawls.jsonl`

The fixture confirmed:

- Exact quotes pass.
- Invented quotes fail closed.
- Malformed or inconsistent verdicts become `unknown`.

## Result vs baseline

| Scope | Precision baseline | Precision verifier | Recall baseline | Recall verifier |
|-------|--------------------|--------------------|-----------------|-----------------|
| campaign 6 | 0.20 (5/25) | no qualified rows (0/0) | 0.08 (2/25) | 0.44 (22/50) |
| campaign 12 | 0.20 (5/25) | 0.00 (0/5) | 0.00 (0/25) | 0.33 (15/45) |
| combined | 0.20 (10/50) | 0.00 (0/5) | 0.04 (2/50) | 0.39 (37/95) |

The verifier returned:

- 5 `pass`
- 4 `fail`
- 41 `unknown`

All five passed rows are `true_icp`. However, 35 other `true_icp` rows did not pass.

The verifier rejected three false positives:

- `shop-muenchner-solarmarkt.de`
- `solar-bouwmarkt.nl`
- `pedowitzgroup.com`

It also rejected one true account:

- `wamtechnik.pl`

Seven false positives became `unknown`. Most true accounts also became `unknown`.

Ten responses failed strict output validation:

- Five pass verdicts conflicted with unknown checks.
- Five responses used missing, short, or non-verbatim quotes.

## Verdict

kill

The verifier improved precision only by rejecting almost every account. Combined recall leak rose from 0.04 to 0.39.

The minimum floor requires evidence that many true account sites do not publish. Unknown evidence cannot act as an exclusion.

Do not add this strict second pass to production.

## Follow-up

Test one narrow campaign criterion next. Campaign 12 has three adjacent marketing-motion false positives and no recall leaks.

Use a single-pass prompt variant. Distinguish managed outbound work from adjacent inbound marketing services.
