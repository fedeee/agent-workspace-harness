# Eval-loop ledger

Operator cycle files for offline evaluation and pipeline debugging. One file per cycle.

The loop measures frozen files or a temporary database copy. It does not write the database.
The operator applies a kept change in this git tree.

The loop supports two workflows:

1. **Pipeline and platform debugging**: Analyze error distributions (such as HTTP 429 rate limits, 403s, or timeouts) on a dump slice. Test a fix with a predicted recovery metric.
2. **Classifier evaluation**: Score precision error and recall error against a frozen gold set in `GOLD.csv`.

`_plans/` holds dated implementation plans. This folder holds the
eval ledger.

Do not copy `GOLD.example.csv` onto `GOLD.csv`. Do not score the
example rows.

Write your own read-only SQL against the dump. This folder does not
ship a schema.

## Layout

| Path | Git | Role |
|------|-----|------|
| `_eval/README.md` | tracked | This protocol |
| `_eval/CYCLE.md` | tracked | Empty cycle template |
| `_eval/EXAMPLE.cycle.md` | tracked | One filled cycle (fake data) |
| `_eval/GOLD.example.csv` | tracked | Gold-row shape with fake ids |
| `_eval/GOLD.example.md` | tracked | Gold protocol shape |
| `_eval/BACKLOG.example.md` | tracked | Hypothesis backlog shape |
| `_eval/NNN-<slug>.md` | tracked | Cycle verdict |
| `_eval/GOLD.md` | tracked | Class rules for this workspace |
| `_eval/GOLD.csv` | tracked | Frozen list + labels |
| `_eval/BACKLOG.md` | tracked | Hypotheses not yet tested |
| `_scratch/eval-loop/*.csv` | ignored | Raw eval output |

## Eval rules

Write the rules in `GOLD.md` before the first cycle.

1. **Target class.** One sentence. What does `in_class` mean here?
2. **Qualified-row predicate.** One dump check. What does the model
   treat as a hit? Recompute it from the fact table each cycle.
3. **Gold labels.** In `GOLD.csv`, set `gold` to `in_class`,
   `out_class`, or `unsure`.

There is no skill that writes these rules. You write `GOLD.md`.
`/eval-loop` then scores against them.

## Hypotheses

Write each idea in `BACKLOG.md`. One sentence. One predicted metric.
Give it the next free id (`H1`, `H2`, …). Set status to `open`.

The skill that tests a hypothesis is `/eval-loop`. Pass the id:

```
/eval-loop H1
```

That runs one cycle against `H1` in `BACKLOG.md`.

| Command | Action |
|---------|--------|
| `/eval-loop` | One cycle. Pick an open item, or write a new one. |
| `/eval-loop H1` | Test hypothesis `H1` this cycle. |
| `/eval-loop observe` | Refresh the baseline. Write no hypothesis. |
| `/eval-loop continue` | One more cycle after the last one. |

Do not implement the change until a cycle keeps it.

## How to run a cycle

Choose classifier or pipeline evaluation from the question.
Frozen files need no database, Docker, or MCP.
For a database question, prepare a temporary copy through `/mount-production-db`.
Use MCP, psql, or the product eval command. Clean up a copy this workflow created.

1. Read live decisions and choose one hypothesis.
2. Freeze the input and record the metric before the test.
3. Run baseline and candidate against the same input.
4. Record results with `scripts/eval_score.py`.
5. Copy CYCLE.md, link the report and its hashes, and update the backlog.
6. Stop after one cycle. Keep the database lifecycle within the user's evaluation request.

## Qualified row

Define one predicate on your dump. Write it in `GOLD.md` and in the
cycle file. Recompute from the fact table. Do not trust a cached
counts column.

## Gold metrics

These are classification error rates. They are not data leakage
(train/test contamination).

| Name in this repo | Standard term | Formula |
|---|---|---|
| Precision error (also: precision leak) | False discovery rate (1 - precision) | out_class on qualified / labelled_qualified |
| Recall error (also: recall leak) | False omission rate | in_class on excluded / labelled_excluded |

`in_class` means "in the target class". `out_class` means "not in the
target class". Keep these two gold values. Keep the two error rates.

- Qualified row + `out_class` = false positive.
- Excluded row + `in_class` = false negative (a miss).
- `labelled_*` ignores `unsure`.

