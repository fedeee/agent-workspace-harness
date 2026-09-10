#!/usr/bin/env python3
"""Guard common forbidden commands for Cursor, Claude Code, and Codex.

This is a guardrail, not a shell interpreter or a security boundary.
"""
import json
import os
import shlex
import sys

REASON = "Blocked git push, ssh, or git commit --no-verify. The user handles remote operations."


def is_blocked(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    tokens = list(lexer)
    for index, token in enumerate(tokens):
        program = os.path.basename(token)
        if program == "ssh":
            return True
        if program in {"bash", "sh", "zsh"}:
            tail = tokens[index + 1:]
            for pos, option in enumerate(tail[:-1]):
                if option.startswith("-") and "c" in option:
                    if is_blocked(tail[pos + 1]):
                        return True
        if program != "git":
            continue
        tail = tokens[index + 1:]
        pos = 0
        while pos < len(tail) and tail[pos].startswith("-"):
            option = tail[pos]
            pos += 2 if option in {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"} else 1
        if pos >= len(tail):
            continue
        if tail[pos] == "push":
            return True
        if tail[pos] == "commit":
            for arg in tail[pos + 1:]:
                if arg in {";", "&&", "||", "|"}:
                    break
                if arg in {"--no-verify", "-n"}:
                    return True
    return False


def main():
    raw = sys.stdin.read()
    data = None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        pass
    pre_tool = isinstance(data, dict) and (
        data.get("hook_event_name") == "PreToolUse" or "tool_input" in data
    )
    if isinstance(data, dict):
        source = data.get("tool_input", data)
        command = source.get("command", source.get("cmd")) if isinstance(source, dict) else None
    else:
        command = raw
    try:
        blocked = not isinstance(command, str) or not command.strip() or is_blocked(command)
    except (ValueError, RecursionError):
        blocked = True
    if pre_tool:
        # Do not emit allow: normal tool permissions must still apply.
        result = {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REASON,
        }} if blocked else {}
    else:
        result = {"permission": "deny", "user_message": REASON,
                  "agent_message": "A hook blocked this command. Do not retry."} if blocked else {"permission": "allow"}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
