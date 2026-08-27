#!/usr/bin/env bash
# Fires after every Write / StrReplace.
#
# Case 1: a plan is marked "In Progress" -> nudge (via additional_context)
# to keep that plan's TODO checklist in sync with the edit that just
# happened.
#
# Case 2: no plan is "In Progress", but one or more are "Approved" and
# this edit isn't touching the plans/memory/.cursor directories -> nudge
# that Status should probably move Approved -> In Progress for whichever
# plan this relates to (plan-writer step 8). Asks the agent to confirm
# with the user rather than flipping Status itself -- this is a
# heuristic guess, not a certainty. Fires once per distinct set of
# Approved plans per session (tracked via a marker file), re-firing if
# that set changes mid-session.

set -euo pipefail

PLANS_DIR=".cursor/plans"
[ -d "$PLANS_DIR" ] || exit 0

INPUT=$(cat)

ACTIVE_PLAN=""
for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue
  grep -Fq "**Status:** In Progress" "$plan" || continue
  if [ -z "$ACTIVE_PLAN" ] || [ "$plan" -nt "$ACTIVE_PLAN" ]; then
    ACTIVE_PLAN="$plan"
  fi
done

if [ -n "$ACTIVE_PLAN" ]; then
  cat <<EOF
{
  "additional_context": "Active plan: $ACTIVE_PLAN. If this edit completes a TODO item, check it off there before continuing."
}
EOF
  exit 0
fi

APPROVED_PLANS=()
for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue
  grep -Fq "**Status:** Approved" "$plan" || continue
  APPROVED_PLANS+=("$plan")
done
[ "${#APPROVED_PLANS[@]}" -gt 0 ] || exit 0

TARGET_PATH=$(python3 - "$INPUT" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print("")
    sys.exit(0)
tool_input = data.get("tool_input") or {}
print(tool_input.get("path") or tool_input.get("file_path") or "")
PY
)

# If we can't tell what was edited, say nothing rather than guessing.
[ -n "$TARGET_PATH" ] || exit 0

case "$TARGET_PATH" in
  plans/*.md|*/plans/*.md|memory/*|*/memory/*|.cursor/*|*/.cursor/*) exit 0 ;;
esac

SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
SET_KEY=$(printf '%s\n' "${APPROVED_PLANS[@]}" | md5sum | cut -d' ' -f1)
MARKER_DIR=".cursor/.reminders"
MARKER_FILE="$MARKER_DIR/${SESSION_ID:-nosession}-${SET_KEY}"
mkdir -p "$MARKER_DIR"
if [ -f "$MARKER_FILE" ]; then
  exit 0
fi
touch "$MARKER_FILE"

LIST=""
for plan in "${APPROVED_PLANS[@]}"; do
  TITLE=$(head -n 1 "$plan" | sed -E 's/^# Plan: //')
  LIST="${LIST}${plan} (\\\"${TITLE}\\\"); "
done

cat <<EOF
{
  "additional_context": "This edit is outside the plans/memory directories, and these plans are Approved but not yet In Progress: ${LIST}If this edit is implementation work for one of them, ask the user whether to mark that specific plan In Progress -- don't update its Status line without confirming."
}
EOF
