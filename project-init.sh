#!/usr/bin/env bash
set -euo pipefail

# project-init.sh — scaffold a new CAMP project, or add CAMP to an existing one.
# CAMP: Context And Memory Protocol
#
# Usage:
#   TEMPLATE_DIR=/path/to/your/templates ./project-init.sh <project-name> [--remote=<url>] [--cursor]
#   TEMPLATE_DIR=/path/to/your/templates ./project-init.sh --existing <path-to-existing-project> [--remote=<url>] [--cursor]
#
# --existing scaffolds CAMP into a directory that already exists (and likely
# already has its own files, git history, and settings). It never overwrites
# anything it didn't create: any file that already exists at a destination
# path is left untouched and reported as skipped. Files that need merging
# rather than a straight copy (CLAUDE.md, .gitignore, .claude/settings.json,
# .cursor/hooks.json) are merged in place instead of being skipped outright.
#
# TEMPLATE_DIR must contain:
#   AGENTS.md, HOW-TO-USE.md, BRIEF-TEMPLATE.md, CONTEXT-SCHEMA.md,
#   DECISIONS-SCHEMA.md, SESSIONS-SCHEMA.md,
#   skills/brief/SKILL.md, skills/decide/SKILL.md,
#   skills/wrap-up/SKILL.md, skills/plan-writer/SKILL.md
#
# This script is deterministic — it copies from one canonical source so
# templates never drift out of sync between projects. No inference happens
# here; content is written by the skills, not this script.

# ── Guards ────────────────────────────────────────────────────────────────

CURSOR=false
EXISTING=false
REMOTE_URL=""
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --cursor) CURSOR=true ;;
    --existing) EXISTING=true ;;
    --remote=*) REMOTE_URL="${arg#--remote=}" ;;
    --remote) echo "Error: --remote requires a value, e.g. --remote=https://github.com/user/repo.git" >&2; exit 1 ;;
    --*) echo "Error: unknown flag '$arg'" >&2; exit 1 ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
  echo "Usage: project-init.sh <project-name> [--remote=<url>] [--cursor]" >&2
  echo "       project-init.sh --existing <path-to-existing-project> [--remote=<url>] [--cursor]" >&2
  exit 1
fi

PROJECT_NAME="${POSITIONAL_ARGS[0]}"
TEMPLATE_DIR="${TEMPLATE_DIR:?Set TEMPLATE_DIR to your canonical template files location}"

if $EXISTING; then
  if [ ! -d "$PROJECT_NAME" ]; then
    echo "Error: directory '$PROJECT_NAME' does not exist." >&2
    echo "--existing requires a path to a project directory that already exists." >&2
    exit 1
  fi
