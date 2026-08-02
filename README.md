# CAMP — Context And Memory Protocol

![License: MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)

Structured memory for AI coding sessions that forget everything between conversations.

CAMP solves the core problem of working with AI across multiple sessions: the
model starts fresh every time, and without a structured way to carry context
forward, you end up re-explaining decisions, relitigating settled questions,
and watching scope quietly drift. CAMP uses four Markdown files to hold a
project's memory and four skills to keep them updated reliably. It works
across Claude Code, Cursor, and Claude.ai, and it doesn't care whether your
project involves code, writing, research, or planning.

---

## Quickstart

```bash
git clone https://github.com/jeremyef/CAMP.git ~/CAMP
export TEMPLATE_DIR=~/CAMP
```
> Clones this repo as your local templates directory and points
> `TEMPLATE_DIR` at it. Add the `export` line to `~/.zshrc` or `~/.bashrc`
> to make it permanent.

```bash
TEMPLATE_DIR=~/CAMP ~/CAMP/project-init.sh my-project-name
```
> Scaffolds a new project: memory files, skills for Claude Code and Cursor,
> a git repo, and an initial commit. Add `--cursor` for Cursor-specific
> attribution config, or `--remote=<url>` to verify and wire up a git
> remote in the same step.

Open the project in Claude Code or Cursor, then run `brief` — it walks
through elicitation section by section and writes `memory/BRIEF.md` once
confirmed.

**Requires:** `git`, `gh` (optional — only for the branch-protection step
printed at the end of init), and `python3` (used by the Cursor
plan-immutability hook, the subagent-model-policy hook, and by
`projects-sync.sh` and `project-init.sh --existing` to patch existing hook
config files).

<details>
<summary>What a project looks like after init</summary>

```
my-project/
├── AGENTS.md                        ← protocol (from this repo)
├── CLAUDE.md                        → symlink to AGENTS.md
├── HOW-TO-USE.md                    ← day-to-day guide (from this repo)
├── .gitignore                       ← excludes .claude/settings.local.json
├── .claude/
│   ├── settings.json                ← registers the hooks below
│   ├── settings.local.json          ← attribution setting (not committed)
│   ├── skills/
│   │   ├── brief/SKILL.md
│   │   ├── decide/SKILL.md
│   │   ├── wrap-up/SKILL.md
│   │   └── plan-writer/SKILL.md
│   └── hooks/
│       ├── plan-reminder.sh
│       ├── plan-completion-check.sh
│       ├── plan-immutability-check.sh
│       └── subagent-model-policy-check.sh   ← Claude Code only
├── .cursor/
│   ├── hooks.json                   ← registers the plan-writer hooks below
│   ├── skills/
│   │   ├── brief/SKILL.md
│   │   ├── decide/SKILL.md
│   │   ├── wrap-up/SKILL.md
│   │   └── plan-writer/SKILL.md
│   └── hooks/
│       ├── plan-reminder.sh
│       ├── plan-completion-check.sh
│       └── plan-immutability-check.sh
├── .github/
│   └── workflows/
│       └── memory-id-check.yml      ← flags duplicate DEC-/SESS- IDs on PRs
└── memory/
    ├── BRIEF.md                     ← filled by `brief` skill
    ├── BRIEF-TEMPLATE.md            ← schema reference
    ├── CONTEXT.md                   ← updated by `wrap-up` each session
    ├── CONTEXT-SCHEMA.md            ← schema reference
    ├── DECISIONS.md                 ← append-only, updated by `decide`
    ├── DECISIONS-SCHEMA.md          ← schema reference
    ├── SESSIONS.md                  ← append-only, updated by `wrap-up`
    ├── SESSIONS-SCHEMA.md           ← schema reference
    ├── DECISIONS-ARCHIVE/
    └── SESSIONS-ARCHIVE/
```

</details>

### Adding CAMP to an existing project

```bash
TEMPLATE_DIR=~/CAMP ~/CAMP/project-init.sh --existing /path/to/existing-project
```
> Same scaffold, but collision-safe: any file that already exists at a
> destination path (`CLAUDE.md`, `.gitignore`, memory files, skills, etc.)
> is left untouched and reported as skipped rather than overwritten.
> `.claude/settings.json` and `.cursor/hooks.json` are the exception — if
> they already exist, CAMP's hook entries are merged in alongside whatever
> is already registered, rather than being skipped or overwritten wholesale.
> `--cursor` and `--remote=<url>` work the same as in fresh-init mode.
> `.cursor/` is only touched if the project already has one, or `--cursor`
> is passed explicitly.

`CLAUDE.md` is the one file CAMP won't attempt to merge automatically —
almost every existing project already has one with real content, and
overwriting it would destroy your existing instructions. If it's already
there, `project-init.sh` leaves it alone and prints a reminder to add a
manual reference to `AGENTS.md` from it yourself.

