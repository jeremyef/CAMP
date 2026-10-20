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

Use this for anything where getting the approach wrong would be expensive to unwind: multi-file features, refactors, schema or migration work, anything touching auth/billing/production config, or whenever the user explicitly asks to see a plan before you start. Skip it for pure read-only questions, or when the user says a plan is not needed. A plan file for a one-line fix just adds noise to the history, so that is the user's call.

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

<Optional, additive: if this plan addresses one or more tracked open items
from memory/CONTEXT.md, add a line `Addresses: ITEM-NNN[, ITEM-MMM...]` at
the end of this section. One item may be addressed by several plans; this
is a citation, not a claim that the plan resolves the item on its own.
Purely informational: citing an item here has no effect on its closure
bookkeeping — it never protects the item from being closed, and finishing
this plan never auto-closes it. Closure only ever happens the normal way,
via wrap-up's own carry-forward/closure-vocabulary rules.>

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

If this is branch-worthy work and the project turns branches on (AGENTS.md,
"Feature-branch workflow"), create the branch first, so the approval commit is
the first on it: `git switch -c feature/<slug>`, with `<slug>` as defined below.
Start from the default branch, brought up to date first if there is a remote
(`git pull --ff-only`; if that is refused, say so and ask; if you start from a
remote branch, add `--no-track`); if you are on another branch, ask which branch
the work should start from. If a branch with that name
already exists, ask whether to switch to it or to use another name. Uncommitted
files, the Draft included, come with you. The same steps apply when the user
approves an existing Draft.

1. Update `Status:` from `Draft` to `Approved` in the plan file.
2. Commit only the plan file:
   ```
   git add <plans-dir>/<filename>.md
   git commit -m "chore(plan): <slug>" -- <plans-dir>/<filename>.md
   ```
   where `<slug>` is the kebab-case portion of the filename after the
   timestamp — e.g. `2026-06-28-1344-initial-build.md` → slug is
   `initial-build`.

This commit is the durable approval record. Make no other file changes
before this commit.

### 6. Log changes of direction, don't silently rewrite

If the approach changes mid-implementation — a step turns out to be wrong, a new constraint surfaces, the user redirects — add a timestamped entry under "Decision log" explaining what changed and why, then update the affected TODO items and "Files affected" entries above it to match. The point of the log is that someone reading the file later can see not just the final plan but how it got there.

### 7. Track progress as you execute

As each TODO item is completed, check it off in the file (`- [ ]` → `- [x]`) rather than only mentioning it in chat. This is what gives the user the at-a-glance progress view Cursor's checklist gives them.
If an item is dropped or becomes unnecessary, say so in a Decision log entry, then check it off or remove it, so the plan can still reach Complete.

### 8. Update the status line

A plan has exactly one of six statuses: Draft, Approved, In Progress,
Paused, Complete, Superseded. The status lives in the plan's header line
(`> **Date:** ... **Status:** X`). The hooks read that line only, so text
elsewhere in the file that quotes a status never changes how a plan is
treated. X must begin with one of those six words, spelled exactly (case
matters) and not followed by another letter, so Completed does not count.
The hooks ignore anything after the word, but a note belongs in the
Decision log, not on the status line. A header the hooks cannot read is
not protected, and the stop hook blocks once to say so.

Move `Status:` at these exact points, not on a guess:
- **Approved**: at step 5 (the commit), not when the user says "yes" in chat
- **In Progress**: at the first implementation file edit
- **Paused**: work is intentionally on hold and is expected to resume.
  Before setting it, append a Decision log entry saying why and what will
  resume it. A Paused plan stays editable and the stop hook does not block
  on it. Resume by setting In Progress again.
- **Complete**: only once every TODO item is checked off (the stop hook
  blocks a Complete plan that still has unchecked items) AND you have made
  every other edit you intend to make to this plan file (Decision log
  entries, Files affected corrections, TODO wording fixes).
