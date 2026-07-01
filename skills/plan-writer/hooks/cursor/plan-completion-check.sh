#!/usr/bin/env bash
# Fires when the agent is about to end its turn. If a plan is marked
# "In Progress" and still has unchecked TODO items, sends a follow-up
# message asking the agent to finish or explain why it's pausing.
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
  grep -Fq "**Status:** In Progress" "$plan" || continue

  UNCHECKED=$(grep -c '^- \[ \]' "$plan")
  if [ "$UNCHECKED" -gt 0 ]; then
    cat <<EOF
{
  "followup_message": "$plan still has $UNCHECKED unchecked TODO item(s) and is marked In Progress. Finish them, or if you're intentionally pausing, update the plan's Status line and say why before stopping."
}
EOF
    exit 0
  fi
done

exit 0