Keep a change if precision error drops and recall error does not rise.
The legacy name `recall error` measures excluded rows; it does not mean `1 - recall`.

## Minimum gold set

For classifier evaluations, do not run `/eval-loop` until `_eval/GOLD.csv` has at least **20**
rows with `gold` set to `in_class` or `out_class`. `unsure` does not
count. You also need at least one labelled qualified row and one
labelled excluded row so both rates have a denominator.

A header-only `GOLD.csv` is not valid for `/eval-loop`. Do not score
`GOLD.example.csv`.

## Harvest the next labeling candidates

Mount the sidecar first. Read DATABASE_URL from state.json with state.py get. Refuse
ports 5432 and 5433. The user must be `eval_ro`.

Pass a query that prints CSV with the `GOLD.csv` headers:

```bash
psql "$DATABASE_URL" -c '\copy (YOUR_QUERY) to stdout csv header' \
  > _scratch/eval-loop/candidates.csv
```

Review candidates in a separate file. Do not append them during an active
eval cycle. After review, append a new cohort and update `_eval/GOLD.md`.

## Reproducible classifier scoring

The scorer uses only the Python standard library. It does not call a model or access a database.
Use the live GOLD.csv. Each row needs `slice_id,id,gold`; IDs must be unique within each slice.
At least 20 labels must be `in_class` or `out_class`. `unsure` does not count.
Export baseline and candidate predictions separately with `slice_id,id,bucket`.
Each file must contain exactly the gold IDs. Bucket is `qualified` or `excluded`.
The scorer recomputes counts from each prediction file. It ignores any old bucket in GOLD.csv.

Create a configuration file with settings for both runs:

```json
{
  "baseline": {"code_revision": "BASE_COMMIT", "model": "MODEL_ID", "prompt_sha256": "HASH", "seed": null},
  "candidate": {"code_revision": "CANDIDATE_COMMIT", "model": "MODEL_ID", "prompt_sha256": "HASH", "seed": null}
}
```

Use null for a deterministic classifier's model. Include runtime and sampling parameters when applicable.
Do not include credentials. Describe commands with secret environment-variable names, not their values.

```bash
python3 scripts/eval_score.py validate --gold _eval/GOLD.csv
python3 scripts/eval_score.py classifier --gold _eval/GOLD.csv \
  --baseline _scratch/eval-loop/baseline.csv --candidate _scratch/eval-loop/candidate.csv \
  --config _scratch/eval-loop/config.json \
  --command 'BASELINE_COMMAND; CANDIDATE_COMMAND' --out _scratch/eval-loop/result.json
```

Both runs need labelled qualified and excluded rows. Invalid inputs exit with status 2.
A valid report exits with status 0 for either keep or kill. Read the verdict in the report.
Comparison uses exact fractions. Displayed numbers are rounded floats.
Twenty labels are a minimum guard, not a statistical confidence claim.

## Pipeline results

Pipeline evaluation requires frozen inputs, a baseline, a declared target, and a new-error count.
It does not require classifier labels. Measure the results with the product's command or read-only SQL.
Save a measurements JSON file:

```json
{"metric": "recovered_rows", "baseline": 40, "candidate": 65, "target": 60, "direction": "higher", "new_errors": 0}
```

Use `lower` for metrics such as latency. A keep requires improvement, the target, and zero new errors.
The config file needs baseline and candidate code revisions and relevant runtime settings.

```bash
python3 scripts/eval_score.py pipeline --data _scratch/eval-loop/frozen-input.csv \
  --measurements _scratch/eval-loop/measurements.json --config _scratch/eval-loop/config.json \
  --command 'BASELINE_COMMAND; CANDIDATE_COMMAND' --out _scratch/eval-loop/pipeline-result.json
```

## Evidence in each report

Reports contain input and prediction SHA-256 hashes, baseline/candidate configuration, and the supplied exact commands.
They also contain the current Git revision, dirty diff hash, untracked file hashes, and scorer hash.
The recorder never executes the supplied commands. Record their real invocations after the evaluation.
For an uncommitted run, preserve its patch with the evidence. A hash alone cannot reconstruct missing code or data.
Keep input snapshots and sanitized reports with the cycle or in durable artifact storage.
Raw local files under `_scratch/` are ignored by Git; link durable copies before a settled decision.
Existing report files are never overwritten.