- **Superseded**: the plan is closed without all its TODOs done because its
  work was replaced or re-planned elsewhere. Ask the user to confirm
  before setting it; never set it on your own judgement. Before setting it,
  append a Decision log entry naming where the unfinished work now lives,
  using references that exist: a plan file path, a DEC-ID, or an ITEM-NNN
  from CONTEXT.md (not free text such as "tracked elsewhere"). Unchecked
  TODOs stay unchecked. Superseded is not a way to skip unfinished work:
  work that is neither done nor replaced stays In Progress or Paused. A plan
  that is simply dropped with no replacement can be Superseded only if a
  `decide` entry records the drop; cite its DEC-ID. A Draft nobody wants
  stays Draft.

Complete and Superseded are terminal. For either, the status edit must be
its own dedicated tool call, made last, never bundled with a TODO checkbox
or a Decision log entry. Once written, `plan-immutability-check.sh` blocks
every further edit to the file. Treat it as one-way.
Commit the plan with `chore(plan): <slug>` as soon as it is Complete or
Superseded, so the durable record shows how it ended. Other status changes
need no commit of their own. `wrap-up` flags a Complete or Superseded plan
whose status differs from its last committed version, so commit those before
`wrap-up`.

Paused is not terminal and has no dedicated-call rule: write the Decision
log entry, then set the status. The plan stays editable, so further edits
to it remain allowed.

If something is discovered after a plan is Complete or Superseded, it does
not go back into that file. Route it to one of:
- a note in this session's `wrap-up` (small observation), or
- a new plan file's "Why" section referencing the old one (real follow-on
  work).

Reopening: the agent never edits or reopens a Complete or Superseded plan.
Only the user can reopen one, by editing the header by hand. If they do,
add a Decision log line saying it was reopened and why. If you believe a
plan was closed in error, stop and tell the user; do not set the Status
back yourself.

`grep -m1 '^> \*\*Date:\*\*' <plans-dir>/*.md` then gives an accurate view
of all plan states without opening each file: one header line per plan,
which is the only place the status is read from.

## Building a history

Never overwrite or delete an old plan file to make room for a new one — each planning session gets its own dated file. Over time `<plans-dir>/` becomes a real record of the project's decisions. If the user asks what was planned previously, or wants context on why something was built a certain way, look in `<plans-dir>/` before assuming the answer isn't recorded anywhere. A plan whose work was replaced is marked Superseded, and a plan on hold is marked Paused; neither is deleted or left with a status that misstates it.

## Enforcement via hooks

`project-init.sh` scaffolds three hooks into every project:

- **plan-reminder** (`.claude/hooks/` / `.cursor/hooks/`) — fires after every file edit. If a plan is marked In Progress, injects a reminder to check off the completed TODO item before continuing. If none is In Progress but one is Approved and the edit looks like implementation work (outside the plans, memory and .claude paths), it nudges the agent to ask the user whether to mark that plan In Progress, once per session for each set of Approved plans. Paused and Superseded plans trigger nothing.
- **plan-completion-check** (`.claude/hooks/` / `.cursor/hooks/`) — fires when the agent is about to stop. If a plan's header status is In Progress or Complete and it still has unchecked TODO items, blocks the stop (Claude Code) or sends a follow-up prompt (Cursor). For In Progress, the message asks the agent to finish, or to set the status to Paused and say why. For Complete, the agent cannot edit or reopen the plan, so the message tells it to stop and tell the user. Paused and Superseded plans are never blocked.
- **plan-immutability-check** (`.claude/hooks/` / `.cursor/hooks/`) — fires before Edit, Write, or MultiEdit (Claude Code) / Write, StrReplace, or Delete (Cursor). If the target file is a plan whose header status is Complete or Superseded, blocks the edit outright. Those plans are immutable; the block message directs the agent to create a new plan file instead, or to ask the user if it believes the plan was closed in error. The hook only sees edits made through those tools. A shell command such as `sed -i` is not intercepted, so the rule still depends on the agent not editing a closed plan that way.

Registered automatically in `.claude/settings.json` (Claude Code) and `.cursor/hooks.json` (Cursor). No manual setup needed.
