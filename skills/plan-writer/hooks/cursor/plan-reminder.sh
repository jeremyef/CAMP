#!/usr/bin/env bash
# Fires after every Write / StrReplace. If there's a plan file marked
# "In Progress", nudges the agent (via additional_context) to keep that
# plan's TODO checklist in sync with the edit that just happened.

set -euo pipefail

PLANS_DIR=".cursor/plans"
[ -d "$PLANS_DIR" ] || exit 0

ACTIVE_PLAN=""
for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue
  grep -Fq "**Status:** In Progress" "$plan" || continue
  if [ -z "$ACTIVE_PLAN" ] || [ "$plan" -nt "$ACTIVE_PLAN" ]; then
    ACTIVE_PLAN="$plan"
  fi
done

[ -n "$ACTIVE_PLAN" ] || exit 0

cat <<EOF
{
  "additional_context": "Active plan: $ACTIVE_PLAN. If this edit completes a TODO item, check it off there before continuing."
}
EOF
