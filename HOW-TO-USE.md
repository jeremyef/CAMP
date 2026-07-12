# How to Use CAMP

## What it is

CAMP (Context And Memory Protocol) is a structured memory system for
AI-assisted projects. It solves the core problem of working with AI across
multiple sessions: the model starts fresh every time, and without a structured
way to carry context forward, you end up re-explaining decisions, relitigating
settled questions, and watching scope quietly drift over time.

CAMP uses four Markdown files to hold the project's memory, and four skills
to keep those files updated reliably. It works across Claude Code, Cursor, and
Claude.ai, and it doesn't care whether your project involves code, writing,
research, or planning — the structure is the same either way.

---

## The four files

All four live in a `memory/` subdirectory of your project.

**BRIEF.md** is the foundation. It defines what the project is, what's in scope, what's out of scope, and what success looks like. It's the document everything else is measured against — decisions are checked against it, scope creep is caught by comparing proposals to it. It changes rarely and only deliberately. Think of it as scoped to a *phase* of the project, not the entire project — when a phase ends and the next begins, the brief is updated to reflect the new scope.

**CONTEXT.md** is the current snapshot. It answers "where does this project stand right now" — what's being worked on, what's blocked, what's unresolved, what just finished. It gets fully rewritten at the end of every session. It's the first thing a new session reads after the brief, and it's deliberately short (capped at 30 lines) so it stays fast to read and process.

**DECISIONS.md** is the permanent record of anything that was settled. Technology choices, scope boundaries, process decisions, anything that would cause confusion if silently reversed later. Entries are never edited — when circumstances change, a new entry supersedes the old one. The file grows in one direction only.

**SESSIONS.md** is the session log. One entry per session, recording what happened, what was decided, and what's coming next. It's the audit trail that lets you understand the project's history without reading every conversation. Older entries archive automatically once the file gets long.

---

## The four skills

**`brief`** creates or updates BRIEF.md. It's invoked at the start of a new project, and again whenever the project is moving into a new phase with a genuinely different scope. It guides you through the content section by section, pushes back on vague answers, and requires both an "In" and an "Out" list in the Scope section before it'll write anything. It's the most deliberate and least frequent of the four skills.

**`decide`** logs a decision to DECISIONS.md. It fires after a choice has been made in conversation — not at the start of a discussion, but at the end, when something's been settled. It checks the decision against the current scope, scans for prior entries on the same topic, shows you the proposed entry for confirmation, and then writes and commits it. It never fires automatically during a discussion; you invoke it once you've reached a conclusion.

**`wrap-up`** closes out a session. It updates CONTEXT.md with the current project state and appends a new entry to SESSIONS.md. It runs a staleness check on recurring items before it writes — if the same thing has been "coming next" for three sessions running without being acted on or formally deferred, it flags it. It also asks "anything decided today that isn't logged yet?" before writing, to catch decisions that didn't go through `decide` during the session.

**`plan-writer`** writes a structured plan before a non-trivial change begins — multi-file features, refactors, migrations, or anything started in Plan Mode. It researches first, then writes a standalone dated file (reasoning, file-by-file impact, a TODO checklist, risks, and a decision log) instead of leaving the plan in chat. Every plan gets its own file rather than overwriting the last one, so `<plans-dir>/` becomes a permanent history of what was planned and why. Three hooks enforce it automatically once scaffolded: a reminder to check off completed TODOs after each edit, a block on stopping mid-plan with unchecked items, and a block on editing a plan already marked Complete.

---

## Starting a project

Run the project-init script once:

```bash
TEMPLATE_DIR=/path/to/your/templates ./project-init.sh my-project-name
```

This creates the directory structure, copies the schema and template files, creates the AGENTS.md/CLAUDE.md symlink, writes empty stub files for the four memory files, sets up git, and writes an initial commit. It also creates `.claude/settings.local.json` with commit attribution disabled — edit or delete that file if you want Claude Code to append Co-Authored-By trailers to commits.

`project-init.sh` scaffolds the four skills into `.claude/skills/` and `.cursor/skills/` automatically — no separate install step.

Then run `brief` to fill out BRIEF.md before doing any other work. The skill will ask which optional sections apply, walk through each gated section, and only write the file once everything is confirmed. The first SESSIONS.md entry is written automatically at the end of this step.

