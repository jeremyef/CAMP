#!/usr/bin/env bash
# PreToolUse — blocks edits to plan files whose header status is Complete or
# Superseded. Both are terminal: any follow-on work requires a new plan file,
# and only the user may reopen one.

INPUT=$(cat)

# Emit the JSON through json.dumps so quotes, backslashes and control
# characters in plan names, titles or status text can never break the output.
json_block() {
  python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$1"
}

# The plan's status lives in its header line only (`> **Date:** ... **Status:** X`).
# Read that line, never the whole file, so a plan that merely quotes a status
# string in its body is not mistaken for having that status.
plan_status_raw() {
  grep -m1 -E '^> \*\*Date:\*\*' "$1" 2>/dev/null | sed -nE 's/.*\*\*Status:\*\* *//p' | sed -E 's/[[:space:]]+$//'
}
# The recognised status is the leading word: one of the six values, followed
# by end of line or a non-letter. A short trailing note is tolerated.
plan_status() {
  plan_status_raw "$1" | sed -nE 's/^(Draft|Approved|In Progress|Paused|Complete|Superseded)([^A-Za-z].*)?$/\1/p'
}

TOOL=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"/\1/')
case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

# Extract all file_path values — MultiEdit carries one per edit in the array
while IFS= read -r FILE_PATH; do
  [ -n "$FILE_PATH" ] || continue

  case "$FILE_PATH" in
    */plans/*.md) ;;
    *) continue ;;
  esac

  [ -f "$FILE_PATH" ] || continue
  STATUS=$(plan_status "$FILE_PATH")
  case "$STATUS" in
    Complete|Superseded) ;;
    *) continue ;;
  esac

  PLAN_NAME=$(basename "$FILE_PATH")
  json_block "${PLAN_NAME} is marked Status: ${STATUS}. Complete and Superseded plans are immutable, and the agent never edits or reopens one. For follow-on work, create a new plan file referencing this one. For a small note, add it to this session's wrap-up instead. If you believe the plan was closed in error, stop and tell the user: only the user can reopen it, by editing its header by hand."
  exit 0
done < <(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"/\1/')

exit 0
