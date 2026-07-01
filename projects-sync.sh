#!/usr/bin/env bash
set -euo pipefail

# sync-projects.sh — push skills and protocol files from this template
# to all registered projects.
#
# Usage: ./sync-projects.sh [--dry-run]
#
# Projects are listed in projects.txt (one absolute path per line).
# Copy projects.example.txt to projects.txt and add your project paths.

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$TEMPLATE_DIR/projects.txt"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "Error: unknown argument '$arg'" >&2; exit 1 ;;
  esac
done

if [ ! -f "$REGISTRY" ]; then
  echo "Error: projects.txt not found." >&2
  echo "Copy projects.example.txt to projects.txt and add your project paths." >&2
  exit 1
fi

SKILLS=(brief decide plan-writer wrap-up)
SYNCED=0
ERRORS=0

sync_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "  WARNING: source missing: $src" >&2
    return
  fi
  if $DRY_RUN; then
    if ! diff -q "$src" "$dst" &>/dev/null 2>&1; then
      echo "  [dry-run] would update: $dst"
    fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
  [[ -z "$PROJECT" || "$PROJECT" == \#* ]] && continue

  if [ ! -d "$PROJECT" ]; then
    echo "WARNING: project directory not found: $PROJECT" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "Syncing → $PROJECT"

  sync_file "$TEMPLATE_DIR/AGENTS.md" "$PROJECT/AGENTS.md"

  if [ -f "$TEMPLATE_DIR/WORKFLOW.md" ]; then
    sync_file "$TEMPLATE_DIR/WORKFLOW.md" "$PROJECT/WORKFLOW.md"
  fi

  for skill in "${SKILLS[@]}"; do
    src="$TEMPLATE_DIR/skills/$skill/SKILL.md"
    sync_file "$src" "$PROJECT/.claude/skills/$skill/SKILL.md"
    sync_file "$src" "$PROJECT/.cursor/skills/$skill/SKILL.md"
  done

  # Sync plan-writer hook scripts (Claude Code)
  mkdir -p "$PROJECT/.claude/hooks"
  for hook in plan-reminder plan-completion-check; do
    sync_file "$TEMPLATE_DIR/skills/plan-writer/hooks/claude/$hook.sh" \
              "$PROJECT/.claude/hooks/$hook.sh"
    $DRY_RUN || chmod +x "$PROJECT/.claude/hooks/$hook.sh"
  done

  # Write-if-absent: Claude Code hook registration
  if [ ! -f "$PROJECT/.claude/settings.json" ]; then
    if $DRY_RUN; then
      echo "  [dry-run] would create: $PROJECT/.claude/settings.json"
    else
      cat > "$PROJECT/.claude/settings.json" << 'JSON'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/plan-reminder.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/plan-completion-check.sh"
          }
        ]
      }
    ]
  }
}
JSON
    fi
  fi

  # Cursor: only if .cursor/ exists in the project
  if [ -d "$PROJECT/.cursor" ]; then
    mkdir -p "$PROJECT/.cursor/hooks"
    for hook in plan-reminder plan-completion-check; do
      sync_file "$TEMPLATE_DIR/skills/plan-writer/hooks/cursor/$hook.sh" \
                "$PROJECT/.cursor/hooks/$hook.sh"
      $DRY_RUN || chmod +x "$PROJECT/.cursor/hooks/$hook.sh"
    done

    # Write-if-absent: Cursor hook registration
    if [ ! -f "$PROJECT/.cursor/hooks.json" ]; then
      if $DRY_RUN; then
        echo "  [dry-run] would create: $PROJECT/.cursor/hooks.json"
      else
        cat > "$PROJECT/.cursor/hooks.json" << 'JSON'
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      {
        "matcher": "Write|StrReplace",
        "command": ".cursor/hooks/plan-reminder.sh"
      }
    ],
    "stop": [
      {
        "command": ".cursor/hooks/plan-completion-check.sh",
        "loop_limit": null
      }
    ]
  }
}
JSON
      fi
    fi
  fi

  SYNCED=$((SYNCED + 1))
done < "$REGISTRY"

echo ""
if $DRY_RUN; then
  echo "Dry run complete — $SYNCED project(s) checked, $ERRORS error(s)."
else
  echo "Sync complete — $SYNCED project(s) updated, $ERRORS error(s)."
fi
