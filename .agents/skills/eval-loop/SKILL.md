---
name: eval-loop
description: Run one evaluation cycle on frozen files or a temporary database copy. Measure classifier quality or pipeline recovery, then record evidence and a keep or kill verdict.
user-invocable: true
---

# Eval loop

Run one cycle: observe, hypothesize, test, keep or kill, record.
Use `$eval-loop` in Codex or `/eval-loop` in other agents.
Accept an optional hypothesis ID, `observe`, or `continue`.

## Choose the workflow first

| Workflow | Input | Required guard | Keep rule |
|---|---|---|---|
| Classifier | Frozen GOLD.csv and two prediction CSVs | At least 20 labels; valid IDs; both prediction buckets per run | Precision error drops; false omission rate does not rise |
| Pipeline | Frozen dump slice or input file and measured results | Baseline, declared target, error count | Metric improves to target with zero new errors |

File evaluation needs no database, Docker, or MCP.
Pipeline evaluation needs no classifier labels or GOLD.csv.
Choose the workflow from the user's metric and available data. Ask only if this remains ambiguous.

## Database access, when needed

Treat preparation, access, evaluation, and cleanup as one user workflow.
Follow the mount-production-db skill to prepare a temporary database copy.
The user supplies the backup and the evaluation question. Handle the connection details.
Use Postgres MCP, psql, or the product evaluation command as appropriate. MCP is optional.

- Read the session's state.json with the state.py helper. Never source generated state files.
- Use DATABASE_URL for host commands. It identifies the read-only eval_ro role.
- Refuse live database ports, including 5432 and 5433.
- Confirm `SELECT current_user, current_database()` before queries. Require eval_ro.
- Never change the mounted database or run product migrations against it.
- If this workflow created the copy, tear it down after evaluation or failure.
- If the user supplied an existing session, leave its lifecycle to its owner.

## Cycle steps

1. Read `_plans/DECISIONS.md`. Verify applicable entries, scope, evidence, and reconsideration conditions.
   Cite live IDs. Examples show format only. State new evidence before a reversal.
2. Choose one hypothesis from `_eval/BACKLOG.md`. Create an empty backlog if absent.
   Do not copy example hypotheses. `observe` records a baseline without a hypothesis or keep verdict.
3. Freeze the input files. For classifiers, validate the live `_eval/GOLD.csv`:
   `python3 scripts/eval_score.py validate --gold _eval/GOLD.csv`.
   `unsure` rows do not count toward the minimum 20 labels.
4. Declare the predicted metric and target before the test. Keep one hypothesis per cycle.
5. Run baseline and candidate against the same input IDs and labels.
   For classifiers, export separate CSVs with `slice_id,id,bucket`.
   Bucket is `qualified` or `excluded`. Recompute it for each run; do not reuse gold-file buckets.
6. Save baseline and candidate model/runtime settings and code revisions in a JSON config.
   Record model IDs, prompt hashes, seed and sampling settings when applicable.
   Use explicit nulls for unavailable settings. Never put API keys or database passwords in reports.
7. Use `scripts/eval_score.py classifier` or `scripts/eval_score.py pipeline` to record the result.
   See `_eval/README.md` for commands and formats. The scorer records hashes, configuration, commands, and code state.
   Save files under `_scratch/eval-loop/`. Do not overwrite an earlier report.
8. Copy `_eval/CYCLE.md` to the next cycle file. Record workflow, evidence paths, hashes, and verdict.
   Commit a sanitized report with the cycle when durable evidence is needed.
   Pipeline metrics are measured externally; the recorder validates inputs and applies the declared rule.
   Review whether the measurement actually answers the hypothesis before you accept a keep verdict.
9. Update the backlog. If evidence rules out an approach, append a product decision with scope,
   evidence, and a reconsideration condition. Never create a settled entry from intuition alone.
10. Clean up a database copy this workflow created. Stop after one cycle unless the user requests another.

## Metric definitions

- Precision error = FP / (TP + FP), also called false discovery rate.
- False omission rate = FN / (TN + FN). Legacy docs call this `recall error`.
- This is not the conventional false negative rate FN / (TP + FN).
- Ignore unsure labels. Require both denominators in each classifier run.

Keep classifier changes only if precision error drops and false omission rate does not rise.
The scorer compares exact fractions before it formats numbers.
Twenty labels are a minimum execution guard, not proof of statistical confidence.
Report counts and slices. Grow the gold set between cycles; never change it during a cycle.
Do not test multiple hypotheses in parallel against the same small gold set.
