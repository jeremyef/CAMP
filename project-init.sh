#!/usr/bin/env bash
set -euo pipefail

# project-init.sh — scaffold a new CAMP project.
# CAMP: Context And Memory Protocol
#
# Usage:
#   TEMPLATE_DIR=/path/to/your/templates ./project-init.sh <project-name>
#
# TEMPLATE_DIR must contain:
#   AGENTS.md, HOW-TO-USE.md, BRIEF-TEMPLATE.md, CONTEXT-SCHEMA.md,
#   DECISIONS-SCHEMA.md, SESSIONS-SCHEMA.md,
#   .claude/skills/brief/SKILL.md, .claude/skills/decide/SKILL.md,
#   .claude/skills/wrap-up/SKILL.md
#
# This script is deterministic — it copies from one canonical source so
# templates never drift out of sync between projects. No inference happens
# here; content is written by the skills, not this script.

# ── Guards ────────────────────────────────────────────────────────────────

PROJECT_NAME="${1:?Usage: project-init.sh <project-name>}"
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

# Preflight — verify all required template files exist before touching
# the filesystem
REQUIRED_TEMPLATES=(
  "AGENTS.md"
  "HOW-TO-USE.md"
  "memory/BRIEF-TEMPLATE.md"
  "memory/CONTEXT-SCHEMA.md"
  "memory/DECISIONS-SCHEMA.md"
  "memory/SESSIONS-SCHEMA.md"
  ".claude/skills/brief/SKILL.md"
  ".claude/skills/decide/SKILL.md"
  ".claude/skills/wrap-up/SKILL.md"
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
mkdir -p "$PROJECT_NAME"/.claude/skills/brief
mkdir -p "$PROJECT_NAME"/.claude/skills/decide
mkdir -p "$PROJECT_NAME"/.claude/skills/wrap-up
cd "$PROJECT_NAME"

# ── Copy canonical template files ─────────────────────────────────────────

cp "$TEMPLATE_DIR/AGENTS.md"                  ./AGENTS.md
cp "$TEMPLATE_DIR/HOW-TO-USE.md"              ./HOW-TO-USE.md
cp "$TEMPLATE_DIR/memory/BRIEF-TEMPLATE.md"   ./memory/BRIEF-TEMPLATE.md
cp "$TEMPLATE_DIR/memory/CONTEXT-SCHEMA.md"   ./memory/CONTEXT-SCHEMA.md
cp "$TEMPLATE_DIR/memory/DECISIONS-SCHEMA.md" ./memory/DECISIONS-SCHEMA.md
cp "$TEMPLATE_DIR/memory/SESSIONS-SCHEMA.md"  ./memory/SESSIONS-SCHEMA.md
cp "$TEMPLATE_DIR/.claude/skills/brief/SKILL.md"   ./.claude/skills/brief/SKILL.md
cp "$TEMPLATE_DIR/.claude/skills/decide/SKILL.md"  ./.claude/skills/decide/SKILL.md
cp "$TEMPLATE_DIR/.claude/skills/wrap-up/SKILL.md" ./.claude/skills/wrap-up/SKILL.md

# Symlink — guard against re-run collision
if [ ! -L CLAUDE.md ]; then
  ln -s AGENTS.md CLAUDE.md
fi

# ── Stub files — content is written by skills, not this script ────────────
# One-line comment in each file points to its schema so they're not blank.

echo "# See memory/BRIEF-TEMPLATE.md — content written by \`rebrief\` skill" \
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
git add AGENTS.md CLAUDE.md HOW-TO-USE.md .gitignore memory/ .claude/skills/
git commit -m "chore(memory): initial scaffold"

# Disable the cleanup trap now that setup succeeded
trap - ERR

# ── Done ───────────────────────────────────────────────────────────────────

echo ""
echo "CAMP project '$PROJECT_NAME' scaffolded successfully."
echo ""
echo "Attribution setting: .claude/settings.local.json has been created with"
echo "attribution disabled (empty strings). Edit or delete this file if you"
echo "want Claude Code to append Co-Authored-By trailers to your commits."
echo "This file is not committed to git — it is a personal preference."
echo ""
echo "Next: open the project in Claude Code and run /brief to fill out memory/BRIEF.md."