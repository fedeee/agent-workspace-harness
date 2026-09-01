---
name: mount-s3-db
description: >-
  Downloads a Postgres dump from S3, mounts it in a throwaway local
  Postgres (separate port + volume, never touches the live local DB), then
  runs read-only SQL against it. Use when the user gives an s3:// dump
  location, says mount S3 DB, sidecar DB, eval against a prod dump, or wants
  to query a remote dump without overwriting local data.
user-invocable: true
---

# Mount S3 DB (read-only sidecar)

Temporarily restore a `pg_dump` from S3 into a **sidecar** Postgres.
Run the user's eval / question. Tear down. Never touch the default local
volume or live local ports.

## Arguments

- `/mount-s3-db` — mount `latest`
- `/mount-s3-db latest`
- `/mount-s3-db 20260729T120000Z` — timestamp key under `db/<ts>/`
- `/mount-s3-db s3://YOUR_BACKUP_BUCKET/db/latest/app.dump`
- `/mount-s3-db latest — count labelled rows by slice`

If the user pastes an `s3://…` dump URI or asks to eval against a dump,
run this workflow even without the slash command.

## Hard rules

1. **Read-only** — never run commands that write to the mounted DB.
2. **Never** restore into the live local Postgres (ports in
   `EVAL_FORBIDDEN_PORTS`, default `5432` and `5433`).
3. **Never** rewrite a product `.env`. Pass `DATABASE_URL` only on the
   command line / shell env for this session.
4. **Never SSH** to a remote host — fetch dumps via S3 only.
5. **Always tear down** when the ask is done (or on failure after a
   successful mount).

### Allowed (DB read-only)

| Command | Notes |
|---------|--------|
| `psql "$DATABASE_URL" -c '…'` | SELECT / explain only |
| Product eval CLI | Writes CSV to disk, not the dump |
| Postgres MCP | Restricted mode, `eval_ro` only |

### Forbidden

- Product write jobs (`work`, `migrate`, `enrich`, app boot that mutates)
- `pg_restore` against the live local DB
- Any `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE`/`DROP` via psql

The mount script creates role `eval_ro` and exports that URL — prefer it.

### Postgres MCP

The `postgres` MCP server runs `.claude/skills/mount-s3-db/scripts/postgres-mcp.sh`.
That script reads `/tmp/eval-sidecar-mcp.env` (written by `mount.sh`).
It starts `crystaldba/postgres-mcp` in `--access-mode=restricted`.
It never uses ports `5432` or `5433`.

Do not export `EVAL_SIDECAR_URL` and expect MCP to pick it up.
The MCP config does not read a session env var.

After step 2:

1. Validate the pointer, safe port, Docker, and sidecar connection:

   ```bash
   bash .claude/skills/mount-s3-db/scripts/postgres-mcp.sh --check
   ```

2. Reconnect the `postgres` MCP server. You do not need to restart the IDE.
3. Use MCP SQL only against the mounted sidecar.
4. Teardown removes the pointer file when this session owns it.

The check emits structured diagnostics on stderr. It rejects missing or stale
pointers, non-`eval_ro` users, ports `5432` and `5433`, and unreachable sidecars.

The pointer file contains `EVAL_SIDECAR_URL` with host `host.docker.internal`
(Docker cannot reach the host as `localhost`). Host-side `psql` still uses
`DATABASE_URL` with `localhost`.

## Workflow

Copy and track:

```
Mount S3 DB progress:
- [ ] 1. Resolve S3 URI
- [ ] 2. Mount sidecar (script)
- [ ] 3. Run user eval / question with DATABASE_URL
- [ ] 4. Report results
- [ ] 5. Teardown sidecar
```

### 1. Resolve S3 URI

Defaults come from `_local/eval.env` (gitignored). Copy
`_local/eval.env.example` if that file is missing.

| Setting | Source |
|---------|--------|
| Bucket | `EVAL_BACKUP_BUCKET` |
| Region | `AWS_REGION` (default `eu-central-1`) |
| Profile | `AWS_PROFILE` |
| Object | `db/<key>/${EVAL_DB_NAME}.dump` where `<key>` is `latest` or a timestamp |

Accept full `s3://…` URIs as-is. Do not hardcode a bucket name in the skill.

### 2. Mount sidecar

From workspace root:

```bash
bash .claude/skills/mount-s3-db/scripts/mount.sh latest
# or:
bash .claude/skills/mount-s3-db/scripts/mount.sh s3://YOUR_BACKUP_BUCKET/db/latest/app.dump
```

Cursor mirror (identical):

```bash
bash .cursor/skills/mount-s3-db/scripts/mount.sh latest
```

The script:

1. Downloads the dump under `/tmp/eval-sidecar-<id>/`
2. Starts `docker compose` from the skill compose file with
   `COMPOSE_PROJECT_NAME=eval-sidecar-<id>` and a **free host port**
3. Restores with `pg_restore --no-owner --no-acl --clean --if-exists`
4. Creates `eval_ro` (SELECT-only)
5. Prints a `KEY=value` block including `DATABASE_URL`, `EVAL_SIDECAR_URL`,
   `SESSION_ID`, `STATE_FILE`
6. Writes `/tmp/eval-sidecar-mcp.env` so postgres MCP can reach the sidecar
7. Prints the MCP connection-test command

Source the printed env (or read `STATE_FILE`) for later steps. Do **not**
export into the user's permanent shell profile.

Needs: Docker, AWS CLI (`AWS_PROFILE` from `_local/eval.env`), network for S3.

### 3. Run the ask

```bash
DATABASE_URL="$DATABASE_URL" psql -v ON_ERROR_STOP=1 -c 'SELECT current_user;'
```

For free-form questions: write read-only SQL against the dump schema.
Prefer a product eval CLI when the user has one that writes CSV to disk.

If an eval CLI needs API keys, use the existing product `.env` — only
override `DATABASE_URL`.

### 4. Report

Summarize findings. Mention which dump URI / session was used. Do not dump
secrets from the DB.

### 5. Teardown

```bash
bash .claude/skills/mount-s3-db/scripts/teardown.sh "$SESSION_ID"
# or:
bash .claude/skills/mount-s3-db/scripts/teardown.sh /tmp/eval-sidecar-<id>/state.env
```

Removes compose project, volume, and `/tmp/eval-sidecar-<id>/`.

If the agent dies mid-flight, recover with:

```bash
docker ps -a --filter name=eval-sidecar-
ls /tmp/eval-sidecar-* 2>/dev/null
bash .claude/skills/mount-s3-db/scripts/teardown.sh <session_id>
```

## Examples

**Ad-hoc SQL**

```
/mount-s3-db s3://YOUR_BACKUP_BUCKET/db/latest/app.dump — count labelled rows by slice
```

**Latest dump, then eval-loop**

```
/mount-s3-db latest
/eval-loop observe
```
