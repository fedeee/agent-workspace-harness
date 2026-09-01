# Eval-loop hypothesis backlog — example

This file shows the backlog shape. Do not copy the fake hypotheses onto
the live file.

One change. One metric. The loop does not implement these until a cycle
picks one.

Write one open item per idea. One sentence. One predicted metric.
Use the next free id (`H1`, `H2`, …).

Status: `open` | `in-cycle` | `keep` | `kill`.

Test an item with `/eval-loop H1`. Example:

```
/eval-loop H1
```

Or run `/eval-loop` and let the agent pick one open item.

Kill on sight (do not add):

- Hardcoded keyword lists or regexes in engine source (D2)
- Extra user-visible budget dials (D1)
- Shipping a prompt change after a vibe check (D3)

## Open

None in this example. Add one sentence per hypothesis.

## Closed

### H1 — Keyword list in engine source

- **Status**: kill
- **Why**: Cycle 000 scored the frozen gold set. Precision error stayed
  0.50. The list overfit `catalogue` and still labelled
  `example-false.com` as qualified. See D2.

### H2 — Prompt block that requires wholesale evidence

- **Status**: keep
- **Why**: Example cycle. Precision error fell from 0.50 to 0.00.
  Recall error stayed 0.50 (`example-miss.com` is still excluded).
  Keep is valid: precision error dropped and recall error did not rise.
