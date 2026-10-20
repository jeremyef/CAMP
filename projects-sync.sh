#!/usr/bin/env bash
set -euo pipefail

# projects-sync.sh — push skills, protocol files, and hooks from this template
# to all registered projects. Auto-commits synced files in each project unless
# --no-commit is passed.
#
# Usage: ./projects-sync.sh [--dry-run] [--no-commit] [--only <path>]
#
# Projects are listed in projects.txt (one absolute path per line).
# Copy projects.example.txt to projects.txt and add your project paths.
#
# --only <path> syncs that one project directory instead and ignores
# projects.txt. The path must be an existing CAMP project (it has a memory/
# folder); it does not need to be registered.
#
# Exit status: 1 if any ERROR line was printed (a missing source file or project
# directory), otherwise 0. Errors do not stop the sync; the rest still runs.

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$TEMPLATE_DIR/projects.txt"
DRY_RUN=false
NO_COMMIT=false
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY_RUN=true ;;
    --no-commit) NO_COMMIT=true ;;
    --only)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "Error: --only requires a project path, e.g. --only ~/projects/my-project" >&2
        exit 1
      fi
      ONLY="$2"
      shift
      ;;
    --only=*)
      ONLY="${1#--only=}"
      if [ -z "$ONLY" ]; then
        echo "Error: --only requires a project path, e.g. --only=~/projects/my-project" >&2
        exit 1
      fi
      ;;
    *) echo "Error: unknown argument '$1'" >&2; exit 1 ;;
  esac
  shift
done

if [ -n "$ONLY" ]; then
  if [ ! -d "$ONLY" ]; then
    echo "Error: --only path is not a directory: $ONLY" >&2
    exit 1
  fi
  ONLY="$(cd "$ONLY" && pwd)"
  if [ ! -d "$ONLY/memory" ]; then
    echo "Error: $ONLY has no memory/ folder, so it is not a CAMP project." >&2
    echo "Use project-init.sh --existing to add CAMP to it first." >&2
    exit 1
  fi
  if [ "$ONLY" = "$TEMPLATE_DIR" ]; then
    echo "Error: --only points at the template itself ($TEMPLATE_DIR)." >&2
    exit 1
  fi
elif [ ! -f "$REGISTRY" ]; then
  echo "Error: projects.txt not found." >&2
  echo "Copy projects.example.txt to projects.txt and add your project paths." >&2
  exit 1
fi

SKILLS=(brief decide plan-writer wrap-up)
SYNCED=0
ERRORS=0
SYNC_TARGETS=()
CHANGED=0
VERSION_WARNINGS=0

# sync_file — copy src to dst. Appends dst to SYNC_TARGETS on write.
# Increments ERRORS (not SYNCED) if src is missing, and CHANGED if dst
# differs from src (or does not exist yet).
sync_file() {
  local src="$1" dst="$2"
  if [ ! -f "$src" ]; then
    echo "  ERROR: source missing: $src" >&2
    ERRORS=$((ERRORS + 1))
    return
  fi
  local differs=false
  if ! diff -q "$src" "$dst" &>/dev/null; then
    differs=true
    CHANGED=$((CHANGED + 1))
  fi
  if $DRY_RUN; then
    if $differs; then
      echo "  [dry-run] would update: $dst"
    fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  SYNC_TARGETS+=("$dst")
}

# camp_version — print the CAMP version (vX.Y.Z or vX.Y.Z-dev) from the first
# line of an AGENTS.md, or nothing if the file is missing or its header is in
# an older format such as "CAMP v1.2". Matches only from "CAMP v" on, so the
# characters before it do not matter.
camp_version() {
  [ -f "$1" ] || return 0
  head -n 1 "$1" | sed -nE 's/^# AGENTS\.md.* CAMP (v[0-9]+\.[0-9]+\.[0-9]+(-dev)?)( .*)?$/\1/p'
}

