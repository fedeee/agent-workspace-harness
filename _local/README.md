# Machine defaults

This folder holds machine-local config. Git does not track `*.env`
files except the example.

Copy `eval.env.example` to `eval.env` on each machine:

```bash
cp _local/eval.env.example _local/eval.env
```

Do not commit `eval.env`.

## Eval sidecar

1. Copy `eval.env.example` to `eval.env`.
2. Set your backup bucket, region, and AWS profile.
3. Set `EVAL_DB_NAME`, `EVAL_DB_USER`, and `EVAL_DB_PASS` to match
   the dump you restore. The sidecar Postgres uses these values.
4. `/mount-production-db` reads `eval.env` before it builds an S3 URI.

| Variable | Role |
|----------|------|
| `EVAL_BACKUP_BUCKET` | S3 bucket that stores `pg_dump` files |
| `AWS_REGION` | Region for `aws s3 cp` |
| `AWS_PROFILE` | Named AWS CLI profile |
| `EVAL_DB_NAME` | Database name inside the dump and the sidecar |
| `EVAL_DB_USER` | Superuser created with the sidecar Postgres |
| `EVAL_DB_PASS` | Password for that superuser |
| `EVAL_FORBIDDEN_PORTS` | Host ports the sidecar must not bind |

Do not put secrets in the example file.

The read-only eval user is always `eval_ro`. The mount script creates
it after restore. Postgres MCP and `/eval-loop` refuse any other user.

See [_eval/README.md](../_eval/README.md).
