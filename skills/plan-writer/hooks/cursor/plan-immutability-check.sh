#!/usr/bin/env bash
# preToolUse — blocks edits to plan files already marked Status: Complete.
# Completed plans are immutable; any follow-on work requires a new plan file.

set -euo pipefail

INPUT=$(cat)

python3 - "$INPUT" <<'PY'
import json
import os
import sys

def allow():
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    allow()

tool = data.get("tool_name", "")
if tool not in ("Write", "StrReplace", "Delete"):
    allow()

tool_input = data.get("tool_input") or {}
path = tool_input.get("path") or tool_input.get("file_path") or ""
if not path:
    allow()

normalized = path.replace("\\", "/")
if "/plans/" not in normalized or not normalized.endswith(".md"):
    allow()

if not os.path.isfile(path):
    allow()

try:
    with open(path, encoding="utf-8") as f:
        content = f.read()
except OSError:
    allow()

if "**Status:** Complete" not in content:
    allow()

plan_name = os.path.basename(path)
msg = (
    f"{plan_name} is marked Status: Complete — completed plans are immutable. "
    "For follow-on work, create a new plan file referencing this one. For a "
    "small note, add it to this session's wrap-up instead. If you believe "
    "this was marked Complete in error, ask the user before reopening it — "
    "do not set Status back to In Progress yourself."
)
print(json.dumps({
    "permission": "deny",
    "user_message": msg,
    "agent_message": msg,
}))
PY
