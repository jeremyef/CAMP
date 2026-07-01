#!/usr/bin/env bash
set -euo pipefail

# projects-sync.sh — push skills, protocol files, and hooks from this template
# to all registered projects. Auto-commits synced files in each project unless
# --no-commit is passed.
#
# Usage: ./projects-sync.sh [--dry-run] [--no-commit]
#
# Projects are listed in projects.txt (one absolute path per line).
# Copy projects.example.txt to projects.txt and add your project paths.

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$TEMPLATE_DIR/projects.txt"
DRY_RUN=false
NO_COMMIT=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --no-commit) NO_COMMIT=true ;;
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
SYNC_TARGETS=()

# sync_file — copy src to dst. Appends dst to SYNC_TARGETS on write.
# Increments ERRORS (not SYNCED) if src is missing.
sync_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "  WARNING: source missing: $src" >&2
    ERRORS=$((ERRORS + 1))
    return
  fi
  if $DRY_RUN; then
    if ! diff -q "$src" "$dst" &>/dev/null; then
      echo "  [dry-run] would update: $dst"
    fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  SYNC_TARGETS+=("$dst")
}

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
  [[ -z "$PROJECT" || "$PROJECT" == \#* ]] && continue

  if [ ! -d "$PROJECT" ]; then
    echo "WARNING: project directory not found: $PROJECT" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "Syncing → $PROJECT"
  SYNC_TARGETS=()

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
  $DRY_RUN || mkdir -p "$PROJECT/.claude/hooks"
  for hook in plan-reminder plan-completion-check plan-immutability-check; do
    sync_file "$TEMPLATE_DIR/skills/plan-writer/hooks/claude/$hook.sh" \
              "$PROJECT/.claude/hooks/$hook.sh"
    if ! $DRY_RUN && [ -f "$PROJECT/.claude/hooks/$hook.sh" ]; then
      chmod +x "$PROJECT/.claude/hooks/$hook.sh"
    fi
  done

  patch_claude_immutability_hook() {
    local settings="$PROJECT/.claude/settings.json"
    [ -f "$settings" ] || return 0
    if $DRY_RUN; then
        if ! python3 - "$settings" <<'PY' 2>/dev/null; then
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cmd = "bash .claude/hooks/plan-immutability-check.sh"
for group in data.get("hooks", {}).get("PreToolUse", []):
    for hook in group.get("hooks", []):
        if hook.get("command") == cmd:
            sys.exit(0)
sys.exit(1)
PY
        echo "  [dry-run] would patch: $settings (add PreToolUse plan-immutability-check)"
      fi
      return 0
    fi
    python3 - "$settings" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])
cmd = "bash .claude/hooks/plan-immutability-check.sh"

for group in pre:
    for hook in group.get("hooks", []):
        if hook.get("command") == cmd:
            sys.exit(0)

pre.insert(0, {
    "matcher": "Edit|Write|MultiEdit",
    "hooks": [{"type": "command", "command": cmd}],
})

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    SYNC_TARGETS+=("$settings")
  }

  # Write-if-absent: Claude Code hook registration
  if [ ! -f "$PROJECT/.claude/settings.json" ]; then
    if $DRY_RUN; then
      echo "  [dry-run] would create: $PROJECT/.claude/settings.json"
    else
      echo "  creating: $PROJECT/.claude/settings.json"
      cat > "$PROJECT/.claude/settings.json" << 'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/plan-immutability-check.sh"
          }
        ]
      }
    ],
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
      SYNC_TARGETS+=("$PROJECT/.claude/settings.json")
    fi
  else
    patch_claude_immutability_hook
  fi

  # Cursor: only if .cursor/ exists in the project
  if [ -d "$PROJECT/.cursor" ]; then
    $DRY_RUN || mkdir -p "$PROJECT/.cursor/hooks"
    for hook in plan-reminder plan-completion-check plan-immutability-check; do
      sync_file "$TEMPLATE_DIR/skills/plan-writer/hooks/cursor/$hook.sh" \
                "$PROJECT/.cursor/hooks/$hook.sh"
      if ! $DRY_RUN && [ -f "$PROJECT/.cursor/hooks/$hook.sh" ]; then
        chmod +x "$PROJECT/.cursor/hooks/$hook.sh"
      fi
    done

    patch_cursor_immutability_hook() {
      local hooks_json="$PROJECT/.cursor/hooks.json"
      [ -f "$hooks_json" ] || return 0
      if $DRY_RUN; then
        if ! python3 - "$hooks_json" <<'PY' 2>/dev/null; then
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cmd = ".cursor/hooks/plan-immutability-check.sh"
for hook in data.get("hooks", {}).get("preToolUse", []):
    if hook.get("command") == cmd:
        sys.exit(0)
sys.exit(1)
PY
          echo "  [dry-run] would patch: $hooks_json (add preToolUse plan-immutability-check)"
        fi
        return 0
      fi
      python3 - "$hooks_json" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
pre = hooks.setdefault("preToolUse", [])
cmd = ".cursor/hooks/plan-immutability-check.sh"

for hook in pre:
    if hook.get("command") == cmd:
        sys.exit(0)

pre.insert(0, {
    "matcher": "Write|StrReplace|Delete",
    "command": cmd,
})

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
      SYNC_TARGETS+=("$hooks_json")
    }

    # Write-if-absent: Cursor hook registration
    if [ ! -f "$PROJECT/.cursor/hooks.json" ]; then
      if $DRY_RUN; then
        echo "  [dry-run] would create: $PROJECT/.cursor/hooks.json"
      else
        echo "  creating: $PROJECT/.cursor/hooks.json"
        cat > "$PROJECT/.cursor/hooks.json" << 'JSON'
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "matcher": "Write|StrReplace|Delete",
        "command": ".cursor/hooks/plan-immutability-check.sh"
      }
    ],
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
        SYNC_TARGETS+=("$PROJECT/.cursor/hooks.json")
      fi
    else
      patch_cursor_immutability_hook
    fi
  fi

  # Auto-commit synced files (skipped in dry-run, if --no-commit, or no git repo)
  if ! $DRY_RUN && ! $NO_COMMIT && [ -d "$PROJECT/.git" ] && [ ${#SYNC_TARGETS[@]} -gt 0 ]; then
    (
      cd "$PROJECT"
      for f in "${SYNC_TARGETS[@]}"; do
        rel="${f#$PROJECT/}"
        [ -f "$rel" ] && git add "$rel"
      done
      if ! git diff --cached --quiet; then
        git commit -m "chore(sync): sync from $(basename "$TEMPLATE_DIR") template"
        echo "  committed."
      fi
    )
  fi

  SYNCED=$((SYNCED + 1))
done < "$REGISTRY"

echo ""
if $DRY_RUN; then
  echo "Dry run complete — $SYNCED project(s) checked, $ERRORS error(s)."
else
  echo "Sync complete — $SYNCED project(s) updated, $ERRORS error(s)."
fi
