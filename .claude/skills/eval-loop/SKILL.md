---
name: eval-loop
description: >-
  Run one operator eval cycle on a mounted sidecar dump: observe, hypothesize
  one change, test, keep or kill, record. Use when the user says eval loop,
  /eval-loop, measure precision error, gold sample, cycle the dump, keep or kill
  a classifier hypothesis, or score a frozen gold set on the sidecar.
user-invocable: true
---

# Eval loop

Run **one** cycle: observe → hypothesize → test → keep or kill → record.

This is a workshop loop. It does not write the dump. The operator applies
a kept change in this git tree.

## Arguments

- `/eval-loop` — one cycle from the latest ledger file
- `/eval-loop continue` — one more cycle after the last one
- `/eval-loop H1` — test that backlog item this cycle
- `/eval-loop observe` — refresh baseline only; write no hypothesis

## Hard rules

1. **Read-only dump.** Never `INSERT` / `UPDATE` / `DELETE` / `TRUNCATE`
   / `DROP` on the sidecar. Never `pg_restore` onto it after mount.
2. **Never** run product write jobs (`work`, `migrate`, `enrich`, app boot
   that mutates state) against the dump.
3. **Never** use the live local DB. Host ports in `EVAL_FORBIDDEN_PORTS`
   (default **5432** and **5433**) are forbidden. The sidecar maps a high
   host port (example: 55442).
4. **One change per cycle.** One predicted metric. Stop after one cycle
   unless the user says continue.
5. **Reject** a hypothesis that puts a vertical word list, brand list, or
   industry regex into engine source (example D2). Cite the live ID if
   this workspace recorded the same rule.
6. **Do not** add a second user-visible budget meter (example D1).
7. **Do not** keep a change after a vibe check (example D3). Score the
   gold set.
8. **Do not** tear down the sidecar. `/mount-production-db` owns mount and teardown.
9. **Do not** run this loop on an empty or tiny gold set. `_eval/GOLD.csv`
   needs at least **20** rows with `gold` set to `in_class` or `out_class`.
   `unsure` does not count. You also need at least one labelled qualified
   row and one labelled excluded row. Do not score `GOLD.example.csv`.

### Allowed

| Action | Notes |
|--------|--------|
| Postgres MCP `execute_sql` | SELECT / explain only. User must be `eval_ro`. |
| `psql` with sidecar `DATABASE_URL` | Export candidate rows to CSV. Read-only. |
| Product eval CLI | Classifier A/B that writes CSV to disk, not the dump. |
| Local replay | Throwaway DB only. Never forbidden ports. Never the sidecar. |

### Forbidden

- Any write to the mounted dump
- Hardcoded class-name lists in engine source
- Silent writes to production settings

## Sidecar guard (run first)

Copy and track:

```
Eval loop progress:
- [ ] 1. Guard dump
- [ ] 2. Guard gold
- [ ] 3. Load latest cycle
- [ ] 4. Observe
- [ ] 5. Hypothesize (one change)
- [ ] 6. Test
- [ ] 7. Keep or kill
- [ ] 8. Record
```

### 1. Guard dump

1. Read `/tmp/eval-sidecar-mcp.env`. If it is missing, stop. Tell the user
   to run `/mount-production-db` first.
2. Parse the host port from `EVAL_SIDECAR_URL`. Refuse **5432** and **5433**.
   `inet_server_port()` inside Docker is always 5432. Do not use it as the
   host-port check.
3. MCP SQL:

   ```sql
   SELECT current_user, current_database();
   ```

   Require `current_user = 'eval_ro'`.
4. Host CLI: source the sidecar `STATE_FILE` (or `/tmp/eval-sidecar-mcp.env`
   plus `localhost` in place of `host.docker.internal`). Pass
   `DATABASE_URL` on the command only. Never rewrite a product `.env`.

### 2. Guard gold

1. Confirm `_eval/GOLD.csv` exists. Do not score `_eval/GOLD.example.csv`.
2. Count rows where `gold` is `in_class` or `out_class`. `unsure` does
   not count.
3. If that count is below **20**, stop. Tell the user to label at least
   20 rows before `/eval-loop`. A header-only `GOLD.csv` is not valid.
4. Confirm at least one labelled `bucket=qualified` row and one labelled
   `bucket=excluded` row. If either count is 0, stop. Both error rates
   need a denominator.

## Qualified row

Define one predicate on your dump. Write it in the cycle file.
Recompute from the fact table. Do not trust a cached counts column.

## Observe

Run read-only SQL against the sidecar. Paste the result into the cycle
file. There is no stock schema in this harness.

## Hypothesize

Pick **one** item from `_eval/BACKLOG.md`, or write a new one.
If the user passed `/eval-loop H1`, test that id.
If `BACKLOG.md` is missing, copy `_eval/BACKLOG.example.md`.

The hypothesis is one sentence. The predicted metric is one number.
A new item gets the next free id (`H1`, `H2`, …) and status `open`,
then `in-cycle`.

Kill on sight:

- Engine keyword lists
- Extra budget dials
- Vibe-check keep

## Test

| Kind | How | Where |
|------|-----|--------|
| SQL | Compare dump slices | Sidecar, read-only |
| Classifier | Product eval CLI or a local scorer | Sidecar URL; CSV under `_scratch/eval-loop/` |
| Replay | Local replay | Throwaway DB. Never the dump. |

Write raw CSVs under `_scratch/eval-loop/` (gitignored). Write the verdict
under `_eval/NNN-<slug>.md`.

Score the frozen gold list in `_eval/GOLD.csv`. Protocol is in `GOLD.md`.
Do not add or remove rows during a cycle. Do not score `GOLD.example.csv`.

To grow the gold set, wait until the cycle is recorded. Then run
read-only SQL with `psql` and `DATABASE_URL` from the sidecar state
file. Write CSV under `_scratch/eval-loop/`. Review that file. Append
only between cycles. Details: `_eval/README.md`.

Gold growth is the one place to run workers. Between cycles, spawn one
subagent per dump slice. Each writes its own CSV under
`_scratch/eval-loop/`. No worker writes `_eval/`. The operator reviews
the CSVs and appends.

Do not run hypotheses in parallel. Score three hypotheses on the same
20 rows, keep the best, and you keep noise. One row is 5 % of the
metric. Two hypotheses that pass alone can fail together. One hypothesis
per cycle stays until the gold set is large enough for a held-out split.

Metrics:

- Precision error (false positive rate on qualified rows) =
  `out_class` on qualified / `labelled_qualified`
- Recall error (false negative rate on excluded rows) =
  `in_class` on excluded / `labelled_excluded`

These are classification error rates. They are not data leakage.

Keep if precision error drops and recall error does not rise.

## Record

Copy `_eval/CYCLE.md` to `_eval/NNN-<slug>.md`.
Fill every field. Update `BACKLOG.md` status.

If the idea is dead, append `_plans/DECISIONS.md` with the next free ID.
Never renumber.

Stop. Do not start the next cycle unless the user says continue.