---

## A typical session

At the start of a new conversation, the session-start protocol runs automatically (or manually with "catch me up" / "start session"). It reads AGENTS.md, BRIEF.md, CONTEXT.md, the DECISIONS.md index, and the last three SESSIONS.md entries — in that order — before responding to anything else. This is what carries context between sessions.

During the session, work normally. When a meaningful decision gets made, invoke `decide`. It doesn't need to be invoked mid-discussion — wait until the choice is settled, then run it. Some sessions will have several `decide` invocations; some will have none.

At the end of the session, invoke `wrap-up`. It handles CONTEXT.md and SESSIONS.md, runs the staleness checks, commits the memory changes to git, and gives you a plain-language summary of what happened and what's queued for next time.

---

## Phase transitions

A project brief is scoped to a phase, not the entire project lifetime. When a meaningful chunk of work is complete and the next phase has a genuinely different scope, run `brief` again. It reads the existing brief, identifies what's changing, proposes the version bump (MAJOR if the Scope In/Out lines change, MINOR for other structural changes), and rewrites the file.

Two things happen automatically at a phase transition: the brief skill scans DECISIONS.md for any entries that were Deferred under the old scope but are now in scope under the new one, and surfaces them before the session begins; and the first `wrap-up` of the new phase applies a reset to CONTEXT.md — clearing phase-specific Open Questions and Recently completed items rather than carrying them forward blindly.

All decisions made under the old scope remain in DECISIONS.md with their original context. Nothing is lost — they're just understood as belonging to the previous phase when read later.

---

## Choosing the right tool

The memory system works across Claude Code, Cursor, and Claude.ai — but each tool has a different relationship with your project files, and picking the wrong one for a task is the most common way to get a frustrating session. The distinction isn't about which tool is better; it's about what each one can actually see.

### Claude Code and Cursor — use when you need to touch files

Both Claude Code and Cursor have direct access to your local filesystem. They can read any file in your project, write and edit code, run commands, commit to git, and invoke the skills that keep the memory system updated. This is where the skills actually run.

**Use Claude Code or Cursor when:**

- You're writing, editing, or refactoring code. The agent can read the actual files, understand the existing patterns, and make changes that are consistent with the rest of the codebase.
- You want to review a coding pattern across multiple files. Example: "Is the error handling pattern consistent between `src/auth/` and `src/payments/`?" — Claude Code can read both directories and give you a grounded answer, not a generic one.
- You're working through a structural question that requires seeing the layout. Example: "Should we move the calendar integration into its own service, or keep it in `src/handlers/`?" Claude Code can see the actual files involved and reason about the real structure.
- You're running the skills. `decide`, `wrap-up`, and `brief` all read and write memory files directly. They only work properly in Claude Code or Cursor.
- You're at the end of a session and need `wrap-up` to commit the memory state.

**A rough test:** if your question would be better answered by someone who can see the code than by someone who's only heard you describe it — use Claude Code or Cursor.

---

### Claude.ai — use when files don't need to change

Claude.ai does not have access to your local filesystem. Skills uploaded to it run in a sandboxed environment, not your project directory. The memory files you've uploaded to Project Knowledge are snapshots — claude.ai reads them but can't update them, and it can't see any other file in your project unless you paste it in.

This sounds limiting, but it maps cleanly onto a real category of work: conversations where what matters is *thinking*, not *doing*.

**Use Claude.ai when:**

- You're planning the next phase or sprint. Example: "Given what we've built so far and the constraints in BRIEF.md, what should phase 2 scope look like?" Claude.ai has the context it needs from the memory files and can reason about direction without touching code.
- You're researching an approach before committing to it. Example: "What are the tradeoffs between Twilio and a self-hosted SMS gateway for our use case?" This is a discussion, not an implementation — the memory files give it enough project context to give relevant advice.
- You're reviewing a decision before logging it. Example: "We're thinking of switching from REST to GraphQL for the API. Does this conflict with anything in our decision history?" Claude.ai can read DECISIONS.md and BRIEF.md and reason about it honestly.
- You're doing longer-form thinking that would burn through Claude Code's context quickly. Research sessions, brainstorming, comparative analysis — claude.ai handles these well as a standalone tool.
- You want a second opinion on something that doesn't require seeing the implementation.

