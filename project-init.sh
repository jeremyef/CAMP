#!/usr/bin/env bash
set -euo pipefail

# project-init.sh — scaffold a new CAMP project.
# CAMP: Context And Memory Protocol
#
# Usage:
#   TEMPLATE_DIR=/path/to/your/templates ./project-init.sh <project-name> [--remote=<url>] [--cursor]
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
REMOTE_URL=""
POSITIONAL_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --cursor) CURSOR=true ;;
    --remote=*) REMOTE_URL="${arg#--remote=}" ;;
    --remote) echo "Error: --remote requires a value, e.g. --remote=https://github.com/user/repo.git" >&2; exit 1 ;;
    --*) echo "Error: unknown flag '$arg'" >&2; exit 1 ;;
    *) POSITIONAL_ARGS+=("$arg") ;;
  esac
done

if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
  echo "Usage: project-init.sh <project-name> [--remote=<url>] [--cursor]" >&2
  exit 1
fi

PROJECT_NAME="${POSITIONAL_ARGS[0]}"
TEMPLATE_DIR="${TEMPLATE_DIR:?Set TEMPLATE_DIR to your canonical template files location}"

# Prevent path traversal (e.g. ../../escape)
if [[ "$PROJECT_NAME" == */* ]] || [[ "$PROJECT_NAME" == *\\* ]]; then
  echo "Error: project name must not contain path separators." >&2
  exit 1
fi

if [ -d "$PROJECT_NAME" ]; then
  echo "Error: directory '$PROJECT_NAME' already exists. Aborting." >&2
  exit 1
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

cleanup() {
  echo "Error: setup failed. Removing partially-created directory '$PROJECT_NAME'." >&2
  cd ..
  rm -rf "$PROJECT_NAME"
}
trap cleanup ERR

mkdir -p "$PROJECT_NAME"/memory/DECISIONS-ARCHIVE
mkdir -p "$PROJECT_NAME"/memory/SESSIONS-ARCHIVE
for skill in brief decide wrap-up plan-writer; do
  mkdir -p "$PROJECT_NAME"/.claude/skills/$skill
  mkdir -p "$PROJECT_NAME"/.cursor/skills/$skill
done
mkdir -p "$PROJECT_NAME"/.claude/hooks
mkdir -p "$PROJECT_NAME"/.cursor/hooks
mkdir -p "$PROJECT_NAME"/.github/workflows
cd "$PROJECT_NAME"

# ── Copy canonical template files ─────────────────────────────────────────

cp "$TEMPLATE_DIR/AGENTS.md"                  ./AGENTS.md
cp "$TEMPLATE_DIR/HOW-TO-USE.md"              ./HOW-TO-USE.md
cp "$TEMPLATE_DIR/memory/BRIEF-TEMPLATE.md"   ./memory/BRIEF-TEMPLATE.md
cp "$TEMPLATE_DIR/memory/CONTEXT-SCHEMA.md"   ./memory/CONTEXT-SCHEMA.md
cp "$TEMPLATE_DIR/memory/DECISIONS-SCHEMA.md" ./memory/DECISIONS-SCHEMA.md
cp "$TEMPLATE_DIR/memory/SESSIONS-SCHEMA.md"  ./memory/SESSIONS-SCHEMA.md

for skill in brief decide wrap-up plan-writer; do
  cp "$TEMPLATE_DIR/skills/$skill/SKILL.md" "./.claude/skills/$skill/SKILL.md"
  cp "$TEMPLATE_DIR/skills/$skill/SKILL.md" "./.cursor/skills/$skill/SKILL.md"
done

for hook in plan-reminder plan-completion-check plan-immutability-check; do
  cp "$TEMPLATE_DIR/skills/plan-writer/hooks/claude/$hook.sh" "./.claude/hooks/$hook.sh"
  chmod +x "./.claude/hooks/$hook.sh"
  cp "$TEMPLATE_DIR/skills/plan-writer/hooks/cursor/$hook.sh" "./.cursor/hooks/$hook.sh"
  chmod +x "./.cursor/hooks/$hook.sh"
done

# Claude-Code-only — no Cursor equivalent (policy targets Agent/Workflow
# tool calls, which are Claude Code constructs).
cp "$TEMPLATE_DIR/hooks/claude/subagent-model-policy-check.sh" "./.claude/hooks/subagent-model-policy-check.sh"
chmod +x "./.claude/hooks/subagent-model-policy-check.sh"

# CI check — inert until a remote + PR workflow exist; harmless either way.
cp "$TEMPLATE_DIR/.github/workflows/memory-id-check.yml" "./.github/workflows/memory-id-check.yml"

# ── Hook registration ──────────────────────────────────────────────────────

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

# Symlink — guard against re-run collision
if [ ! -L CLAUDE.md ]; then
  ln -s AGENTS.md CLAUDE.md
fi

# ── Stub files — content is written by skills, not this script ────────────
# One-line comment in each file points to its schema so they're not blank.

echo "# See memory/BRIEF-TEMPLATE.md — content written by \`brief\` skill" \
  > memory/BRIEF.md
echo "# See memory/CONTEXT-SCHEMA.md — content written by \`wrap-up\` skill" \
  > memory/CONTEXT.md
echo "# See memory/DECISIONS-SCHEMA.md — content written by \`decide\` skill" \
  > memory/DECISIONS.md
echo "# See memory/SESSIONS-SCHEMA.md — content written by \`wrap-up\` skill" \
  > memory/SESSIONS.md

# ── Gitignore ─────────────────────────────────────────────────────────────

cat > .gitignore << 'GITIGNORE'
# Local attribution preference — not project policy
.claude/settings.local.json
GITIGNORE

if [ "$CURSOR" = true ]; then
  cat >> .gitignore << 'GITIGNORE'

# Cursor local settings — not project policy
.cursor/settings.json
.cursor/cli-config.json
GITIGNORE
fi

# ── Attribution setting ────────────────────────────────────────────────────
# Claude Code appends "Generated with Claude Code" and a Co-Authored-By
# trailer to every commit by default. This file lets you control that.
# It is NOT committed to git (personal preference, not project policy).
# To disable attribution entirely, leave both values as empty strings "".
# To keep it, delete this file or set values to your preferred text.

cat > .claude/settings.local.json << 'JSON'
{
  "attribution": {
    "commit": "",
    "pr": ""
  }
}
JSON

if [ "$CURSOR" = true ]; then
  cat > .cursor/cli-config.json << 'JSON'
{
  "attribution": {
    "attributeCommitsToAgent": false,
    "attributePRsToAgent": false
  }
}
JSON
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

# Initial commit — per AGENTS.md git integration section.
# Note: .claude/settings.local.json is intentionally excluded (listed in .gitignore).
git add AGENTS.md CLAUDE.md HOW-TO-USE.md .gitignore memory/ .claude/skills/ .cursor/skills/ .claude/hooks/ .cursor/hooks/ .claude/settings.json .cursor/hooks.json .github/workflows/
git commit -m "chore(memory): initial scaffold"

# Disable the cleanup trap now that setup succeeded
trap - ERR

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
  git remote add origin "$REMOTE_URL"
fi

# ── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "CAMP project '$PROJECT_NAME' scaffolded successfully."
echo ""
echo "Attribution: .claude/settings.local.json sets attribution to disabled."
echo "Edit or delete this file to change that preference (not committed to git)."
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
if [ "$CURSOR" = true ]; then
  echo "Cursor:      Attribution config written to .cursor/cli-config.json."
  echo ""
fi
if [ -n "$REMOTE_URL" ]; then
  echo "Remote: origin → $REMOTE_URL"
  echo ""
fi
echo "Next: open the project in Claude Code or Cursor and run /brief."