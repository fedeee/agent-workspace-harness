# Review Standards

Review independently against the stated requirements and the selected Git scope.
Read the changed code, relevant callers, and tests. Treat plans and test summaries as claims to verify.

## Boundaries

- Do not edit source, tests, plans, the ledger, or Git state. Do not commit or apply fixes.
- Use read-only tools or permissions when available. Instructions alone are not a security boundary.
- Run focused checks only when available tools and repository policy permit them.
  Avoid commands that modify the checkout or shared services. Use an isolated temporary copy when needed.
- Distinguish checks you ran from supplied results and static inspection.
- Do not run migrations, install dependencies, or access production services for a review.

## Findings

Prioritize defects introduced by the change: incorrect behavior, security flaws, data loss, and broken compatibility.
Trace relevant edge cases and error paths. Check that tests exercise the changed behavior.
Report a missing test as a finding only when you identify a concrete behavior at risk.
Skip style preferences, speculative risks, and unrelated pre-existing defects.
For instruction changes, trace a realistic request through the workflow and verify referenced resources exist.

Each finding needs:

- Priority: P0 (immediate critical failure), P1 (urgent), P2 (normal), or P3 (minor).
- A short title and a precise file reference with line numbers from the reviewed version.
- The triggering condition, observed or demonstrable failure, and user impact.
- Supporting code, a reproduction, or test evidence; state assumptions that affect the claim.
- A brief correction direction when clear. Do not implement it.

Do not invent findings to fill a quota. Separate unresolved questions from confirmed defects.

## Report

1. Scope: base and target commit IDs, plus any included local or untracked changes.
2. Review mode: independent agent or self-review. Disclose inherited implementation context if fresh context was unavailable.
3. Findings: most severe first, with evidence and file references.
4. Validation: checks performed, supplied evidence, and checks not run.
5. Limitations: missing requirements, unavailable dependencies, or changes outside the inspected scope.

If no actionable findings remain, say `No actionable findings in the reviewed scope`.
This does not prove the change is defect-free. A failed or incomplete review must remain explicit.
