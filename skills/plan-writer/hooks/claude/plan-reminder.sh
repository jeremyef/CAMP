#!/usr/bin/env bash
# Fires after every Edit / Write / MultiEdit.
#
# Case 1: a plan is marked "In Progress" -> nudge Claude (via
# additionalContext) to keep its TODO checklist in sync with the edit
# that just happened. Doesn't know whether the edit actually completed
# a TODO item -- can't reliably infer that from a diff alone -- so it
# just surfaces the active plan's path on every edit.
#
# Case 2: no plan is "In Progress", but one or more are "Approved" and
# this edit isn't touching the plans/memory/.claude directories ->
# nudge that real implementation work looks like it's starting and
# Status should probably move Approved -> In Progress for whichever
# plan this relates to (plan-writer step 8). Deliberately asks the
# agent to confirm with the user rather than flipping Status itself --
# this is a heuristic guess, not a certainty, and a wrong guess written
# to the plan file is trusted as fact by other hooks/checks afterward.
# Fires once per distinct set of Approved plans per session (tracked via
# a marker file) so it doesn't nag on every single edit, but does
# re-fire if the set of Approved plans changes mid-session.

INPUT=$(cat)

# Emit the JSON through json.dumps so quotes, backslashes and control
# characters in plan names, titles or paths can never break the output.
json_context() {
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":sys.argv[1]}}))' "$1"
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

PLANS_DIR=".claude/plans"
[ -d "$PLANS_DIR" ] || exit 0

# plans_with_status STATUS: plan files whose header status is exactly STATUS.
plans_with_status() {
  local want="$1" f
  for f in "$PLANS_DIR"/*.md; do
    [ -f "$f" ] || continue
    [ "$(plan_status "$f")" = "$want" ] && echo "$f"
  done
}

ACTIVE_PLAN=$(plans_with_status "In Progress" | xargs -r ls -t | head -n 1)

if [ -n "$ACTIVE_PLAN" ]; then
  json_context "Active plan: $ACTIVE_PLAN. If this edit completes a TODO item, check it off there before continuing."
  exit 0
fi

mapfile -t APPROVED < <(plans_with_status "Approved" | sort)
[ "${#APPROVED[@]}" -gt 0 ] || exit 0

# Extract the edited file's path from tool_input specifically (not a raw
# grep over the whole payload, which could match an unrelated key).
TARGET_PATH=$(python3 - "$INPUT" <<'PY'
import json, sys
try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print("")
    sys.exit(0)
tool_input = data.get("tool_input") or {}
print(tool_input.get("file_path") or tool_input.get("path") or "")
PY
)

# If we can't tell what was edited, say nothing rather than guessing.
[ -n "$TARGET_PATH" ] || exit 0

case "$TARGET_PATH" in
  plans/*.md|*/plans/*.md|memory/*|*/memory/*|.claude/*|*/.claude/*) exit 0 ;;
esac

SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
SET_KEY=$(printf '%s\n' "${APPROVED[@]}" | md5sum | cut -d' ' -f1)
MARKER_DIR=".claude/.reminders"
MARKER_FILE="$MARKER_DIR/${SESSION_ID:-nosession}-${SET_KEY}"
mkdir -p "$MARKER_DIR"
if [ -f "$MARKER_FILE" ]; then
  exit 0
fi
touch "$MARKER_FILE"

LIST=""
for plan in "${APPROVED[@]}"; do
  TITLE=$(head -n 1 "$plan" | sed -E 's/^# Plan: //')
  LIST="${LIST}${plan} (\"${TITLE}\"); "
done

json_context "This edit is outside the plans/memory directories, and these plans are Approved but not yet In Progress: ${LIST}If this edit is implementation work for one of them, ask the user whether to mark that specific plan In Progress -- don't update its Status line without confirming."
