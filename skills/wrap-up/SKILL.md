---
name: wrap-up
description: Closes out a working session — updates memory/CONTEXT.md and memory/SESSIONS.md. Use when the user indicates they're finishing for now, ending a session, or asks to wrap up, save progress, or sign off.
when: When the user is ending a session, wants to save progress, or indicates they are done for now
---

# wrap-up

## Non-interactive invocation
If `wrap-up` is running with no user able to answer a live question
(e.g. a non-interactive agent context), use these fallback defaults
instead of blocking indefinitely — each is called out at its point
below, this section is the single source of truth for all of them:
- **Decisions check**: treat as "no" (cannot be verified without a
  human) and proceed, but add a line to the SESSIONS.md Summary
  flagging that this check was skipped non-interactively, so a human
  reviewing later knows to double-check rather than assume it was
  properly answered.
- **Uncommitted-code check**: default to a memory-only commit — stage
  and commit only memory/CONTEXT.md and memory/SESSIONS.md as usual;
  never auto-commit the other dirty/untracked files without a human
  saying so.
- **Overflow's forced resolve/defer** (the last-resort path in "Overflow
  check" below, when the one-time exception isn't available): take the
  exception if it *is* available; if it isn't, let the file exceed the
  cap rather than fake a decision, and flag it loudly in Current focus
  and Next steps as needing real human attention next session. This is
  the only option, structurally — `decide` itself never logs a decision
  without explicit user confirmation, so it cannot be invoked
  meaningfully in a non-interactive run either.
- **Merged-branch check** (see that section below): if the branch is already
  merged, do not commit. Leave the memory files written and say so in the
  closing line.

## When this fires
The user is ending a working session. Explicit triggers: "let's wrap
up," "that's it for today," "save progress," "sign off." Implicit
triggers: the user states they are stopping, stepping away, or
switching to a different task entirely. Do not fire on ambiguous
phrases like "I'll pick this up later" or "one more thing" — if
genuinely uncertain, ask once: "Are you wrapping up for now?"

## Before writing anything — decisions check
Ask: "Anything decided today that isn't in memory/DECISIONS.md yet?"

If the answer is yes: do not proceed with wrap-up. Hand off to
`decide` first. Once the user confirms `decide` has run for all
outstanding decisions, then continue wrap-up from this point.

If the user says yes but does not invoke `decide` and moves on
anyway: do not silently proceed. Ask once more: "Should I log those
decisions before wrapping up, or proceed without them?" Accept
whichever they choose — document the outcome in the SESSIONS.md
Summary either way.

Untracked plan file check: after the decisions check, if `<plans-dir>`
exists run `git ls-files --others <plans-dir>/` to find untracked
plan files. Read each one's header status (the `> **Date:** ... **Status:** X`
line, by its leading word) before deciding what to do:
- `Approved`, `In Progress`, `Paused`, `Complete`, or `Superseded` and
  still untracked is a
  protocol error — plan-writer's approval commit should have committed it at
  approval time and didn't. Surface it distinctly from ordinary
  uncommitted files:
  "These plan files are Approved (or later) but were never committed
  as required at approval time:
    <list>
  Commit each with `chore(plan): <slug>` before proceeding (plan-writer's
  approval commit)." Do not bundle this with the general dirty files question
  below — it requires its own response and commit before wrap-up
  continues.
- `Draft` and untracked is expected, not an error — plan-writer commits
  a plan at approval, so a Draft is normally untracked. Do not raise it
  separately here. Instead fold its path into the "Uncommitted code
  check" below as if it were any other dirty file.

Tracked plan status-drift check: after the untracked-plan check, for
any plan file that's both tracked and dirty (shows as modified, not
untracked, in `git status`), compare its on-disk header status
against the header status in the last committed version
(`git show HEAD:<path>`). If the on-disk status is `Complete` or `Superseded`
and the two differ, surface it distinctly, the same elevated framing as the
untracked case above — not bundled with the general "Uncommitted code check"
below:
"This plan's Status changed from `<old>` to `<new>` but that change
was never committed: `<path>`. Commit it now with `chore(plan): <slug>`
before proceeding." This catches a plan committed once at an earlier
status (e.g. Approved), then edited further to a more final one
(especially Complete) with that specific edit never committed — losing
the durable record that it ever finished. Any other status change (for example
Approved to In Progress, or Paused) needs no commit of its own; do not raise it.

Uncommitted code check: after the untracked plan check, run
`git status --porcelain` to find any non-memory files that are dirty,
staged, or untracked (this must include untracked files — a Draft plan
from the check above needs to appear here, not silently drop out of
both checks). If any are found, surface the list of file paths and
ask: "These non-memory files are uncommitted — commit them first, or
proceed with the memory-only commit?" Wait for an explicit answer. Do not
auto-continue.

