# Use case: PreGTM

| Original PreGTM record                                                        | What it shows                                                 |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [`003-qualification-floor.md`](pregtm/003-qualification-floor.md)             | Cycle 003: a kill verdict for a strict qualification verifier |
| [`011-429-retry.md`](pregtm/011-429-retry.md)                                 | Cycle 011: a kill verdict for a two-second HTTP 429 retry     |
| [`012-fetch-slot-cap.md`](pregtm/012-fetch-slot-cap.md)                       | Cycle 012: a keep verdict for a shared website request limit  |
| [`20260909-crawl-error-cap.plan.md`](pregtm/20260909-crawl-error-cap.plan.md) | The plan that cites D77 and implements the keep verdict       |
| [`DECISIONS-excerpt.md`](pregtm/DECISIONS-excerpt.md)                         | Ledger entries D58, D77, and D78                              |

## Kill: a stricter check discarded suitable companies

A second AI verifier required website quotes for every minimum qualification requirement.
It excluded companies when the evidence was missing.
The test used 50 previously accepted companies: labels identified 40 suitable companies and ten unsuitable ones.

| Companies retained | Before verification | After verification |
| ------------------ | ------------------: | -----------------: |
| Suitable           |                  40 |                  5 |
| Unsuitable         |                  10 |                  0 |

The verifier removed every unsuitable company, but also discarded 35 suitable companies.
Many company websites did not state every required fact. The team rejected the change and recorded decision D58.
**Lesson: missing evidence does not show that a company is unsuitable.**

Two days later, a different plan changed the same classifier. Its ledger table cites D58:

```markdown
| D58 | H12 does not treat a missing size rule as exclude. |
```

Read the [cycle 003 record](pregtm/003-qualification-floor.md) and [entry D58](pregtm/DECISIONS-excerpt.md#icp-classifier-and-harvest).

## Keep: limit website requests while other work stays parallel

This example shows the full loop in one day: kill, ledger entry, plan, keep.

1. **Kill.** 60 websites returned HTTP 429, or "too many requests", in campaign 17.
   Cycle 011 retried each blocked request after two seconds. The retry recovered 0 of 32.
2. **Record.** The agent wrote D77: "Do not add this retry to `fetch.py` as a yield fix."
3. **Plan.** The next plan read the ledger. It cites D77 and seven other entries. Three rows:

   ```markdown
   | D6 | No headless browser. Persistent 403 on an account site stays unreachable. |
   | D8 | Do not change `ENRICH_CONCURRENCY` or headers. Classify can stay parallel. |
   | D77 | Do not add a 2s 429 retry. |
   ```

4. **Keep.** The plan allowed one website request at a time. The five workers stayed for other work.
   Cycle 012 replayed the same 60 websites.

| First-request result | Cycle 011: no shared request limit | Cycle 012: one-request limit |
| -------------------- | ---------------------------------: | ---------------------------: |
| HTML returned        |                            27 / 60 |                      60 / 60 |
| HTTP 429             |                            32 / 60 |                       0 / 60 |
| Timeout              |                             1 / 60 |                       0 / 60 |

The agent recorded the result as D78.
These were separate live runs. External conditions could affect the result, so the comparison does not isolate the cause.
The experiment did not measure full pipeline speed or classification quality.

Read cycles [011](pregtm/011-429-retry.md) and [012](pregtm/012-fetch-slot-cap.md),
the [plan](pregtm/20260909-crawl-error-cap.plan.md), and [entries D77 and D78](pregtm/DECISIONS-excerpt.md#crawler-and-fetch).

[Return to the harness README](../../README.md#evaluate-one-hypothesis-at-a-time).
