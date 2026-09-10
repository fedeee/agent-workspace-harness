#!/usr/bin/env bash
# Start crystaldba/postgres-mcp against the mounted sidecar only.
# Reads /tmp/eval-sidecar-mcp.json (written by mount.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

POINTER="${EVAL_MCP_ENV:-/tmp/eval-sidecar-mcp.json}"
URI="${EVAL_SIDECAR_URL:-}"
MODE="${1:-serve}"
SESSION_ID=""
SOURCE="environment"

status() {
  local level="$1"
  local code="$2"
  local message="$3"
  printf '[postgres-mcp] level=%s code=%s message="%s"\n' \
    "$level" "$code" "$message" >&2
}

fail() {
  status "error" "$1" "$2"
  exit 1
}

read_pointer_value() {
  local key="$1"
  python3 "$SCRIPT_DIR/state.py" get "$POINTER" "$key"
}

if [[ "$MODE" != "serve" && "$MODE" != "--check" ]]; then
  fail "invalid_argument" "usage: postgres-mcp.sh [--check]"
fi

command -v awk >/dev/null 2>&1 ||
  fail "missing_command" "required command is unavailable: awk"
command -v python3 >/dev/null 2>&1 ||
  fail "missing_command" "required command is unavailable: python3"
command -v docker >/dev/null 2>&1 ||
  fail "missing_command" "required command is unavailable: docker"

if [[ -z "$URI" ]]; then
  SOURCE="$POINTER"
  [[ -f "$POINTER" ]] ||
    fail "pointer_missing" "mount a sidecar before starting the postgres MCP server: $POINTER"
  [[ -r "$POINTER" ]] ||
    fail "pointer_unreadable" "sidecar pointer is not readable: $POINTER"

  URI="$(read_pointer_value EVAL_SIDECAR_URL)"
  SESSION_ID="$(read_pointer_value SESSION_ID)"
  [[ -n "$URI" ]] ||
    fail "pointer_invalid" "sidecar pointer has no EVAL_SIDECAR_URL: $POINTER"
  [[ "$SESSION_ID" =~ ^[[:alnum:]-]+$ ]] ||
    fail "pointer_invalid" "sidecar pointer has an invalid SESSION_ID: $POINTER"

  STATE_FILE="/tmp/eval-sidecar-${SESSION_ID}/state.json"
  [[ -e "$STATE_FILE" ]] || STATE_FILE="/tmp/eval-sidecar-${SESSION_ID}/state.env"
  [[ -r "$STATE_FILE" ]] ||
    fail "pointer_stale" "sidecar state is missing; remount or remove stale pointer: $POINTER"
  STATE_URI="$(python3 "$SCRIPT_DIR/state.py" get "$STATE_FILE" EVAL_SIDECAR_URL)"
  [[ "$STATE_URI" == "$URI" ]] ||
    fail "pointer_stale" "sidecar pointer does not match session state: $STATE_FILE"
fi

PARSED="$(
  URI_TO_PARSE="$URI" python3 - <<'PY'
import os
from urllib.parse import urlparse

parsed = urlparse(os.environ["URI_TO_PARSE"])
if parsed.scheme not in {"postgres", "postgresql"}:
    raise SystemExit("URI scheme must be postgres or postgresql")
if not parsed.hostname or not parsed.port:
    raise SystemExit("URI must include a host and port")
database = parsed.path.lstrip("/")
if not parsed.username or not database:
    raise SystemExit("URI must include a user and database")
print("|".join((parsed.username, parsed.hostname, str(parsed.port), database)))
PY
)" || fail "uri_invalid" "EVAL_SIDECAR_URL is not a valid Postgres URI"

IFS='|' read -r DB_USER DB_HOST DB_PORT DB_NAME <<< "$PARSED"
[[ "$DB_USER" == "eval_ro" ]] ||
  fail "unsafe_user" "postgres MCP requires the read-only eval_ro role"
case "$DB_HOST" in
  localhost|127.0.0.1|host.docker.internal) ;;
  *) fail "unsafe_host" "postgres MCP requires a local sidecar host" ;;
esac
[[ "$DB_PORT" != "5432" && "$DB_PORT" != "5433" ]] ||
  fail "unsafe_port" "refusing the live local database port: $DB_PORT"

CHECK_HOST="$DB_HOST"
if [[ "$CHECK_HOST" == "host.docker.internal" ]]; then
  CHECK_HOST="127.0.0.1"
fi

CHECK_HOST="$CHECK_HOST" CHECK_PORT="$DB_PORT" python3 - <<'PY' ||
import os
import socket

with socket.create_connection(
    (os.environ["CHECK_HOST"], int(os.environ["CHECK_PORT"])),
    timeout=2,
):
    pass
PY
  fail "sidecar_unreachable" "cannot reach sidecar at ${CHECK_HOST}:${DB_PORT}"

docker info >/dev/null 2>&1 ||
  fail "docker_unavailable" "Docker daemon is not available"

status "info" "connection_ready" \
  "source=${SOURCE} session=${SESSION_ID:-override} host=${DB_HOST} port=${DB_PORT} database=${DB_NAME} user=${DB_USER}"

if [[ "$MODE" == "--check" ]]; then
  exit 0
fi

# Linux host networking can reach a loopback-only database bind.
NETWORK_ARGS=(--add-host=host.docker.internal:host-gateway)
MCP_HOST=host.docker.internal
if [[ "$(uname -s)" == Linux ]]; then
  NETWORK_ARGS=(--network host)
  MCP_HOST=127.0.0.1
fi
URI="$(URI_TO_PARSE="$URI" MCP_HOST="$MCP_HOST" python3 - <<'PYURI'
import os
from urllib.parse import urlparse

parsed = urlparse(os.environ["URI_TO_PARSE"])
if parsed.hostname in {"localhost", "127.0.0.1", "host.docker.internal"}:
    credentials = parsed.netloc.rsplit("@", 1)[0]
    parsed = parsed._replace(netloc=f"{credentials}@{os.environ['MCP_HOST']}:{parsed.port}")
print(parsed.geturl())
PYURI
)"

exec docker run -i --rm \
  "${NETWORK_ARGS[@]}" \
  -e "DATABASE_URI=${URI}" \
  crystaldba/postgres-mcp:latest \
  --access-mode=restricted
