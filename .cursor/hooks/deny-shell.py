#!/usr/bin/env python3
"""Deny git push, ssh, and git commit --no-verify."""
import json
import re
import sys

DENY = {
    "permission": "deny",
    "user_message": "Blocked git push, ssh, or git commit --no-verify.",
    "agent_message": "A hook blocked this command. Do not retry.",
}

def command_text(raw: str) -> str:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    if isinstance(data, dict):
        if isinstance(data.get("command"), str):
            return data["command"]
        tool_input = data.get("tool_input")
        if isinstance(tool_input, dict) and isinstance(tool_input.get("command"), str):
            return tool_input["command"]
    return raw

raw = sys.stdin.read()
command = command_text(raw)
blocked = re.search(
    r"git\s+push|--no-verify|(^|[^A-Za-z0-9_-])ssh\s",
    command,
)
print(json.dumps(DENY if blocked else {"permission": "allow"}))