else
  # Prevent path traversal (e.g. ../../escape)
  if [[ "$PROJECT_NAME" == */* ]] || [[ "$PROJECT_NAME" == *\\* ]]; then
    echo "Error: project name must not contain path separators." >&2
    exit 1
  fi

  if [ -d "$PROJECT_NAME" ]; then
    echo "Error: directory '$PROJECT_NAME' already exists. Aborting." >&2
    echo "Use --existing $PROJECT_NAME to add CAMP to it instead." >&2
    exit 1
  fi
fi

# Require git before doing anything
if ! command -v git &>/dev/null; then
  echo "Error: git is not installed or not in PATH." >&2
  exit 1
fi

# Verify the remote is reachable before touching the filesystem
if [ -n "$REMOTE_URL" ]; then
  if ! GIT_TERMINAL_PROMPT=0 git ls-remote "$REMOTE_URL" HEAD &>/dev/null 2>&1; then
    echo "Error: remote '$REMOTE_URL' is not reachable." >&2
    echo "Verify the URL and your git credentials, then re-run." >&2
    exit 1
  fi
fi

# Preflight — verify all required template files exist before touching
# the filesystem
REQUIRED_TEMPLATES=(
  "AGENTS.md"
  "HOW-TO-USE.md"
  "memory/BRIEF-TEMPLATE.md"
  "memory/CONTEXT-SCHEMA.md"
  "memory/DECISIONS-SCHEMA.md"
  "memory/SESSIONS-SCHEMA.md"
  "skills/brief/SKILL.md"
  "skills/decide/SKILL.md"
  "skills/wrap-up/SKILL.md"
  "skills/plan-writer/SKILL.md"
  "skills/plan-writer/hooks/claude/plan-reminder.sh"
  "skills/plan-writer/hooks/claude/plan-completion-check.sh"
  "skills/plan-writer/hooks/claude/plan-immutability-check.sh"
  "skills/plan-writer/hooks/cursor/plan-reminder.sh"
  "skills/plan-writer/hooks/cursor/plan-completion-check.sh"
  "skills/plan-writer/hooks/cursor/plan-immutability-check.sh"
  "hooks/claude/subagent-model-policy-check.sh"
  ".github/workflows/memory-id-check.yml"
)

MISSING=()
for f in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "$TEMPLATE_DIR/$f" ]; then
    MISSING+=("$f")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Error: the following template files are missing from $TEMPLATE_DIR:" >&2
  for f in "${MISSING[@]}"; do
    echo "  - $f" >&2
  done
  exit 1
fi

# ── Setup — clean up on any failure after directory creation ──────────────
# Only applies when we created the directory ourselves; never rm -rf a
# pre-existing project directory on failure.

if ! $EXISTING; then
  cleanup() {
    echo "Error: setup failed. Removing partially-created directory '$PROJECT_NAME'." >&2
    cd ..
    rm -rf "$PROJECT_NAME"
  }
  trap cleanup ERR
fi

mkdir -p "$PROJECT_NAME"/memory/DECISIONS-ARCHIVE
mkdir -p "$PROJECT_NAME"/memory/SESSIONS-ARCHIVE
cd "$PROJECT_NAME"

# Cursor support: in --existing mode, only touch .cursor/ if the project
# already has one, or the user explicitly asked for it via --cursor. In
# fresh-scaffold mode, behavior is unchanged — always scaffold Cursor too.
if $EXISTING; then
  if [ -d .cursor ] || [ "$CURSOR" = true ]; then
    DO_CURSOR=true
  else
    DO_CURSOR=false
  fi
else
  DO_CURSOR=true
fi

# ── Collision-safe write helpers ────────────────────────────────────────
# TOUCHED tracks every path this run actually wrote (used for staging).
# SKIPPED tracks paths that already existed and were left untouched.
# In fresh-scaffold mode neither destination ever pre-exists, so these
# behave exactly like an unconditional copy/write.

TOUCHED=()
SKIPPED=()
PATCHED=()

copy_if_absent() {
  local src="$1" dst="${2#./}"
  if [ -e "$dst" ]; then
    SKIPPED+=("$dst")
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  TOUCHED+=("$dst")
}

write_if_absent() {
  local dst="${1#./}" content="$2"
  if [ -e "$dst" ]; then
    SKIPPED+=("$dst")
    return
  fi
  mkdir -p "$(dirname "$dst")"
  printf '%s\n' "$content" > "$dst"
  TOUCHED+=("$dst")
}

# Same as write_if_absent, but for local/gitignored preference files that
# should never be staged or committed.
write_if_absent_local() {
  local dst="$1" content="$2"
  if [ -e "$dst" ]; then
    SKIPPED+=("$dst")
    return
  fi
  mkdir -p "$(dirname "$dst")"
  printf '%s\n' "$content" > "$dst"
}

# ── Copy canonical template files ─────────────────────────────────────────

copy_if_absent "$TEMPLATE_DIR/AGENTS.md"                  ./AGENTS.md
copy_if_absent "$TEMPLATE_DIR/HOW-TO-USE.md"              ./HOW-TO-USE.md
copy_if_absent "$TEMPLATE_DIR/memory/BRIEF-TEMPLATE.md"   ./memory/BRIEF-TEMPLATE.md
copy_if_absent "$TEMPLATE_DIR/memory/CONTEXT-SCHEMA.md"   ./memory/CONTEXT-SCHEMA.md
copy_if_absent "$TEMPLATE_DIR/memory/DECISIONS-SCHEMA.md" ./memory/DECISIONS-SCHEMA.md
copy_if_absent "$TEMPLATE_DIR/memory/SESSIONS-SCHEMA.md"  ./memory/SESSIONS-SCHEMA.md

for skill in brief decide wrap-up plan-writer; do
  copy_if_absent "$TEMPLATE_DIR/skills/$skill/SKILL.md" "./.claude/skills/$skill/SKILL.md"
  if $DO_CURSOR; then
    copy_if_absent "$TEMPLATE_DIR/skills/$skill/SKILL.md" "./.cursor/skills/$skill/SKILL.md"
  fi
done

for hook in plan-reminder plan-completion-check plan-immutability-check; do
  copy_if_absent "$TEMPLATE_DIR/skills/plan-writer/hooks/claude/$hook.sh" "./.claude/hooks/$hook.sh"
  chmod +x "./.claude/hooks/$hook.sh"
  if $DO_CURSOR; then
    copy_if_absent "$TEMPLATE_DIR/skills/plan-writer/hooks/cursor/$hook.sh" "./.cursor/hooks/$hook.sh"
    chmod +x "./.cursor/hooks/$hook.sh"
  fi
done

# Claude-Code-only — no Cursor equivalent (policy targets Agent/Workflow
# tool calls, which are Claude Code constructs).
copy_if_absent "$TEMPLATE_DIR/hooks/claude/subagent-model-policy-check.sh" "./.claude/hooks/subagent-model-policy-check.sh"
chmod +x "./.claude/hooks/subagent-model-policy-check.sh"

# CI check — inert until a remote + PR workflow exist; harmless either way.
copy_if_absent "$TEMPLATE_DIR/.github/workflows/memory-id-check.yml" "./.github/workflows/memory-id-check.yml"

# ── Hook registration ──────────────────────────────────────────────────────
# If settings.json / hooks.json don't exist yet, write them fresh (as
# before). If they already exist — the common case for --existing — patch
# in only the hook entries that are missing, leaving everything else in the
# file alone.

patch_claude_settings_hook() {
  local event="$1" matcher="$2" cmd="$3" mode="$4"
  python3 - .claude/settings.json "$event" "$matcher" "$cmd" "$mode" <<'PY'
import json, sys

path, event, matcher, cmd, mode = sys.argv[1:6]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
arr = hooks.setdefault(event, [])

found = any(
    h.get("command") == cmd
    for group in arr
    for h in group.get("hooks", [])
)
if not found:
    entry = {"hooks": [{"type": "command", "command": cmd}]}
    if matcher:
        entry["matcher"] = matcher
    if mode == "prepend":
        arr.insert(0, entry)
    else:
        arr.append(entry)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
}

if [ ! -f .claude/settings.json ]; then
  cat > .claude/settings.json << 'JSON'
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
  TOUCHED+=(".claude/settings.json")
else
  patch_claude_settings_hook "PreToolUse"  "Edit|Write|MultiEdit" "bash .claude/hooks/plan-immutability-check.sh"     prepend
  patch_claude_settings_hook "PreToolUse"  "Agent|Workflow"       "bash .claude/hooks/subagent-model-policy-check.sh" append
  patch_claude_settings_hook "PostToolUse" "Edit|Write|MultiEdit" "bash .claude/hooks/plan-reminder.sh"               append
  patch_claude_settings_hook "Stop"        ""                     "bash .claude/hooks/plan-completion-check.sh"       append
  TOUCHED+=(".claude/settings.json")
  PATCHED+=(".claude/settings.json")
fi

if $DO_CURSOR; then
  patch_cursor_hooks() {
    local event="$1" matcher="$2" cmd="$3" mode="$4"
    python3 - .cursor/hooks.json "$event" "$matcher" "$cmd" "$mode" <<'PY'
import json, sys

path, event, matcher, cmd, mode = sys.argv[1:6]
with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
arr = hooks.setdefault(event, [])

found = any(h.get("command") == cmd for h in arr)
if not found:
    entry = {"command": cmd}
    if matcher:
        entry["matcher"] = matcher
    if event == "stop":
        entry["loop_limit"] = None
    if mode == "prepend":
        arr.insert(0, entry)
    else:
        arr.append(entry)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY
  }

  if [ ! -f .cursor/hooks.json ]; then
    cat > .cursor/hooks.json << 'JSON'
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
    TOUCHED+=(".cursor/hooks.json")
  else
    patch_cursor_hooks "preToolUse"  "Write|StrReplace|Delete" ".cursor/hooks/plan-immutability-check.sh" prepend
    patch_cursor_hooks "postToolUse" "Write|StrReplace"        ".cursor/hooks/plan-reminder.sh"           append
    patch_cursor_hooks "stop"        ""                        ".cursor/hooks/plan-completion-check.sh"  append
    TOUCHED+=(".cursor/hooks.json")
    PATCHED+=(".cursor/hooks.json")
  fi
fi

# ── CLAUDE.md ────────────────────────────────────────────────────────────
# Highest-risk collision: an existing project almost always already has one.
# Never overwrite real content — only symlink when nothing is there yet.

CLAUDE_WARN=false
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = "AGENTS.md" ]; then
  : # already correctly symlinked — idempotent re-run, nothing to do
elif [ -e CLAUDE.md ]; then
  SKIPPED+=("CLAUDE.md")
  CLAUDE_WARN=true
else
  ln -s AGENTS.md CLAUDE.md
  TOUCHED+=("CLAUDE.md")
fi

# ── Stub files — content is written by skills, not this script ────────────
# One-line comment in each file points to its schema so they're not blank.
# Never overwrites real memory content if it's already there.

write_if_absent memory/BRIEF.md     "# See memory/BRIEF-TEMPLATE.md — content written by \`brief\` skill"
write_if_absent memory/CONTEXT.md   "# See memory/CONTEXT-SCHEMA.md — content written by \`wrap-up\` skill"
write_if_absent memory/DECISIONS.md "# See memory/DECISIONS-SCHEMA.md — content written by \`decide\` skill"
write_if_absent memory/SESSIONS.md  "# See memory/SESSIONS-SCHEMA.md — content written by \`wrap-up\` skill"

# ── CAMP version tracking ──────────────────────────────────────────────────
# Records which template commit this project was last synced from, so
# AGENTS.md's session-start check can tell if the template has moved on.
# template_repo is left blank if TEMPLATE_DIR has no origin remote (e.g. a
# local-only template) — AGENTS.md's check skips silently when it's blank.
# Local/gitignored like settings.local.json: last_checked_at updates weekly
# as a side effect of that check, and committing that churn on a schedule
# unrelated to any real project change would make it a permanent source of
# "uncommitted files" noise in wrap-up's dirty-file check.

TEMPLATE_REMOTE="$(cd "$TEMPLATE_DIR" && git remote get-url origin 2>/dev/null || true)"
TEMPLATE_COMMIT="$(cd "$TEMPLATE_DIR" && git rev-parse --short HEAD 2>/dev/null || true)"
TODAY="$(date +%Y-%m-%d)"

write_if_absent_local .camp-version "template_repo: $TEMPLATE_REMOTE
synced_commit: $TEMPLATE_COMMIT
synced_at: $TODAY
last_checked_at: $TODAY"

# ── Gitignore ─────────────────────────────────────────────────────────────
# If absent, create it as before. If present, append only the lines that
# are actually missing, rather than overwriting the file.

if [ ! -f .gitignore ]; then
  cat > .gitignore << 'GITIGNORE'
# Local attribution preference — not project policy
.claude/settings.local.json

# Local CAMP template-sync tracking — not project policy
.camp-version

# plan-reminder hook's per-session dedupe markers — not project state
.claude/.reminders/
GITIGNORE

  if [ "$CURSOR" = true ]; then
    cat >> .gitignore << 'GITIGNORE'

# Cursor local settings — not project policy
.cursor/settings.json
.cursor/cli-config.json

# plan-reminder hook's per-session dedupe markers — not project state
.cursor/.reminders/
GITIGNORE
  fi
  TOUCHED+=(".gitignore")
else
  GITIGNORE_LINES=(".claude/settings.local.json" ".camp-version" ".claude/.reminders/")
  if [ "$CURSOR" = true ]; then
    GITIGNORE_LINES+=(".cursor/settings.json" ".cursor/cli-config.json" ".cursor/.reminders/")
  fi
  GITIGNORE_CHANGED=false
  for line in "${GITIGNORE_LINES[@]}"; do
    if ! grep -qxF "$line" .gitignore; then
      echo "$line" >> .gitignore
      GITIGNORE_CHANGED=true
    fi
  done
  if $GITIGNORE_CHANGED; then
    TOUCHED+=(".gitignore")
  else
    SKIPPED+=(".gitignore (already covers CAMP's local files)")
  fi
fi

# ── Attribution setting ────────────────────────────────────────────────────
# Claude Code appends "Generated with Claude Code" and a Co-Authored-By
# trailer to every commit by default. This file lets you control that.
# It is NOT committed to git (personal preference, not project policy).
# To disable attribution entirely, leave both values as empty strings "".
# To keep it, delete this file or set values to your preferred text.
# Never overwritten if the project already has a local preference set.

write_if_absent_local .claude/settings.local.json '{
  "attribution": {
    "commit": "",
    "pr": ""
  }
}'

if $DO_CURSOR && [ "$CURSOR" = true ]; then
  write_if_absent_local .cursor/cli-config.json '{
  "attribution": {
    "attributeCommitsToAgent": false,
    "attributePRsToAgent": false
  }
}'
fi

# ── Git setup ──────────────────────────────────────────────────────────────

if [ ! -d .git ]; then
  git init
fi

# Guard against memory/ being silently swallowed by an existing .gitignore
IGNORED=()
for f in memory/BRIEF.md memory/CONTEXT.md memory/DECISIONS.md memory/SESSIONS.md; do
  if git check-ignore -q "$f" 2>/dev/null; then
    IGNORED+=("$f")
  fi
done

if [ ${#IGNORED[@]} -gt 0 ]; then
  echo "Error: the following memory files are being ignored by a .gitignore rule:" >&2
  for f in "${IGNORED[@]}"; do
    echo "  - $f" >&2
  done
  echo "Fix this before continuing — the memory system requires these files" >&2
  echo "to be trackable by git." >&2
  exit 1
fi

# In --existing mode, warn about (but don't block on) unrelated uncommitted
# work already sitting in the project — the commit below stages only the
# CAMP paths this run touched, never a blanket `git add`.
if $EXISTING; then
  OTHER_DIRTY=()
  while IFS= read -r line; do
    f="${line:3}"
    is_touched=false
    for t in "${TOUCHED[@]}"; do
      if [ "$f" = "$t" ]; then
        is_touched=true
        break
      fi
    done
    $is_touched || OTHER_DIRTY+=("$f")
  done < <(git status --porcelain --untracked-files=all 2>/dev/null || true)

  if [ ${#OTHER_DIRTY[@]} -gt 0 ]; then
    echo "Warning: these files have uncommitted changes unrelated to the CAMP scaffold:" >&2
    for f in "${OTHER_DIRTY[@]}"; do
      echo "  - $f" >&2
    done
    echo "They will not be touched or included in the scaffold commit below." >&2
  fi
fi

# Initial commit — per AGENTS.md git integration section. Stages only the
# paths this run actually wrote (never `git add .`/`-A`).
# Note: .claude/settings.local.json and .cursor/cli-config.json are
# intentionally excluded — they're local preference files, not staged.
if [ ${#TOUCHED[@]} -gt 0 ]; then
  git add "${TOUCHED[@]}"
fi

if ! git diff --cached --quiet 2>/dev/null; then
  if $EXISTING; then
    git commit -m "chore(memory): add CAMP scaffold to existing project"
  else
    git commit -m "chore(memory): initial scaffold"
  fi
else
  echo "Nothing new to stage — CAMP scaffold already present, no commit made."
fi

# Disable the cleanup trap now that setup succeeded
if ! $EXISTING; then
  trap - ERR
fi

# ── Register project in template registry ─────────────────────────────────

REGISTRY="$TEMPLATE_DIR/projects.txt"
PROJECT_ABS="$(pwd)"
if [ -f "$REGISTRY" ]; then
  if ! grep -qxF "$PROJECT_ABS" "$REGISTRY"; then
    echo "$PROJECT_ABS" >> "$REGISTRY"
    echo "Registered in $(basename "$TEMPLATE_DIR")/projects.txt"
  fi
else
  echo "$PROJECT_ABS" > "$REGISTRY"
  echo "Created $(basename "$TEMPLATE_DIR")/projects.txt and registered project."
fi

# ── Remote ─────────────────────────────────────────────────────────────────

if [ -n "$REMOTE_URL" ]; then
  if git remote get-url origin &>/dev/null; then
    echo "Note: remote 'origin' already set to $(git remote get-url origin) — leaving unchanged."
  else
    git remote add origin "$REMOTE_URL"
  fi
fi

# ── Done ───────────────────────────────────────────────────────────────────

echo ""
if $EXISTING; then
  echo "CAMP scaffolded into existing project '$PROJECT_NAME' successfully."
else
  echo "CAMP project '$PROJECT_NAME' scaffolded successfully."
fi
echo ""

if [ ${#SKIPPED[@]} -gt 0 ]; then
  echo "Skipped (already present, left untouched):"
  for f in "${SKIPPED[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

if [ ${#PATCHED[@]} -gt 0 ]; then
  echo "Patched (already existed — missing hook entries merged in, rest left as-is):"
  for f in "${PATCHED[@]}"; do
    echo "  - $f"
  done
  echo ""
fi

if $CLAUDE_WARN; then
  echo "CLAUDE.md already exists and was left untouched — CAMP's protocol lives"
  echo "in AGENTS.md instead. Add a reference to AGENTS.md from your existing"
  echo "CLAUDE.md manually if you want it loaded automatically."
  echo ""
fi

echo "Attribution: .claude/settings.local.json sets attribution to disabled"
echo "(unless one already existed, in which case it was left as-is)."
echo "Edit or delete this file to change that preference (not committed to git)."
echo ""
echo "Version tracking: .camp-version records the template commit this project"
echo "was scaffolded from (not committed to git). AGENTS.md checks it weekly and"
echo "prints a quiet note if the template has since moved on — never blocking."
echo ""
echo "Hooks:       .claude/hooks/ and .cursor/hooks/ scaffolded with plan-writer enforcement hooks."
echo "             .claude/hooks/ also has subagent-model-policy-check.sh (Claude Code only)"
echo "             enforcing CLAUDE.md's subagent-model-policy on Agent/Workflow calls."
echo "             Registered in .claude/settings.json and .cursor/hooks.json."
echo ""
echo "CI:          .github/workflows/memory-id-check.yml scaffolded — flags duplicate"
echo "             DEC-/SESS- IDs on PRs touching memory/. Inert until you push a remote."
echo ""
echo "Optional: to enforce PR-only merges once you've pushed a remote (blocks direct"
echo "  pushes to main, requires the memory ID check above to pass before merging):"
echo "  gh api repos/{owner}/{repo}/branches/main/protection -X PUT \\"
echo "    -f required_status_checks[strict]=true \\"
echo "    -f 'required_status_checks[contexts][]=check-duplicate-ids' \\"
echo "    -f enforce_admins=true \\"
echo "    -f 'required_pull_request_reviews[required_approving_review_count]=0' \\"
echo "    -f restrictions=null"
echo ""
if $DO_CURSOR; then
  echo "Cursor:      .cursor/ scaffolded/patched alongside .claude/."
  echo ""
fi
if [ -n "$REMOTE_URL" ]; then
  echo "Remote: origin → $REMOTE_URL"
  echo ""
fi
echo "Next: open the project in Claude Code or Cursor and run /brief."