## Session boundary
A SESSIONS.md entry covers everything since the most recent prior
entry in SESSIONS.md, whichever skill wrote it — `wrap-up`'s own last
entry, or `brief`'s, if `brief` has written more recently (e.g. a
phase-transition bump happened since the last `wrap-up`, or `wrap-up`
has never run on this project yet and only `brief` entries exist so
far). This avoids re-narrating ground `brief`'s entry already covered.
If SESSIONS.md has no entries at all yet, this is genuinely the first
entry of any kind — cover everything from project start. If `wrap-up`
fires more than once in a session, each entry covers only the work
since the prior entry — not the whole session.

## Phase-transition detection
Before drafting CONTEXT.md's new content or running staleness checks,
compare the current BRIEF.md version against the version recorded in
CONTEXT.md's existing state pointer line (`[YYYY-MM-DD] [vX.Y.Z]
<summary>`) — read this from CONTEXT.md as it stands before this
wrap-up run overwrites it, not from SESSIONS.md. CONTEXT.md is a file
only `wrap-up` ever writes, so its state pointer always reflects the
phase `wrap-up` last recorded, regardless of any SESSIONS.md entry
`brief` may have written in between. If CONTEXT.md does not yet exist
or has no state pointer (the first `wrap-up` run of a new project),
skip this check — there is no prior phase to compare against.

If the MAJOR version has increased (e.g., v1.x.x → v2.0.0), this is
the first session of a new phase. Flag this at the start of wrap-up's
output: "This is the first session wrap-up in phase [vX.0.0]. Applying
phase-transition reset to CONTEXT.md."

Phase-transition resets (applied only when a new phase is detected):
- Staleness counters reset: the 3-session counts for both Open
  Questions and Next steps staleness checks restart from zero.
  Items from the previous phase are not treated as stale — only
  items that recur within the current phase count toward the
  threshold.
- CONTEXT.md Open Questions: review each item from the previous
  snapshot against the new phase's scope (BRIEF.md "In" list). Items
  not relevant to the new scope require asking the user before
  dropping — per CONTEXT-SCHEMA.md's "Phase-transition reset" section,
  there is no auto-drop case, a phase boundary never waives asking.
  Items still relevant carry forward (same ID).
- CONTEXT.md Recently completed: do not carry forward — start
  fresh. The phase boundary is a natural reset for this section.

## Drafting CONTEXT.md's new content (before writing either file)
Read the existing memory/CONTEXT.md in full. For each item carried
from the previous snapshot, apply exactly one of
memory/CONTEXT-SCHEMA.md's closure-vocabulary outcomes (reworded —
same ID, no closure note; merged; split; resolved; decided per
DEC-NNN; deferred per DEC-NNN; dropped — always asking the user first;
moved to a different section — not a closure). For each genuinely new
item, mint the next free `ITEM-NNN` by scanning both the current
CONTEXT.md snapshot and memory/SESSIONS.md's Closed notes (live file
and SESSIONS-ARCHIVE/, if it exists) for the highest number in use
*or* ever closed, and assign one above the higher of the two (see
CONTEXT-SCHEMA.md's "ID format" — checking the snapshot alone can
reuse a retired number once the highest-numbered item closes before
a lower one does). No counter line, no cross-file *coordination*
(this is a read, not shared state two branches both edit); collisions
are caught downstream by `memory-id-check`, not prevented here.

Also scan `<plans-dir>/*.md` for any plan whose header status is `Paused`
or `In Progress`. Name them in the drafted Current focus content as
CONTEXT-SCHEMA.md's "Current focus" section describes (one short line each)
— this is what makes a stalled-but-not-abandoned plan visible without
the next session having to open every plan file by hand.

Staleness checks — run both now, using phase-reset counts if a new
phase was detected above. Both match by `ITEM-NNN` ID, not by prose
similarity. An item that never received an ID (a project that hasn't
adopted the scheme, or a pre-existing item not yet touched by a
`wrap-up` run) falls back to the model's own judgment of prose
similarity, same as before this scheme existed.
1. Open Questions: if the same ID has appeared in Open Questions in
   memory/CONTEXT.md across 3 or more consecutive sessions within
   the current phase without resolving, flag this to the user before
   writing and prompt a decision: either log it formally via `decide`
   or explicitly defer it. Do not silently carry it forward again.
2. Next steps: scan the last 3 SESSIONS.md entries within the current
   phase (same Brief version MAJOR). If the same ID has appeared
   across 3 or more consecutive entries without being acted on or
   formally deferred, flag this to the user before writing and prompt
   the same decision. Do not silently repeat it a fourth time.

This drafting pass produces: the final Current focus / Active
blockers / Open questions / Recently completed content, and the full
list of closure notes (if any) for that session's Closed field.

## Overflow check (before composing the SESSIONS.md entry)
Count what the drafted CONTEXT.md content (above) would total,
following memory/CONTEXT-SCHEMA.md's "Hard cap and overflow handling"
section exactly. This check — and its resolution — must happen now,
**before** the SESSIONS.md entry below is composed, so the outcome
(a closure/deferral from resolving it, or the cap-exception marker)
is correctly reflected in that same entry, not missing from it.

If it fits within 40 lines (or within 45 via an available one-time
exception — see below), proceed. If it doesn't:

1. Offer to resolve or defer something now via `decide` — the
   preferred path. This may itself produce new closure notes (e.g.
   "deferred per DEC-NNN") to fold into the drafted content above.
2. If that's not how the user wants to proceed, check the immediately
   prior SESSIONS.md entry for a `Context cap exception: used` line.
   If absent, a one-time +5-line exception (45 max) is available —
   take it, and plan to write `Context cap exception: used` in this
   session's entry. If present (the prior entry already used it), the
   exception is not available again — option 1 is the only path this
   time.
3. If option 1 isn't resolved and option 2 isn't available, do not let
   the session deadlock trying to end. Surface this plainly to the
   user — "CONTEXT.md is over cap, the one-time exception was already
   used last session, and nothing's been resolved or deferred yet —
   how do you want to proceed?" — and accept whatever they decide,
   the same way a second Stop-hook attempt is allowed to succeed
   rather than loop forever. This is a last resort, not a routine
   path.

If the cap-exception marker has been used in 2 or more of the last 3
sessions, flag this to the user as a signal the base 40-line cap
itself should be raised for real, rather than leaning on the
exception repeatedly.

## Writing memory/SESSIONS.md
Read the current SESSIONS.md to determine the next SESS-ID before
writing. Read the Brief version field from the most recent entry (if
one exists) — this is used for the Next-steps staleness scan's
current-phase scoping above, not for phase-transition detection (that
check uses CONTEXT.md instead — see above — because `brief` can also
write directly to SESSIONS.md, which would make a SESSIONS.md-based
comparison unreliable; `brief` never participates in ID assignment or
closure notes at all).

Append one new entry following memory/SESSIONS-SCHEMA.md exactly —
Summary, Brief version (current BRIEF.md version), Decisions, Closed
(the closure notes from the drafting pass above, or "None"), Files
touched (omit if none), Next steps, Context cap exception (only if
used, per the overflow check above). This is append-only — never edit
a past entry.

Archive check: if appending this entry would bring the live entry
count to 11 or more, move all but the most recent 5 entries to
memory/SESSIONS-ARCHIVE/<year>-<quarter>.md before committing, then
append one archive-event line at the top of SESSIONS.md per the
schema.

## Writing memory/CONTEXT.md
Write the file using the content already drafted above — state
pointer (first line, always — format: `[YYYY-MM-DD] [vX.Y.Z]
<summary>`), Current focus, Active blockers, Open questions, Recently
completed. Active blockers and Open questions lines carry the
`ITEM-NNN:` prefix, one item per line (never more than one item on a
single bullet).

Current focus, Active blockers, and Open questions are never cut for
space — the overflow check above already resolved any case where they
wouldn't fit. Only Recently completed may still be trimmed if, after
everything else, it alone pushes the file over the (possibly
exception-extended) cap:
1. Tell the user Recently completed was trimmed, and why.
2. Replace the trimmed content with:
   [Truncated — see SESSIONS.md SESS-NNN for this session's output]

## After writing
Closing summary first — before any git steps, give the user a 3-5
sentence plain-language summary covering: what was accomplished this
session, any decisions logged, any items closed, and what's queued
for next time (or "nothing queued" if Next steps is None). In a git project,
also name any local branch whose last commit is more than 60 days old and that
is not merged into the default branch (not contained in it, and its remote copy
not deleted, as of the last fetch), with that date. Only name them; deleting
one is for the user to ask for (see "Branch cleanup"). This is
for the user reading in the moment, not a repeat of what was written
to the files.

Git steps (only if inside a git work tree — check per AGENTS.md's
git-detection rule; skip entirely if not):
- If nothing in memory/ actually changed this session, skip the
  commit — do not force an empty commit. A Closed-only or
  Context-cap-exception-only change still counts as "changed."
- Otherwise, run the "Merged-branch check" below before staging anything.
- Then stage only memory/CONTEXT.md and memory/SESSIONS.md
  (+ memory/SESSIONS-ARCHIVE/<file> if archiving ran this turn).
- Commit message: `chore(memory): session wrap-up [SESS-NNN]` where
  SESS-NNN is the ID of the entry just written — read from the entry
  itself, do not invent. Name the same paths in the commit (`git commit
  -m "<message>" -- <the paths above>`), so anything else already staged
  stays out of it.
- End with one closing line: the branch the commits are on, and how many
  commits on it are not yet pushed (`git rev-list --count @{upstream}..HEAD`).
  If the branch has no upstream, say that instead, and that it may not have been
  pushed; if its upstream is gone, say the remote copy was deleted. If the
  branch is not the repo's default branch, say so explicitly. If no commit was
  made, the line says so and, if the memory files changed, that they are written
  but not committed. On a branch other than the default, also say what the
  merged-branch check found: not merged, merged (and you stopped), or could not
  run, and why.

## Merged-branch check
The aim: do not commit memory files onto a branch whose work is already merged.
Run this at the commit step, just before staging, on any branch that is not the
default branch; `decide` and `brief` do the same at their commit step. The memory
files are already written by then, so stopping leaves them written and
uncommitted.

Find the default branch once and reuse it, including for the stale-branch list:
the branch `origin/HEAD` points to; if that is not set, `main` or `master` when
exactly one of them exists on the remote (locally, if there is no remote);
otherwise ask once (unattended: skip the check and say so in the closing line).
The remote is `origin`, or the only remote if there is just one; with several
and none called `origin`, ask once (unattended, as above). Below,
`<remote>/<default>` means the remote's copy of the default branch, or the local
default branch if there is no remote.

If a remote exists, start with `git fetch --prune <remote>`. Run every network
command with a time limit (`timeout 10 <command>`). A command that is missing, errors or
times out counts as "could not run", never as "no" (but `--is-ancestor` exiting 1
is a real "no", 128 is an error, and `gh pr view` saying "no pull requests found"
is a real "no"): carry on with what is local and say so in the closing line.

The branch is merged if any of these says so:
- its tip is contained in `<remote>/<default>` (`git merge-base --is-ancestor
  HEAD <remote>/<default>`; test the remote's copy, not your local default
  branch, which may be behind). A brand-new branch with no commits is contained
  too, so if this is the only sign, ask whether the branch is simply new and
  carry on if it is;
- its remote copy is gone after the prune
  (`git for-each-ref --format='%(upstream:track)' refs/heads/<branch>` shows
  `[gone]`), which usually means the pull request merged;
- `gh pr view --json state` says MERGED (when `gh` is installed and the remote is
  on GitHub), which also catches squash and rebase merges.

This check is best effort. It cannot see a squash or rebase merge, or a merged
branch that has gained commits since, when the remote branch was kept and `gh` is
missing, a merge into a fork's upstream, work done in another clone, or anything
when the fetch fails. The closing line names the branch
and the result of the check, so a miss is visible.

If the branch is merged, stop and say so before doing anything else, and list the
branch's commits that the default branch does not contain (`git log
<remote>/<default>..HEAD`), so work added after the merge is visible. Then offer,
and never act unasked: (a) commit the memory files on a short-lived branch
started from the remote's default branch, leaving your local default branch alone
(`git switch -c chore/memory-<date> --no-track <remote>/<default>`), and tell the
user to merge it (any uncommitted code files come along on the switch; tell the
user); (b) stop. If a switch is refused, do not force it: say what blocked it and
leave the memory files as they are.

## Branch cleanup
After a merged-branch recovery, offer to tidy up the branch you left; never act
unasked. Remove its worktree first if it has one (`git worktree remove <path>`),
never the one this session is standing in; if git refuses because it holds
untracked or modified files, do not use `--force`: say what it holds and ask.
Then delete the local branch with `git branch -d <branch>`. If that refuses (for
example after a squash merge), or the user says the work is abandoned, show the
commits that would be lost (`git log <remote>/<default>..<branch>`), say whether the pull request was merged, and use
`git branch -D <branch>` only after an explicit yes. Never delete a remote branch;
if the user asks, mention GitHub's "automatically delete head branches" setting.

## What this skill never does
- Never writes to memory/DECISIONS.md under any circumstance — not
  even to note that a decision was made. That job belongs to `decide`
  exclusively.
- Never writes to memory/BRIEF.md.
- Never edits a past SESSIONS.md entry.
- Never runs git push.
