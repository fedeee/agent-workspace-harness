---
name: review-change
description: Independently review a Git change for actionable defects, with evidence and file references. Works with or without an implementation plan.
user-invocable: true
origin: template
---

# Review Change

Review the change without modifying it. A plan is optional.
Follow `.claude/prompt-snippets/review-standards.md` for review criteria and report format.

## Select the scope

Read repository instructions, `git status --short`, and the relevant diff.
Honor the user's explicit scope. Resolve refs to commit IDs before review.

- No argument: review staged and unstaged changes against `HEAD`, plus relevant untracked files.
  Use `git diff HEAD` and `git ls-files --others --exclude-standard`.
  On an unborn branch, inspect staged and untracked files as additions.
  If the tree is clean, ask which branch, commit, or range to review. Do not assume `HEAD~1`.
- `base <ref>`: review the branch from `git merge-base <ref> HEAD` through `HEAD`.
  Report local edits separately; exclude them from this committed scope.
- `commit <sha>`: review that commit against its parent. A root commit contains only additions.
  Ask which parent to use for a merge commit unless the user specifies one.
- A plan path: read its requirements and original `Base` under `## Waves`.
  Review from that base through the current tree, including relevant untracked files.
  If the base is missing or invalid, ask for it. Do not infer it from the current `HEAD`.

Read the corresponding file versions for the selected scope, including callers and tests.
For committed scope, use Git objects or an isolated snapshot; local edits are not review evidence for that commit.
Do not stage, stash, reset, commit, or alter files to prepare the review.
Inspect relevant untracked source and tests; exclude unrelated files, generated output, and secrets.
If the working tree changes during review, disclose that limitation. Do not claim the newer changes were reviewed.

## Delegate the review

Start one fresh reviewer subagent when the current tool supports delegation.
Use the tool's reviewer capability when available, or a general subagent with the reviewer instructions.
Use a fresh context without the implementation transcript when the tool permits it.
Pass this bounded handoff:

- Repository path and resolved review scope, including base and target commit IDs.
- Requirements or the relevant plan sections; identify any missing acceptance criteria.
- Changed file list and access to the actual diff, file versions, callers, and tests.
- Repository instruction paths and `.claude/prompt-snippets/review-standards.md`.
- Available test commands and results, clearly marked as supplied evidence.
- Instruction to inspect independently, return findings, and make no edits or commits.

Do not supply the implementer's conclusions about correctness or proposed review findings.
The reviewer may verify supplied test evidence; it must not claim those tests as its own execution.
Wait for the reviewer result. Review-only requests do not authorize fixes.

If already assigned as the reviewer, perform the review directly. Do not delegate another reviewer.
If delegation is unavailable, perform the same checks and label the result `Self-review; no independent agent available`.
If review fails or access is incomplete, report the limitation instead of a successful review.

## Return the result

Return the reviewer's supported findings and limitations using the shared report format.
Check cited evidence before presenting a finding. Explain any finding you reject; do not silently discard it.
Do not write a report file unless the user requests one or the calling workflow requires one.
Leave remediation to the user or the implementation workflow.

## Examples

```text
$review-change
$review-change base main
$review-change commit <sha>
$review-change _plans/<plan>.plan.md
```

Use `/review-change` in Claude Code or Cursor.
In other tools, ask the agent to follow this file directly when skill discovery is unavailable.