The scaffold commit is staged from only the specific paths this run wrote —
never a blanket `git add`— and the script warns (without blocking) if it
finds other uncommitted changes already sitting in the project. Re-running
`--existing` against an already-scaffolded project is idempotent: nothing
to stage means no commit is made.

---

## How it works

Four files, all in `memory/`:

| File | Answers | Updated by |
|---|---|---|
| **BRIEF.md** | What is this project, what's in/out of scope, what does success look like | `brief`, rarely |
| **CONTEXT.md** | Where does this stand right now | `wrap-up`, every session |
| **DECISIONS.md** | What was settled, and why | `decide`, when something's decided |
| **SESSIONS.md** | What happened, session by session | `wrap-up`, every session |

Four skills keep them honest:

| Skill | Does |
|---|---|
| `brief` | Elicits and writes BRIEF.md, section by section |
| `decide` | Logs a settled decision to DECISIONS.md, checked against scope first |
| `wrap-up` | Closes a session — updates CONTEXT.md, appends SESSIONS.md, flags stale "coming next" items |
| `plan-writer` | Writes a standalone, dated plan file before non-trivial changes — enforced by hooks that block edits until it's followed |

---

## CAMP in practice

### Scoping a new project

Say you're building a small habit-tracker app — one that actually helps you
stick to habits, unlike generic to-do apps. You open Claude Code and
describe the idea. There's no `memory/BRIEF.md` yet, so `brief` fires on
its own and asks a few questions before writing anything.

It pushes back on vague answers — "an app to help me build habits" becomes
"keep one habit going for 30 days without a missed day slipping by
unnoticed." It also insists on what you're *not* building, the part people
usually skip, and skipping it is how small projects balloon. Then: how will
you know it worked, and what's off the table (here: fully offline, no
login).

Once you've answered everything, it writes this:

```
# BRIEF.md — v1.0.0 (2026-06-21)

## Purpose
Help you actually stick to daily habits instead of quietly giving up
on them after a few days, the way generic to-do apps let happen.

## Scope

In:
- Log a habit as done for the day, one tap.
- See your current streak for each habit.

Out:
- Social features, sharing streaks, or leaderboards.
- Habit suggestions or AI coaching.

## Success criteria
Still using it daily after 30 days, with at least one habit at a
30-day streak and zero missed days going unnoticed.

## Constraints / non-negotiables
Must work fully offline — no account or login required.

## Notes
Single-user for now — no need to support more than one person's
habits in the same app yet.
```

### Implementing a change

A few weeks in, you want to add a "streak freeze" — skip a day without
losing your streak. That touches storage, the streak logic, and the UI, so
it's not a one-line fix. Before any file gets touched, CAMP's
pre-implementation check (C0 in AGENTS.md) fires, regardless of how you
phrase the request.

It checks `.claude/plans/` (or `.cursor/plans/`) for an existing plan.
Finding none, it asks: *"No plan found — run `plan-writer` first?"* Say
yes, and `plan-writer` reads the real streak code, then writes a dated
file:

```
# Plan: Add streak freeze to habit tracker

> **Date:** 2026-07-14 09:30 · **Status:** Approved

## Why
Missing one day currently resets the whole streak, which is
discouraging enough that it's a common reason people abandon habit
trackers entirely. A limited freeze lets one missed day pass without
losing the streak, without removing the accountability that makes
streaks motivating in the first place. Considered making streaks
never reset at all — rejected, since that removes the pressure that
makes a streak worth keeping.

## Files affected
- `lib/streak.ts` — freeze-aware streak calculation: a frozen day
  counts as "not missed" but not "completed."
- `lib/habitStore.ts` — add a `frozenDays` field per habit and a
  method to apply a freeze.
- `components/HabitCard.tsx` — freeze button, shown only when a
  streak would otherwise break today.
- `components/StreakBadge.tsx` — show a frost icon on frozen days
  in the streak history.

## TODO
- [ ] Add `frozenDays` to the habit data model; migrate existing
      local storage data.
- [ ] Update streak calculation to treat frozen days as non-breaking.
- [ ] Add the freeze action to `habitStore.ts`.
- [ ] Add the freeze button to `HabitCard.tsx`.
- [ ] Show frozen days distinctly in the streak history UI.
- [ ] Manually test: miss a day, freeze it, confirm streak continues;
      miss a second day without freezing, confirm streak resets.

## Risks / open questions
- Cap freezes (e.g. one per month) or leave unlimited? Leaving
  unlimited for v1 — revisit if it undermines the point of streaks.

## Decision log
> **2026-07-16 14:10 —** Capped freezes at one per month after two
> weeks of use — unlimited freezes made the streak feel meaningless.
> Updated TODO and Files affected to add the cap check to
> `lib/streak.ts`.
```

