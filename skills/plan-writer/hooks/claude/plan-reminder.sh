#!/usr/bin/env bash
# Fires after every Edit / Write / MultiEdit. If there's a plan file marked
# "In Progress", nudges Claude (via additionalContext, not a prompt it can
# ignore) to keep that plan's TODO checklist in sync with the edit that
# just happened.
#
# This doesn't know whether the edit actually completed a TODO item -- it
# can't reliably infer that from a diff alone -- so it just surfaces the
# active plan's path on every edit. Claude still makes the judgment call
# of which item to check off, but it can no longer "forget" the file exists.

PLANS_DIR=".claude/plans"
[ -d "$PLANS_DIR" ] || exit 0

ACTIVE_PLAN=$(grep -Fl "**Status:** In Progress" "$PLANS_DIR"/*.md 2>/dev/null | xargs -r ls -t | head -n 1)
[ -n "$ACTIVE_PLAN" ] || exit 0

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Active plan: $ACTIVE_PLAN. If this edit completes a TODO item, check it off there before continuing."
  }
}
EOF
