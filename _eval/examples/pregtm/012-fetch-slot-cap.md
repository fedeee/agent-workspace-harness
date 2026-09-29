---
cycle: 012
date: 2026-09-09
dump_uri: s3://pregtm-db-backups/db/latest/icp.dump
campaign_ids: [17, 13]
hypothesis_id: H17
verdict: keep
---

# Cycle 012 — fetch slot cap

Shipped in the same sitting as the crawl-error-cap plan. Not a dump write.

## Dump

- **URI**: `s3://pregtm-db-backups/db/latest/icp.dump`
- **Sidecar port**: 55444
- **MCP user**: eval_ro

## Baseline (from `leads`)

Cycle 011 on the same 60 campaign-17 `http_429` domains, five workers,
no fetch slot: 27 HTML, 32 `http_429`, 1 timeout.

Campaign 13 last run: 24 errors, 11 `http_403`. Four of those hosts are
now on `UNIVERSAL_SKIP_DOMAINS` (news + registries). Account-shaped 403s
stay unreachable (D6).

## Hypothesis

One in-flight website GET across enrich workers cuts live 429s on the
frozen 60-domain cohort.

## Predicted metric

First-GET `http_429` ≤ 10 / 60. HTML ≥ 27 / 60.

## Test method

local replay. `fetch_html` with default `FETCH_CONCURRENCY=1` and five
worker threads. Homepage GET only. No classifier. No dump write.

```
_scratch/eval-loop/h17-results.csv
```

## Result vs baseline

| Metric | Cycle 011 | This cycle | Delta |
|--------|-----------|------------|-------|
| first-GET HTML | 27 / 60 | 60 / 60 | +33 |
| first-GET 429 | 32 / 60 | 0 / 60 | -32 |
| precision leak | n/a | not scored | n/a |
| recall leak | n/a | not scored | n/a |

## Verdict

keep

The slot cap cleared the 429 spike on this cohort. `ENRICH_CONCURRENCY`
stays 5. No 2s retry (D77). No browser (D6).

## Follow-up

Remaining campaign-13 403s on banks, grid operators, and product brands
are bot walls. Do not skip them. Do not pick H16 unless asked.
