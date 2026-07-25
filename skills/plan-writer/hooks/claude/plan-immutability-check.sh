#!/usr/bin/env bash
# PreToolUse — blocks edits to plan files already marked Status: Complete.
# Completed plans are immutable; any follow-on work requires a new plan file.

INPUT=$(cat)

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
  grep -Fq "**Status:** Complete" "$FILE_PATH" || continue

  PLAN_NAME=$(basename "$FILE_PATH")
  cat <<EOF
{
  "decision": "block",
  "reason": "${PLAN_NAME} is marked Status: Complete — completed plans are immutable. For follow-on work, create a new plan file referencing this one. For a small note, add it to this session's wrap-up instead. If you believe this was marked Complete in error, ask the user before reopening it — do not set Status back to In Progress yourself."
}
EOF
  exit 0
done < <(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"/\1/')

exit 0