SOURCE_VERSION="$(camp_version "$TEMPLATE_DIR/AGENTS.md")"

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
  [[ -z "$PROJECT" || "$PROJECT" == \#* ]] && continue

  if [ ! -d "$PROJECT" ]; then
    echo "ERROR: project directory not found: $PROJECT" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "Syncing → $PROJECT"
  SYNC_TARGETS=()
  CHANGED=0
  ERRORS_BEFORE=$ERRORS
  PROJECT_VERSION="$(camp_version "$PROJECT/AGENTS.md")"

  # AGENTS.md is synced last (below), not here: see the version marker note.
  sync_file "$TEMPLATE_DIR/HOW-TO-USE.md" "$PROJECT/HOW-TO-USE.md"

  # Schemas and the brief template: the skills and AGENTS.md cite them, and
  # project-init.sh only copies them when absent, so without this an existing
  # project never receives schema changes.
  for tmpl in BRIEF-TEMPLATE CONTEXT-SCHEMA DECISIONS-SCHEMA SESSIONS-SCHEMA; do
    sync_file "$TEMPLATE_DIR/memory/$tmpl.md" "$PROJECT/memory/$tmpl.md"
  done

  # Memory ID check script, called by .github/workflows/memory-id-check.yml
  sync_file "$TEMPLATE_DIR/scripts/check-memory-ids.sh" \
            "$PROJECT/scripts/check-memory-ids.sh"
  sync_file "$TEMPLATE_DIR/scripts/check-template-update.sh" \
            "$PROJECT/scripts/check-template-update.sh"

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

  # Sync subagent-model-policy hook (Claude Code only — no Cursor equivalent)
  sync_file "$TEMPLATE_DIR/hooks/claude/subagent-model-policy-check.sh" \
            "$PROJECT/.claude/hooks/subagent-model-policy-check.sh"
  if ! $DRY_RUN && [ -f "$PROJECT/.claude/hooks/subagent-model-policy-check.sh" ]; then
    chmod +x "$PROJECT/.claude/hooks/subagent-model-policy-check.sh"
  fi

  # Sync memory-ID-collision CI check
  sync_file "$TEMPLATE_DIR/.github/workflows/memory-id-check.yml" \
            "$PROJECT/.github/workflows/memory-id-check.yml"

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

  patch_subagent_model_policy_hook() {
    local settings="$PROJECT/.claude/settings.json"
    [ -f "$settings" ] || return 0
    if $DRY_RUN; then
        if ! python3 - "$settings" <<'PY' 2>/dev/null; then
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
cmd = "bash .claude/hooks/subagent-model-policy-check.sh"
for group in data.get("hooks", {}).get("PreToolUse", []):
    for hook in group.get("hooks", []):
        if hook.get("command") == cmd:
            sys.exit(0)
sys.exit(1)
PY
        echo "  [dry-run] would patch: $settings (add PreToolUse subagent-model-policy-check)"
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
cmd = "bash .claude/hooks/subagent-model-policy-check.sh"

for group in pre:
    for hook in group.get("hooks", []):
        if hook.get("command") == cmd:
            sys.exit(0)

pre.append({
    "matcher": "Agent|Workflow",
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
      },
      {
        "matcher": "Agent|Workflow",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/subagent-model-policy-check.sh"
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
    patch_subagent_model_policy_hook
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

  # Version marker (DEC-011): AGENTS.md's first line records the CAMP version,
  # so it is written last, and only if every file above landed. Otherwise the
  # header would claim files this project never received.
  if [ "$ERRORS" -gt "$ERRORS_BEFORE" ]; then
    echo "  AGENTS.md left as-is: $((ERRORS - ERRORS_BEFORE)) error(s) above, so its version line would claim files that did not land." >&2
  else
    sync_file "$TEMPLATE_DIR/AGENTS.md" "$PROJECT/AGENTS.md"
  fi

  # Files changed but the version did not: the template's AGENTS.md needs a
  # version bump. Warns only. A -dev source changes all the time, so it never
  # warns.
  if [ "$CHANGED" -gt 0 ] && [ -n "$SOURCE_VERSION" ] \
     && [ "$PROJECT_VERSION" = "$SOURCE_VERSION" ] \
     && [[ "$SOURCE_VERSION" != *-dev ]]; then
    echo "  WARNING: $CHANGED file(s) differ but the CAMP version is still $SOURCE_VERSION. Bump the version in the template's AGENTS.md before syncing." >&2
    VERSION_WARNINGS=$((VERSION_WARNINGS + 1))
  fi

  # Refresh .camp-version's synced_commit/synced_at to this template's
  # current HEAD. last_checked_at is preserved as-is (or set to today if
  # the file didn't exist yet) — it tracks AGENTS.md's own weekly check
  # cadence and isn't reset just because a sync happened. This file is
  # local/gitignored (see project-init.sh) — never added to SYNC_TARGETS,
  # never staged or committed.
  TEMPLATE_REMOTE="$(git -C "$TEMPLATE_DIR" remote get-url origin 2>/dev/null || true)"
  TEMPLATE_COMMIT="$(git -C "$TEMPLATE_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  TODAY="$(date +%Y-%m-%d)"
  CAMP_VERSION_FILE="$PROJECT/.camp-version"
  KNOWN_REMOTE=""
  KNOWN_BRANCH="main"
  if [ -f "$CAMP_VERSION_FILE" ]; then
    LAST_CHECKED="$(grep '^last_checked_at:' "$CAMP_VERSION_FILE" | sed 's/^last_checked_at: *//')"
    KNOWN_REMOTE="$(grep '^template_repo:' "$CAMP_VERSION_FILE" | sed 's/^template_repo: *//' || true)"
    KNOWN_BRANCH="$(grep '^template_branch:' "$CAMP_VERSION_FILE" | sed 's/^template_branch: *//' || true)"
    KNOWN_BRANCH="${KNOWN_BRANCH:-main}"
  fi
  # The template clone's checked-out branch is the channel. If it cannot be
  # read (not git, or detached HEAD), keep the known one rather than guess.
  TEMPLATE_BRANCH="$(git -C "$TEMPLATE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ -z "$TEMPLATE_BRANCH" ] || [ "$TEMPLATE_BRANCH" = "HEAD" ]; then
    TEMPLATE_BRANCH="$KNOWN_BRANCH"
  fi
  LAST_CHECKED="${LAST_CHECKED:-$TODAY}"
  NEW_CAMP_VERSION="template_repo: $TEMPLATE_REMOTE
template_branch: $TEMPLATE_BRANCH
synced_commit: $TEMPLATE_COMMIT
synced_at: $TODAY
last_checked_at: $LAST_CHECKED"
  # Only record this source when it is the template the project already
  # tracks. A sync from another clone (such as camp-dev) would write a commit
  # that is never on the template's main, and AGENTS.md step 7 would then
  # report "behind the template" forever.
  if [ -f "$CAMP_VERSION_FILE" ] && [ "$KNOWN_REMOTE" != "$TEMPLATE_REMOTE" ]; then
    echo "  .camp-version left as-is: this source's origin ($TEMPLATE_REMOTE) is not the project's template_repo ($KNOWN_REMOTE)."
  elif $DRY_RUN; then
    if [ -f "$CAMP_VERSION_FILE" ] && [ "$TEMPLATE_BRANCH" != "$KNOWN_BRANCH" ]; then
      echo "  [dry-run] would switch CAMP channel from $KNOWN_BRANCH to $TEMPLATE_BRANCH."
    fi
    if [ ! -f "$CAMP_VERSION_FILE" ] || [ "$(cat "$CAMP_VERSION_FILE")" != "$NEW_CAMP_VERSION" ]; then
      echo "  [dry-run] would update: $CAMP_VERSION_FILE"
    fi
  else
    if [ -f "$CAMP_VERSION_FILE" ] && [ "$TEMPLATE_BRANCH" != "$KNOWN_BRANCH" ]; then
      echo "  CAMP channel switched from $KNOWN_BRANCH to $TEMPLATE_BRANCH."
    fi
    printf '%s\n' "$NEW_CAMP_VERSION" > "$CAMP_VERSION_FILE"
  fi
  unset LAST_CHECKED KNOWN_REMOTE KNOWN_BRANCH TEMPLATE_BRANCH

  # Ensure the plan-reminder hook's dedupe-marker dirs are gitignored.
  # Append-only, like project-init.sh's gitignore step — never overwrite.
  GITIGNORE_LINES=(".camp-version" ".claude/.reminders/")
  if [ -d "$PROJECT/.cursor" ]; then
    GITIGNORE_LINES+=(".cursor/.reminders/")
  fi
  if $DRY_RUN; then
    for line in "${GITIGNORE_LINES[@]}"; do
      if [ ! -f "$PROJECT/.gitignore" ] || ! grep -qxF "$line" "$PROJECT/.gitignore" 2>/dev/null; then
        echo "  [dry-run] would add to .gitignore: $line"
      fi
    done
  else
    GITIGNORE_CHANGED=false
    for line in "${GITIGNORE_LINES[@]}"; do
      if [ ! -f "$PROJECT/.gitignore" ] || ! grep -qxF "$line" "$PROJECT/.gitignore" 2>/dev/null; then
        echo "$line" >> "$PROJECT/.gitignore"
        GITIGNORE_CHANGED=true
      fi
    done
    if $GITIGNORE_CHANGED; then
      SYNC_TARGETS+=("$PROJECT/.gitignore")
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
done < <(if [ -n "$ONLY" ]; then printf '%s\n' "$ONLY"; else cat "$REGISTRY"; fi)

echo ""
if $DRY_RUN; then
  echo "Dry run complete — $SYNCED project(s) checked, $ERRORS error(s)."
else
  echo "Sync complete — $SYNCED project(s) updated, $ERRORS error(s)."
fi
if [ "$VERSION_WARNINGS" -gt 0 ]; then
  echo "$VERSION_WARNINGS project(s) received changed files without a CAMP version change (see warnings above)."
fi

# Errors do not stop the sync (other files and projects still go ahead), but
# the exit code tells a caller that something did not land.
[ "$ERRORS" -eq 0 ] || exit 1
