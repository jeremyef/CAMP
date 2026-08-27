#!/usr/bin/env bash
# Fires when the agent is about to end its turn. If a plan is marked
# "In Progress" or "Complete" and still has unchecked TODO items, sends
# a follow-up message asking the agent to fix it.
#
# The loop_count check prevents infinite loops: if the agent genuinely
# can't finish (e.g. it needs you to answer something), it won't be
# interrupted a second time.

set -euo pipefail

INPUT=$(cat)

# Only intervene on a normal completion (not abort/error)
echo "$INPUT" | grep -q '"status"[[:space:]]*:[[:space:]]*"completed"' || exit 0

# loop_count > 0 means we already followed up once → allow stop
if echo "$INPUT" | grep -qE '"loop_count"[[:space:]]*:[[:space:]]*[1-9]'; then
  exit 0
fi

PLANS_DIR=".cursor/plans"
[ -d "$PLANS_DIR" ] || exit 0

for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue

  STATUS=$(grep -oE '\*\*Status:\*\* (In Progress|Complete)' "$plan" | head -n 1 | sed -E 's/\*\*Status:\*\* //')
  [ -n "$STATUS" ] || continue

  UNCHECKED=$(grep -c '^- \[ \]' "$plan")
  [ "$UNCHECKED" -gt 0 ] || continue

  if [ "$STATUS" = "Complete" ]; then
    MSG="$plan is marked Complete but still has $UNCHECKED unchecked TODO item(s). A plan can only be Complete once every item is checked off (plan-writer step 8). Finish and check off the remaining items, or set Status back to In Progress if it isn't actually done."
  else
    MSG="$plan still has $UNCHECKED unchecked TODO item(s) and is marked In Progress. Finish them, or if you're intentionally pausing, update the plan's Status line and say why before stopping."
  fi

  cat <<EOF
{
  "followup_message": "$MSG"
}
EOF
  exit 0
done

exit 0
