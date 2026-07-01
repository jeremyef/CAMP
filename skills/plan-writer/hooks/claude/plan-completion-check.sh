#!/usr/bin/env bash
# Fires when Claude is about to end its turn. If a plan is marked
# "In Progress" and still has unchecked TODO items, blocks the stop once
# and asks Claude to either finish, or explicitly mark why it's pausing.
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
  grep -Fq "**Status:** In Progress" "$plan" || continue

  UNCHECKED=$(grep -c '^- \[ \]' "$plan")
  if [ "$UNCHECKED" -gt 0 ]; then
    cat <<EOF
{
  "decision": "block",
  "reason": "$plan still has $UNCHECKED unchecked TODO item(s) and is marked In Progress. Finish them, or if you're intentionally pausing, update the plan's Status line and say why before stopping."
}
EOF
    exit 0
  fi
done

exit 0