Nothing gets implemented until you approve it. Approval gets committed as
the record; TODO items get checked off as you go — including the
mid-flight change logged above once unlimited freezes turned out to feel
too easy.

### Making a decision

That note in the plan's Decision log only tracks how the plan changed —
it's scoped to the plan file, not the project. Whether to cap freezes at
all is a real product decision, one that would confuse a future session if
silently reversed. That's what `decide` is for.

`decide` checks BRIEF.md's Scope first (already covered — no rebrief
needed), then scans DECISIONS.md for anything logged on this topic.
Finding nothing, it shows you the proposed entry and waits for
confirmation:

```
### DEC-003 — 2026-07-16 — Cap streak freezes at one per month

Context:
Testing showed unlimited freezes made the streak feel meaningless —
after two weeks, missed days stopped feeling like they mattered.

Decision:
Limit to one freeze per calendar month per habit.

Alternatives considered:
- Unlimited freezes — rejected. Undermines the accountability that
  makes a streak worth keeping in the first place.
- No freezes at all — rejected. One missed day shouldn't erase weeks
  of consistency; that's the whole reason this feature exists.

Disposition: Active
Brief version: v1.1.0
```

Confirm it, and `decide` writes and commits it immediately — unlike
CONTEXT.md and SESSIONS.md, decisions aren't batched to the end of the
session.

### Staying oriented across sessions

A few sessions later, `wrap-up` rewrites `memory/CONTEXT.md` from scratch —
capped at 30 lines, so it's fast to read next time:

```
[2026-07-16] [v1.1.0] Streak freeze shipped and capped at 1/month.

## Current focus
Watching real usage of the freeze cap before considering rollover.

## Active blockers
None

## Open questions
- Should an unused monthly freeze roll over to the next month?

## Recently completed
- Daily habit logging and streak counting shipped and in daily use.
- Streak freeze shipped. DEC-002: streaks stored locally, no sync
  between devices. DEC-003: freezes capped at one per month.
```

Open a new conversation later, and session-start reads BRIEF.md,
CONTEXT.md, the DECISIONS.md index, and the last three SESSIONS.md entries
before responding to anything — "where were we?" is answered before you
ask.

---

## Keeping projects in sync

Running CAMP across more than one project? `projects-sync.sh` pushes
AGENTS.md, the four skills, the plan-writer hooks, the subagent-model-policy
hook, and the memory-ID CI check out to every registered project — so a
fix made here doesn't have to be copied by hand into each one.

```bash
cp projects.example.txt projects.txt
# then add one absolute project path per line
```
> Registers which projects get synced. `projects.txt` is gitignored —
> machine-specific. `project-init.sh` also registers a project here
> automatically the moment you scaffold it, so you only need this step for
> projects that existed before you started using this template.

```bash
./projects-sync.sh
```
> Copies AGENTS.md and the four skills into `.claude/skills/` and
> `.cursor/skills/` in every registered project, syncs the plan-writer
> hook scripts, the Claude-Code-only subagent-model-policy hook, and
> `.github/workflows/memory-id-check.yml`, and patches (or creates, if
> missing) `.claude/settings.json` / `.cursor/hooks.json` so the hooks
> stay registered. Commits the changes in each project automatically.

```bash
./projects-sync.sh --dry-run   # preview changes, write nothing
./projects-sync.sh --no-commit # sync files but leave the commit to you
```

---

## Platform specifics

<details>
<summary><b>Claude Code</b> — full native support</summary>

CLAUDE.md (symlinked to AGENTS.md) is read natively, skills auto-discovered,
memory files read/written directly on the local filesystem. Invoke skills
via slash command or let Claude match them automatically.

</details>

<details>
<summary><b>Cursor</b> — same as Claude Code</summary>

Cursor reads AGENTS.md natively; skills are installed to both
`.claude/skills/` and `.cursor/skills/` by default.

</details>

<details>
<summary><b>Claude.ai</b> — limited, manual sync required</summary>

No filesystem access — paste AGENTS.md into custom instructions, upload
memory files as Project Knowledge, and copy skill output back manually.

</details>

---

## Further reading

- **HOW-TO-USE.md** — the four files and skills, day to day.
- **memory/\*-SCHEMA.md** — exact format spec per memory file.
- **AGENTS.md** — the full protocol.

---

## License

MIT — see [LICENSE](./LICENSE).

---

## Related

Want the Plan → Implement → Validate agentic workflow layer (gnhf,
treehouse, firstmate, no-mistakes, Lavish) on top of this? See
[CAMP-agentic](https://github.com/jeremyef/CAMP-agentic).
