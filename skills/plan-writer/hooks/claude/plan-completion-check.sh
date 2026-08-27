#!/usr/bin/env bash
# Fires when Claude is about to end its turn. If a plan is marked
# "In Progress" or "Complete" and still has unchecked TODO items, blocks
# the stop once and asks Claude to fix it. This runs at Stop time
# regardless of what caused the bad state (Claude's own edit, or a
# hand-edit outside the session), so it catches the "marked Complete
# with leftover TODOs" case the same way it already catches "In
# Progress with leftover TODOs."
#
# The stop_hook_active check is what stops this from looping forever: if
# Claude genuinely can't finish (e.g. it needs you to answer something),
# blocking it a second time in a row would trap the session. This lets it
# stop on the second attempt no matter what.

INPUT=$(cat)

if echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

PLANS_DIR=".claude/plans"
[ -d "$PLANS_DIR" ] || exit 0

for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue

  STATUS=$(grep -oE '\*\*Status:\*\* (In Progress|Complete)' "$plan" | head -n 1 | sed -E 's/\*\*Status:\*\* //')
  [ -n "$STATUS" ] || continue

  UNCHECKED=$(grep -c '^- \[ \]' "$plan")
  [ "$UNCHECKED" -gt 0 ] || continue

  if [ "$STATUS" = "Complete" ]; then
    REASON="$plan is marked Complete but still has $UNCHECKED unchecked TODO item(s). A plan can only be Complete once every item is checked off (plan-writer step 8). Finish and check off the remaining items, or set Status back to In Progress if it isn't actually done."
  else
    REASON="$plan still has $UNCHECKED unchecked TODO item(s) and is marked In Progress. Finish them, or if you're intentionally pausing, update the plan's Status line and say why before stopping."
  fi

  cat <<EOF
{
  "decision": "block",
  "reason": "$REASON"
}
EOF
  exit 0
done

exit 0
