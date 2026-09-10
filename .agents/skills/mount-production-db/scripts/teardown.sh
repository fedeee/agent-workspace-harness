#!/usr/bin/env bash
# Tear down an eval sidecar started by mount.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FALLBACK="$SCRIPT_DIR/docker-compose.yml"

usage() {
  cat <<'EOF'
Usage:
  teardown.sh <session_id>
  teardown.sh /tmp/eval-sidecar-<id>/state.json
  teardown.sh --list
  teardown.sh --all
EOF
}

MCP_POINTER="${EVAL_MCP_ENV:-/tmp/eval-sidecar-mcp.json}"

list_sessions() {
  echo "Active /tmp sessions:"
  ls -d /tmp/eval-sidecar-* 2>/dev/null || echo "  (none)"
  echo ""
  echo "Docker containers matching eval-sidecar-:"
  docker ps -a --filter name=eval-sidecar- --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
}

remove_mcp_pointer_if_ours() {
  local sid="$1"
  local pointer_sid=""
  [[ -f "$MCP_POINTER" ]] || return 0
  pointer_sid="$(python3 "$SCRIPT_DIR/state.py" get "$MCP_POINTER" SESSION_ID)"
  if [[ "$pointer_sid" == "$sid" ]]; then
    rm -f "$MCP_POINTER"
    echo "[teardown] removed MCP pointer $MCP_POINTER" >&2
  fi
}

teardown_one() {
  local target="$1"
  local state_file=""
  local session_id=""
  local compose_project=""
  local compose_file=""
  local state_dir=""
  local db_port=""
  if [[ -f "$target" ]]; then
    state_file="$target"
  elif [[ -d "/tmp/eval-sidecar-${target}" ]]; then
    state_file="/tmp/eval-sidecar-${target}/state.json"
    session_id="$target"
  elif [[ "$target" == /tmp/eval-sidecar-* ]]; then
    state_file="${target%/}/state.json"
  else
    session_id="$target"
    state_file="/tmp/eval-sidecar-${session_id}/state.json"
  fi

  if [[ ! -f "$state_file" && -f "${state_file%.json}.env" ]]; then
    state_file="${state_file%.json}.env"
  fi
  if [[ -f "$state_file" ]]; then
    session_id="$(python3 "$SCRIPT_DIR/state.py" get "$state_file" SESSION_ID)"
    compose_project="$(python3 "$SCRIPT_DIR/state.py" get "$state_file" COMPOSE_PROJECT)"
    state_dir="$(python3 "$SCRIPT_DIR/state.py" get "$state_file" STATE_DIR)"
    db_port="$(python3 "$SCRIPT_DIR/state.py" get "$state_file" DB_PORT)"
    compose_file="$COMPOSE_FALLBACK"
  else
    echo "[teardown] warning: no state file at $state_file — best-effort by session id" >&2
    session_id="${session_id:-$target}"
    compose_project="eval-sidecar-${session_id}"
    state_dir="/tmp/eval-sidecar-${session_id}"
  fi

  [[ "$session_id" =~ ^[[:alnum:]-]+$ ]] || {
    echo "error: invalid sidecar session id" >&2
    return 1
  }
  [[ "$state_dir" == "/tmp/eval-sidecar-${session_id}" ]] || {
    echo "error: refused unexpected sidecar state directory: $state_dir" >&2
    return 1
  }
  [[ "$compose_project" == "eval-sidecar-${session_id}" ]] || {
    echo "error: refused unexpected compose project: $compose_project" >&2
    return 1
  }

  if [[ -z "$compose_file" || ! -f "$compose_file" ]]; then
    compose_file="$COMPOSE_FALLBACK"
  fi

  echo "[teardown] session=${session_id} project=${compose_project}" >&2

  if [[ -n "$compose_file" && -f "$compose_file" ]]; then
    COMPOSE_PROJECT_NAME="$compose_project" DB_PORT="${db_port:-55433}" \
      docker compose -f "$compose_file" down -v >&2 || return 1
  else
    echo "[teardown] warning: compose file not found; stopping containers by name" >&2
    ids="$(docker ps -aq --filter "name=${compose_project}" 2>/dev/null || true)"
    if [[ -n "$ids" ]]; then
      # shellcheck disable=SC2086
      docker rm -f $ids >&2 || true
    fi
    vols="$(docker volume ls -q --filter "name=${compose_project}" 2>/dev/null || true)"
    if [[ -n "$vols" ]]; then
      # shellcheck disable=SC2086
      docker volume rm $vols >&2 || true
    fi
  fi

  if [[ -n "$state_dir" && -d "$state_dir" ]]; then
    rm -rf "$state_dir"
    echo "[teardown] removed $state_dir" >&2
  fi

  remove_mcp_pointer_if_ours "$session_id"

  echo "[teardown] done" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
  --list)
    list_sessions
    exit 0
    ;;
  --all)
    for d in /tmp/eval-sidecar-*; do
      [[ -d "$d" ]] || continue
      teardown_one "$d/state.json"
    done
    ids="$(docker ps -aq --filter name=eval-sidecar- 2>/dev/null || true)"
    if [[ -n "$ids" ]]; then
      # shellcheck disable=SC2086
      docker rm -f $ids >&2 || true
    fi
    vols="$(docker volume ls -q --filter name=eval-sidecar- 2>/dev/null || true)"
    if [[ -n "$vols" ]]; then
      # shellcheck disable=SC2086
      docker volume rm $vols >&2 || true
    fi
    rm -f "$MCP_POINTER"
    exit 0
    ;;
  *)
    teardown_one "$1"
    ;;
esac
