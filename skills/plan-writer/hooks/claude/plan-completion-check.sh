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

if echo "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

PLANS_DIR=".claude/plans"
[ -d "$PLANS_DIR" ] || exit 0

# Collect every problem across all plans and report them in one block, so a
# single stop never hides the rest (the second stop attempt always passes).
PROBLEMS=""
for plan in "$PLANS_DIR"/*.md; do
  [ -f "$plan" ] || continue

  STATUS=$(plan_status "$plan")
  if [ -z "$STATUS" ]; then
    RAW=$(plan_status_raw "$plan" | cut -c1-40)
    [ -n "$RAW" ] && SEEN="read: '$RAW'" || SEEN="no status found"
    PROBLEMS="${PROBLEMS}$plan has no recognisable status ($SEEN). The header line must read '> **Date:** ... **Status:** X' where X starts with exactly one of: Draft, Approved, In Progress, Paused, Complete, Superseded. Until it does, the plan hooks do not protect this plan. Fix the header, or tell the user. | "
    continue
  fi
  case "$STATUS" in
    "In Progress"|Complete) ;;
    *) continue ;;
  esac

  UNCHECKED=$(grep -c '^- \[ \]' "$plan")
  [ "$UNCHECKED" -gt 0 ] || continue

  if [ "$STATUS" = "Complete" ]; then
    REASON="$plan is marked Complete but still has $UNCHECKED unchecked TODO item(s). A plan can only be Complete once every item is checked off (plan-writer step 8). You cannot edit or reopen a Complete plan. Stop and tell the user, so they can decide whether to reopen it (by editing its header by hand) or accept the unchecked items."
  else
    REASON="$plan still has $UNCHECKED unchecked TODO item(s) and is marked In Progress. Finish them, or if you're intentionally pausing, add a Decision log entry saying why, set the plan's Status to Paused, and then stop."
  fi

  PROBLEMS="${PROBLEMS}${REASON} | "
done

if [ -n "$PROBLEMS" ]; then
  json_block "${PROBLEMS% | }"
fi
exit 0
