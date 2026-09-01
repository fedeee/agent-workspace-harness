# Join this workspace

This file is the human path. Agents follow [CLAUDE.md](CLAUDE.md).
The owner publishes `main` to GitHub. Agents never `git push`.

This harness is one git repository. Put product code in this tree, or
copy the harness files into an existing app repo. Do not add a
`repos/` clone manager.

Git tracks the ledger, plans, and gold set. Git ignores `_local/eval.env`
(bucket and DB password). Copy the example file on each machine.

## What you can do alone

| Task |
|------|
| Read [README.md](README.md) and this file |
| Copy `_local/eval.env.example` to `_local/eval.env` |

## What you cannot do without a dump and labels

| Task | Why |
|------|-----|
| Mount a dump or run `/eval-loop` | Needs a filled `eval.env`, a dump URI, and at least 20 labelled gold rows. |

After the owner pushes `main`, clone this repo. Then do the first table.

## Tools

Install these before you open the workspace:

| Tool | Why |
|------|------|
| Git | Clone this repo |
| Cursor or Claude Code | Skills (`/eval-loop`, `/create-plan`, …) |
| Docker | Eval sidecar Postgres |
| Node.js (`npx`) | MCP servers in `.mcp.json` |
| AWS CLI | `/mount-s3-db` only. Skip until you mount a dump. |
| `psql` | Optional. Export gold candidates from the sidecar. |

You do not need a dump, a gold set, or AWS on day 1.

## 1. Create local secrets

From the workspace root:

```bash
cp _local/eval.env.example _local/eval.env
```

Fill the bucket, region, and database fields. Do not commit `eval.env`.

Do not copy `_plans/DECISIONS.example.md` onto `DECISIONS.md`.
Those example IDs are not this workspace's ledger.

Do not copy `_eval/GOLD.example.csv` onto `GOLD.csv`.
Do not score those fake rows.

## 2. Add product code

Put application source in this git tree. Or copy `_eval/`, `_plans/`,
skills, and `CLAUDE.md` into an existing app repo.

Do not wrap other remotes in a `repos/` folder.

## 3. Postgres MCP

The Postgres MCP server starts with the IDE. It reads a pointer file
that `/mount-s3-db` writes. Until you mount a dump, that server fails.

Treat that failure as expected. Agents must ignore it unless the task
is `/eval-loop`, `/mount-s3-db`, or sidecar SQL. Context7 and
Playwright do not need the sidecar. Do not change `.mcp.json` to
"fix" the error.

## You are onboarded when

Harness (required):

- [ ] You cloned this repo (or copied the harness files)
- [ ] `_local/eval.env` exists (copy of the example)
- [ ] You read [README.md](README.md) and this file
- [ ] You know the Postgres MCP error is expected until `/mount-s3-db`
- [ ] Agents ignore that error unless the task is `/eval-loop` or
      `/mount-s3-db`

Product (required before you ship code):

- [ ] Application source lives in this git tree (or you copied the
      harness into an existing app repo)

Eval (required before `/eval-loop`):

- [ ] `_local/eval.env` has a real bucket and DB name
- [ ] `_eval/GOLD.csv` has at least **20** labelled rows (`true_icp` or
      `false_icp`, not the example domains). `unsure` does not count.
- [ ] `GOLD.csv` has at least one labelled qualified row and one
      labelled excluded row
- [ ] You can run `/mount-s3-db`

## Then work

- `/create-plan` — write a plan with steps and pseudocode
- `/implement-plan` — execute it and record new dead ends
- `/eval-loop` — one keep/kill cycle on the mounted dump
- `/mount-s3-db` — restore a dump onto a throwaway sidecar Postgres

Agents never run `git push` and never open SSH. You push.
