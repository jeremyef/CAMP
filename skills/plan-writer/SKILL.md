---
name: plan-writer
description: Use this whenever planning a non-trivial code change in Claude Code — multi-file features, refactors, migrations, or anything started in Plan Mode. Produces a comprehensive plan with reasoning, file-by-file impact, and an editable TODO checklist, saved as a standalone markdown file rather than left in chat, and keeps a permanent dated history of every plan for the project. Trigger this any time the user asks to "plan this out," wants to see the approach before coding starts, asks "what's your plan," or enters Plan Mode for anything beyond a one-file tweak — even if they don't mention "plan" by name but are clearly describing a feature or refactor that needs scoping first.
when: When the user wants to plan a non-trivial implementation, asks to see a plan before starting, or enters Plan Mode
---

# Plan Writer

A good plan earns its keep by being something a person can actually read, edit, and come back to later — not a wall of text that scrolls away in chat. This skill turns Claude Code's planning step into a durable, structured artifact: one file per plan, written to disk, building up a real history of how the project evolved and why.

## Why this exists

Chat-based plans disappear the moment the conversation moves on. If the user wants to check what was decided last week, or hand a plan to someone else, or just re-read the reasoning before approving, they have to scroll back through transcript. Writing the plan to a dedicated file fixes that — it becomes something they can open in their editor, commit to the repo, and reference independently of the conversation that produced it.

## When to use this

Use this for anything where getting the approach wrong would be expensive to unwind: multi-file features, refactors, schema or migration work, anything touching auth/billing/production config, or whenever the user explicitly asks to see a plan before you start. Skip it for trivial single-file edits or pure read-only questions — the overhead isn't worth it there, and a plan file for a one-line fix just adds noise to the history.

## Workflow

### 0. Detect the plans directory

Run this before writing anything:

```bash
if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_CHILD_SESSION:-}" ]; then
  echo ".claude/plans"
elif [ -n "${CURSOR_AGENT:-}" ]; then
  echo ".cursor/plans"
else
  echo ".claude/plans"
fi
```

The output is the plans directory path. All subsequent references to `<plans-dir>` mean whichever path this step resolves to. Create the directory if it doesn't exist yet.

### 1. Research before writing anything

Before drafting the plan, actually read the relevant files, search for related code, and understand the current structure — the same exploration Plan Mode already does. The plan is only as good as the research behind it; don't fill in the "Why" or "Files affected" sections with guesses.

### 2. Write the plan file

Create the file at `<plans-dir>/<YYYY-MM-DD-HHMM>-<kebab-case-task-slug>.md` (where `<plans-dir>` is the path resolved in step 0). Use the actual current date and time — pull it from the system clock rather than guessing — and 24-hour `HHMM` so filenames stay both unique and chronologically sortable when more than one plan happens in a day. Use a short, descriptive slug — `add-rate-limiter`, not `plan-1`.

Use this structure:

```markdown
# Plan: <Task title>

> **Date:** <YYYY-MM-DD HH:MM> · **Status:** Draft

## Why

<A few sentences on the goal and the reasoning behind this approach. If there
were real alternatives worth naming, say what was considered and why this
one won.>

## Files affected

<List only files that will actually be created or modified — not every
file read for context along the way. Order them to match the order
they're touched in the TODO list below, so the two sections can be
cross-referenced at a glance.>

- `path/to/file.ext` — <what changes here and why, one line>
- `path/to/other_file.ext` — <what changes here and why, one line>

## TODO

- [ ] <First concrete step>
- [ ] <Next step>
- [ ] <...>

## Risks / open questions

- <Anything genuinely uncertain that the user should weigh in on — a real
  tradeoff, an assumption being made, a dependency outside your control.
  Not a generic disclaimer like "tests should be reviewed." If there's
  nothing like that, omit this section entirely rather than including it
  empty.>

## Decision log

> Updates go here as the plan changes mid-implementation. Each entry
> starts with a timestamp and stays in place — append new entries below
> older ones, don't rewrite or remove what's already there.
>
> **YYYY-MM-DD HH:MM —** <what changed and why>
```

A TODO item should be one independently completable unit of work — typically one file or one cohesive change, not a single line of code. As a rough guide, most features land around 4-8 steps; if you're past ~12, the steps are probably too fine-grained (don't give "add import statement" its own line), and if a multi-file change has only 1-2 steps, they're probably too broad to actually track progress against.

Keep the "Why" section honest and specific rather than generic — "uses a sliding-window counter in Redis because the existing rate-limit middleware already depends on Redis being up" is useful; "implements rate limiting" is not.

### 3. Surface it in chat too

After writing the file, give the user a short summary in chat — the gist of the approach and a pointer to the file path — rather than making them open the file blind. Don't paste the whole plan into the chat as well; that defeats the point of having a single source of truth.

### 4. Wait for approval, then execute

Don't start editing code until the user has approved or revised the plan, consistent with how Plan Mode already works. If they ask for changes to the plan itself, edit the file directly rather than just agreeing in chat — the file should always reflect the current state of the plan, not an earlier draft.

### 5. Commit the plan as the approval record

Once the user approves, before touching any implementation file:

1. Update `Status:` from `Draft` to `Approved` in the plan file.
2. Commit only the plan file:
   ```
   git add <plans-dir>/<filename>.md
   git commit -m "chore(plan): <slug>"
   ```
   where `<slug>` is the kebab-case portion of the filename after the
   timestamp — e.g. `2026-06-28-1344-initial-build.md` → slug is
   `initial-build`.

This commit is the durable approval record. The C0 check in AGENTS.md
uses `git ls-files` + Status to find active plans — a plan that exists
only on disk (untracked) does not satisfy C0. Make no other file
changes before this commit.

### 7. Track progress as you execute

As each TODO item is completed, check it off in the file (`- [ ]` → `- [x]`) rather than only mentioning it in chat. This is what gives the user the at-a-glance progress view Cursor's checklist gives them.

### 6. Log changes of direction, don't silently rewrite

If the approach changes mid-implementation — a step turns out to be wrong, a new constraint surfaces, the user redirects — add a timestamped entry under "Decision log" explaining what changed and why, then update the affected TODO items and "Files affected" entries above it to match. The point of the log is that someone reading the file later can see not just the final plan but how it got there.

### 8. Update the status line

Move `Status:` forward at these exact points — not on a guess:
- **Approved** — at step 5 (the commit), not when the user says "yes" in chat
- **In Progress** — at the first implementation file edit
- **Complete** — once every TODO item is checked off

`grep "Status" <plans-dir>/*.md` then gives an accurate view of
all plan states without opening each file.

## Building a history

Never overwrite or delete an old plan file to make room for a new one — each planning session gets its own dated file. Over time `<plans-dir>/` becomes a real record of the project's decisions. If the user asks what was planned previously, or wants context on why something was built a certain way, look in `<plans-dir>/` before assuming the answer isn't recorded anywhere.

## Optional: enforcement via hooks

This skill relies on remembering to keep the plan file in sync as work happens. `.claude/hooks/plan-reminder.sh` and `.claude/hooks/plan-completion-check.sh` make that deterministic instead of advisory — registered via `.claude/settings.json`, they fire automatically on every file edit and on session end respectively, independent of whether this skill happens to be loaded in context. See the hooks' own comments for what each one does.
