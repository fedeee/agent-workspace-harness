# PreGTM decisions ledger: excerpt

These entries are copied without change from the PreGTM `_plans/DECISIONS.md`.
Links to other PreGTM plans do not resolve in this repository.

## Crawler and fetch

### D77 — A 2s HTTP 429 retry does not recover the campaign-17 spike
- **Status**: settled 2026-09-09, **on measurement**
- **Was**: On website GET, wait `Retry-After` (cap 5s, default 2s) and
  retry once. Predicted: recover ≥ 20 of 60 campaign-17 dump `http_429`
  homepages.
- **Why**: Cycle 011 re-fetched those 60 domains with five workers
  (the live `ENRICH_CONCURRENCY` default). 27 returned HTML on the
  first GET. 32 returned 429. 1 timed out. The 32 retries waited 2s
  (no `Retry-After` header) and all 32 returned 429 again. Recovered
  = 0. LLM-client 429 retry is the wrong template for website WAFs
  that keep blocking the same IP during a burst.
- **Do not** add this retry to `fetch.py` as a yield fix.
- **Plan**: [campaign-error-eval](20260909-campaign-error-eval.plan.md)
  cycle 011 / H15.

### D78 — Cap in-flight website GETs; do not lower enrich workers
- **Status**: settled 2026-09-09
- **Was**: D8 dropped concurrency changes as a yield fix. Cycle 011
  then measured five enrich workers producing 32/60 live 429s on the
  campaign-17 dump cohort. A 2s retry recovered 0 (D77).
- **Now**: `FETCH_CONCURRENCY` default 1 gates `fetch_streamed` and
  `fetch_pdf_bytes`. `ENRICH_CONCURRENCY` stays 5 so classify can
  wait on the slot without a second UI meter (D2). Header and locale
  tuning stay out (D8).
- **Do not** add a browser for remaining 403s (D6).
- **Plan**: [crawl-error-cap](20260909-crawl-error-cap.plan.md)

## ICP, classifier and harvest

### D58 — A strict Tier B proof floor destroys recall
- **Status**: settled 2026-08-19
- **Was**: Add a second verifier after classification. Keep only accounts
  that prove every minimum Tier B requirement with exact page quotes.
- **Why**: Cycle 003 tested 50 frozen qualified rows across campaigns 6
  and 12. The verifier kept five rows. Combined precision leak fell from
  0.20 to 0.00, but recall leak rose from 0.04 to 0.39. Campaign 6 kept
  no rows. Many true accounts do not publish every required fact on their
  sites. A missing fact is not proof that the account fails the ICP.
  Narrow criterion tests remain valid. Do not use a strict all-criteria
  second pass or treat `unknown` as excluded.
- **Plan**: [eval-loop](20260818-eval-loop.plan.md) cycle 003 / H7.
