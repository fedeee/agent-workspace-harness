#!/usr/bin/env python3
"""Print a Codex MCP merge without changing existing TOML text or server values."""
import json
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None


def merge(existing, servers):
    if existing and tomllib is None:
        raise ValueError("Python 3.11+ is required to parse existing Codex TOML")
    config = tomllib.loads(existing) if existing else {}
    current = config.get("mcp_servers", {})
    if not isinstance(current, dict):
        raise ValueError("mcp_servers must be a TOML table")
    blocks = []
    for name, server in servers.items():
        if name in current:
            continue
        blocks.append(
            f"[mcp_servers.{json.dumps(name)}]\n"
            f"command = {json.dumps(server['command'])}\n"
            f"args = {json.dumps(server.get('args', []))}\n"
        )
    if not blocks:
        return ""
    result = existing + "\n" + "\n".join(blocks)
    if tomllib is not None:
        tomllib.loads(result)
    return result


if __name__ == "__main__":
    try:
        path = Path(sys.argv[1])
        existing = path.read_text() if path.exists() else ""
        sys.stdout.write(merge(existing, json.load(sys.stdin)))
    except (OSError, ValueError, KeyError) as error:
        print(f"codex-mcp: {error}", file=sys.stderr)
        sys.exit(2)