**Use claude.ai with caution when:**

- The conversation is about code structure or patterns. You can paste a `tree` output and relevant files to give it a picture, but it's working from a static snapshot, not the live codebase. It can discuss patterns, but it can't verify them. For example, "does this pattern hold across the whole codebase" is a question it can only partially answer from what you paste — Claude Code can answer it completely.

```bash
tree -a -I '.git|node_modules|*.pyc' --dirsfirst > project-snapshot.txt
```
> Generates a visual directory tree, excluding git internals, node_modules, and compiled files, and saves it to a text file you can paste into claude.ai for structure-related discussions. `-a` includes hidden directories like `.claude/`.

**Don't use claude.ai when:**

- You need the skills to actually run. `decide`, `wrap-up`, and `brief` require filesystem access — they don't work properly in claude.ai's sandboxed environment. Any decisions reached in a claude.ai session need to be manually logged when you return to Claude Code or Cursor.
- The answer depends on seeing code you haven't pasted. Example: "Is the auth module well-structured?" — claude.ai will give you a generic answer because it can't see the module. Claude Code will give you a real one.
- You're at the end of a session and need `wrap-up` to commit the memory state. Switch to Claude Code or Cursor for that step.

**The practical handoff pattern:** use claude.ai for the thinking, then bring the conclusions back. If a claude.ai session produces a decision worth logging, note it and run `decide` in your next Claude Code or Cursor session. If it surfaces a new direction worth capturing in BRIEF.md, run `brief`. The memory system makes this handoff clean — the next Claude Code session starts with full context regardless of where the thinking happened.

See PLATFORM-WIRING.md for full installation and setup details per platform.

---

## Token usage

> **Note — dated June 2026.** Anthropic adjusts usage limits periodically.
> The absolute numbers below may drift; the relative guidance holds.

Token cost compounds with session length — every message re-reads the full
accumulated context from scratch, so the memory system's static footprint
gets paid on every turn. At steady state (mature project with DECISIONS.md
index), that footprint is roughly 2,500 tokens. For a 20-message session,
that's ~50,000 tokens from footprint re-reads alone, before counting the
conversation itself.

**Project init** (first `brief` run, 10–15 elicitation exchanges):
roughly 45,000–60,000 tokens. On Pro this sits at or above the window;
on Max 5x it fits comfortably.

**Day-to-day sessions:**

| Session type | Messages | Estimate |
|---|---|---|
| Short planning / research | 10 | ~25,000 |
| Typical build session + skills | 20 | ~55,000 |
| Long debugging / exploration | 35 | ~92,000 |

On **Pro** (~44K window): keep sessions short. Invoke `wrap-up` earlier
than feels natural, start a new conversation, and the footprint resets.
Long exploratory sessions without compaction are not viable.

On **Max 5x** (~88K): comfortable up to ~25–30 messages. Watch the limit
past 35.

On **Max 20x** (~220K): comfortable headroom for nearly any session.

One cost that grows through a project's early life: before the
DECISIONS.md index exists (first ~40 entries), the full file is read each
session. At 39 entries it may cost 2,000+ tokens per session start. Once
the index generates it drops to ~300 and stays flat regardless of project
age — this is the biggest single payoff of the archiving mechanic.

---

## File reference

| File | Owned by | Updated | Never |
|---|---|---|---|
| BRIEF.md | `brief` skill | At project start; at phase transitions | Edited directly; touched by other skills |
| CONTEXT.md | `wrap-up` skill | End of every session | Appended to; edited mid-session |
| DECISIONS.md | `decide` skill | When a decision is made | Edited; entries deleted |
| SESSIONS.md | `wrap-up` skill | End of every session | Edited; entries deleted |

Schema files (`DECISIONS-SCHEMA.md`, `SESSIONS-SCHEMA.md`, `CONTEXT-SCHEMA.md`, `BRIEF-TEMPLATE.md`) live in `memory/` alongside the live files. They're reference documents for the skills — you don't edit them during normal use, but reading them is the fastest way to understand any file's format in detail.
