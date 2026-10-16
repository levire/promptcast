#!/usr/bin/env python3
"""Reminds an agent of the comment rule when an edit adds a comment of more than QUIET_LINES lines.

Reads a PostToolUse hook payload on standard input and prints nothing for shorter comments.
"""
import json
import sys

MARKERS = ("//", "#", "/*", "*", "<!--")

QUIET_LINES = 3

REMINDER = (
    f"This edit added a comment of more than {QUIET_LINES} lines. "
    "docs/agents/writing.md: name the wrong belief the comment prevents, and if "
    "its content fits in a name, rename the thing and write nothing. Keep what is "
    "left short: plain words, one fact per sentence. The reason for a design "
    "choice goes in the pull request."
)


def written(payload):
    tool_input = payload.get("tool_input") or {}
    edits = tool_input.get("edits")
    if isinstance(edits, list):
        return "\n".join(str(e.get("new_string", "")) for e in edits)
    return str(tool_input.get("new_string") or tool_input.get("content") or "")


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    run = 0
    for line in written(payload).splitlines():
        if not line.strip().startswith(MARKERS):
            run = 0
            continue
        run += 1
        if run > QUIET_LINES:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": REMINDER}}))
            return


main()
