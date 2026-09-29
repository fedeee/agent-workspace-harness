---
status: completed
repos: [pregtm]
created: 2026-09-09
related: 20260909-campaign-error-eval.plan.md, 20260730-run-efficiency.plan.md
---

# Plan: Crawl 429 cap and 403 skips

## Context

Campaign 17 run 15 had 60 `http_429` errors under five enrich workers.
Cycle 011 showed a 2s retry recovers 0 of those (D77). Campaign 13 run
16 had 24 errors, 11 of them `http_403`. A browser will not recover
403 (D6). This plan caps in-flight website GETs and skips hosts that
are never an account.

## Decisions ledger

| ID | How this plan respects it |
|---|---|
| D6 | No headless browser. Persistent 403 on an account site stays unreachable. |
| D7 | No timeout clamp. The fetch slot does not change the wall budget. |
| D8 | Do not change `ENRICH_CONCURRENCY` or headers. Classify can stay parallel. |
| D77 | Do not add a 2s 429 retry. |
| D18, D53 | No campaign account-name list. Skip only universal media and directories. |
| D2 | `FETCH_CONCURRENCY` is an internal ceiling. Not a UI meter. |
| D32 | No silent PATCH of campaign `skipDomains`. |

## Repo Context

### pregtm

- `pipeline/lead_pipeline/config.py` — `enrich_concurrency()` default 5.
- `pipeline/lead_pipeline/enrich/fetch.py` — `fetch_streamed` / `fetch_pdf_bytes`.
  No global slot. Five workers burst the same WAF.
- `pipeline/lead_pipeline/runner.py` — skip list runs before crawl.
  Unreachable HTML stays `status=error` (D1).
- `shared/blocklist.py` — `UNIVERSAL_SKIP_DOMAINS`. Media and directories
  belong here. A bank or a grid operator can be an account. Leave those out.
- `pipeline/tests/test_crawl_budget.py` — named HTTP reasons, wall budget.

## User intervention

None for the fetch slot. Next prod run uses it.
Campaign 13 403s on real account hosts stay errors until a new run.

## Steps

- [x] Step 1: Cap in-flight website GETs
  - **Task**: Add `fetch_concurrency()` default 1. Gate `fetch_streamed`
    and `fetch_pdf_bytes` on one process-wide semaphore. Keep enrich
    workers at 5 so classify can overlap waits.
  - **Files**: `repos/pregtm/pipeline/lead_pipeline/config.py`,
    `repos/pregtm/pipeline/lead_pipeline/enrich/fetch.py`
  - **Notes**: `reset_fetch_gate()` for tests. D78.

- [x] Step 2: Skip universal 403 hosts that are never accounts
  - **Task**: Add campaign-13 news and registry hosts that match the
    existing universal bar (media, company directories). Do not add
    banks, grid operators, or product brands.
  - **Files**: `repos/pregtm/shared/blocklist.py`,
    `repos/pregtm/pipeline/tests/test_blocklist.py`
  - **Notes**: `telegraaf.nl`, `destentor.nl`, `visura.pro`,
    `ufficiocamerale.it`.

- [x] Step 3: Tests
  - **Task**: Five parallel `fetch_html` calls with a mock transport.
    Max in-flight GETs is 1. Blocklist tests cover the new hosts.
  - **Files**: `repos/pregtm/pipeline/tests/test_crawl_budget.py`,
    `repos/pregtm/pipeline/tests/test_blocklist.py`
  - **Notes**: 45 passed.

- [x] Step 4: Replay the frozen 60 dump 429 domains
  - **Task**: Five worker threads, new fetch gate, homepage GET only.
    Keep bar: first-GET 429 count ≤ 10 of 60 (H17).
  - **Files**: `_scratch/eval-loop/h17-results.csv` (gitignored)
  - **Notes**: 60/60 HTML, 0 `http_429`.

- [x] Step 5: Record
  - **Task**: D78. Update H17. Do not start the next eval cycle.
  - **Files**: `_plans/DECISIONS.md`, `_eval/BACKLOG.md`,
    `_eval/012-fetch-slot-cap.md`

- [x] Step 6: Validate
  - **Task**: `uv run pytest pipeline/tests/test_crawl_budget.py pipeline/tests/test_blocklist.py`
  - **Files**: those test files
  - **Notes**: 45 passed.
