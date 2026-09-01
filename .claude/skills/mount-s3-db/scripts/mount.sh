#!/usr/bin/env bash
# Mount a Postgres dump from S3 into a throwaway local sidecar.
# Never binds EVAL_FORBIDDEN_PORTS (default 5432,5433).
set -euo pipefail

RO_USER="eval_ro"
RO_PASS="eval_ro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

find_workspace_root() {
  local d="$SCRIPT_DIR"
  while [[ "$d" != "/" ]]; do
    if [[ -f "$d/_eval/README.md" && -d "$d/_local" ]]; then
      echo "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

WORKSPACE_ROOT="$(find_workspace_root)" || {
  echo "error: could not find workspace root containing _eval/ and _local/ (from $SCRIPT_DIR)" >&2
  exit 1
}

if [[ -f "$WORKSPACE_ROOT/_local/eval.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$WORKSPACE_ROOT/_local/eval.env"
  set +a
fi

BUCKET="${EVAL_BACKUP_BUCKET:-}"
REGION="${AWS_REGION:-eu-central-1}"
PROFILE="${AWS_PROFILE:-}"
DB_NAME="${EVAL_DB_NAME:-app}"
DB_USER="${EVAL_DB_USER:-app}"
DB_PASS="${EVAL_DB_PASS:-app}"
FORBIDDEN_PORTS="${EVAL_FORBIDDEN_PORTS:-5432,5433}"
MCP_ENV_FILE="${EVAL_MCP_ENV:-/tmp/eval-sidecar-mcp.env}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "error: missing $COMPOSE_FILE" >&2
  exit 1
fi

ARG="${1:-latest}"

if [[ "$ARG" != s3://* && -z "$BUCKET" ]]; then
  echo "error: set EVAL_BACKUP_BUCKET in _local/eval.env or pass a full s3:// URI" >&2
  echo "Copy _local/eval.env.example to _local/eval.env" >&2
  exit 1
fi

resolve_s3_uri() {
  local arg="$1"
  if [[ "$arg" == s3://* ]]; then
    echo "$arg"
    return
  fi
  echo "s3://${BUCKET}/db/${arg}/${DB_NAME}.dump"
}

is_forbidden_port() {
  local port="$1"
  local item
  IFS=',' read -ra items <<< "$FORBIDDEN_PORTS"
  for item in "${items[@]}"; do
    item="${item// /}"
    [[ "$item" == "$port" ]] && return 0
  done
  return 1
}

pick_free_port() {
  FORBIDDEN_PORTS="$FORBIDDEN_PORTS" python3 - <<'PY'
import os
import socket

forbidden = {
    int(p.strip())
    for p in os.environ["FORBIDDEN_PORTS"].split(",")
    if p.strip()
}
for port in range(55433, 55533):
    if port in forbidden:
        continue
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("127.0.0.1", port))
        print(port)
        break
    except OSError:
        pass
    finally:
        s.close()
else:
    raise SystemExit("no free port in 55433-55532")
PY
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require_cmd docker
require_cmd aws
require_cmd python3

S3_URI="$(resolve_s3_uri "$ARG")"
SESSION_ID="$(python3 -c 'import uuid; print(uuid.uuid4().hex[:12])')"
COMPOSE_PROJECT="eval-sidecar-${SESSION_ID}"
STATE_DIR="/tmp/eval-sidecar-${SESSION_ID}"
DUMP_PATH="${STATE_DIR}/${DB_NAME}.dump"
STATE_FILE="${STATE_DIR}/state.env"
DB_PORT="$(pick_free_port)"

if is_forbidden_port "$DB_PORT"; then
  echo "error: refused to bind forbidden port $DB_PORT" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

echo "[mount-s3-db] session=$SESSION_ID" >&2
echo "[mount-s3-db] downloading $S3_URI → $DUMP_PATH" >&2
if [[ -n "$PROFILE" ]]; then
  AWS_PROFILE="$PROFILE" aws s3 cp "$S3_URI" "$DUMP_PATH" --region "$REGION" >&2
else
  aws s3 cp "$S3_URI" "$DUMP_PATH" --region "$REGION" >&2
fi

echo "[mount-s3-db] starting sidecar Postgres on localhost:${DB_PORT} (project $COMPOSE_PROJECT)" >&2
COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
  DB_PORT="$DB_PORT" \
  EVAL_DB_USER="$DB_USER" \
  EVAL_DB_PASS="$DB_PASS" \
  EVAL_DB_NAME="$DB_NAME" \
  docker compose -f "$COMPOSE_FILE" up -d db >&2

echo "[mount-s3-db] waiting for healthy..." >&2
for _ in $(seq 1 60); do
  if COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
      DB_PORT="$DB_PORT" \
      EVAL_DB_USER="$DB_USER" \
      EVAL_DB_PASS="$DB_PASS" \
      EVAL_DB_NAME="$DB_NAME" \
      docker compose -f "$COMPOSE_FILE" exec -T db \
      pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
    DB_PORT="$DB_PORT" \
    EVAL_DB_USER="$DB_USER" \
    EVAL_DB_PASS="$DB_PASS" \
    EVAL_DB_NAME="$DB_NAME" \
    docker compose -f "$COMPOSE_FILE" exec -T db \
    pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
  echo "error: sidecar Postgres did not become ready" >&2
  COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
    DB_PORT="$DB_PORT" \
    EVAL_DB_USER="$DB_USER" \
    EVAL_DB_PASS="$DB_PASS" \
    EVAL_DB_NAME="$DB_NAME" \
    docker compose -f "$COMPOSE_FILE" down -v >&2 || true
  rm -rf "$STATE_DIR"
  exit 1
fi

echo "[mount-s3-db] restoring dump (clean into sidecar only)..." >&2
set +e
COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
  DB_PORT="$DB_PORT" \
  EVAL_DB_USER="$DB_USER" \
  EVAL_DB_PASS="$DB_PASS" \
  EVAL_DB_NAME="$DB_NAME" \
  docker compose -f "$COMPOSE_FILE" exec -T db \
  pg_restore --clean --if-exists --no-owner --no-acl \
  -U "$DB_USER" -d "$DB_NAME" < "$DUMP_PATH"
RESTORE_RC=$?
set -e
if [[ "$RESTORE_RC" -gt 1 ]]; then
  echo "error: pg_restore failed with exit $RESTORE_RC" >&2
  COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
    DB_PORT="$DB_PORT" \
    EVAL_DB_USER="$DB_USER" \
    EVAL_DB_PASS="$DB_PASS" \
    EVAL_DB_NAME="$DB_NAME" \
    docker compose -f "$COMPOSE_FILE" down -v >&2 || true
  rm -rf "$STATE_DIR"
  exit 1
fi

echo "[mount-s3-db] creating read-only role ${RO_USER}..." >&2
COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT" \
  DB_PORT="$DB_PORT" \
  EVAL_DB_USER="$DB_USER" \
  EVAL_DB_PASS="$DB_PASS" \
  EVAL_DB_NAME="$DB_NAME" \
  docker compose -f "$COMPOSE_FILE" exec -T db \
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL >/dev/null
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${RO_USER}') THEN
    CREATE ROLE ${RO_USER} LOGIN PASSWORD '${RO_PASS}';
  ELSE
    ALTER ROLE ${RO_USER} WITH LOGIN PASSWORD '${RO_PASS}';
  END IF;
END
\$\$;
GRANT CONNECT ON DATABASE ${DB_NAME} TO ${RO_USER};
GRANT USAGE ON SCHEMA public TO ${RO_USER};
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${RO_USER};
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO ${RO_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${RO_USER};
SQL

SUPERUSER_URL="postgresql://${DB_USER}:${DB_PASS}@localhost:${DB_PORT}/${DB_NAME}"
DATABASE_URL="postgresql://${RO_USER}:${RO_PASS}@localhost:${DB_PORT}/${DB_NAME}"
EVAL_SIDECAR_URL="postgresql://${RO_USER}:${RO_PASS}@host.docker.internal:${DB_PORT}/${DB_NAME}"

cat > "$MCP_ENV_FILE" <<EOF
SESSION_ID=${SESSION_ID}
EVAL_SIDECAR_URL=${EVAL_SIDECAR_URL}
EOF

cat > "$STATE_FILE" <<EOF
SESSION_ID=${SESSION_ID}
COMPOSE_PROJECT=${COMPOSE_PROJECT}
DB_PORT=${DB_PORT}
DATABASE_URL=${DATABASE_URL}
SUPERUSER_URL=${SUPERUSER_URL}
EVAL_SIDECAR_URL=${EVAL_SIDECAR_URL}
MCP_ENV_FILE=${MCP_ENV_FILE}
S3_URI=${S3_URI}
DUMP_PATH=${DUMP_PATH}
STATE_DIR=${STATE_DIR}
STATE_FILE=${STATE_FILE}
COMPOSE_FILE=${COMPOSE_FILE}
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[mount-s3-db] ready. Prefer DATABASE_URL (eval_ro). Teardown: bash $SCRIPT_DIR/teardown.sh ${SESSION_ID}" >&2
echo "[mount-s3-db] postgres MCP check: bash $SCRIPT_DIR/postgres-mcp.sh --check" >&2
echo "[mount-s3-db] reconnect only the postgres MCP server after the check passes" >&2
echo ""
cat "$STATE_FILE"
