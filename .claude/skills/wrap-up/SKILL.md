---
name: wrap-up
description: Closes out a working session — updates memory/CONTEXT.md and memory/SESSIONS.md. Use when the user indicates they're finishing for now, ending a session, or asks to wrap up, save progress, or sign off.
when: When the user is ending a session, wants to save progress, or indicates they are done for now
---

# wrap-up

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

Uncommitted code check: after the decisions check, check whether any
non-memory files are dirty or staged in the working tree. If any are
found, surface the list of dirty file paths and ask: "These
non-memory files are uncommitted — commit them first, or proceed with
wrap-up?" Wait for an explicit answer. Do not auto-continue.

## Session boundary
A SESSIONS.md entry covers everything from the previous `wrap-up`
invocation (or session start, if this is the first wrap-up) to this
one. If `wrap-up` fires more than once in a session, each entry
covers only the work since the prior entry — not the whole session.

## Writing memory/SESSIONS.md
Read the current SESSIONS.md to determine the next SESS-ID before
writing. Read the Brief version field from the most recent entry (if
one exists) — this is used for the phase-transition check below.
Append one new entry following memory/SESSIONS-SCHEMA.md exactly —
Summary, Brief version (current BRIEF.md version), Decisions,
Files touched (omit if none), Next steps. This is append-only —
never edit a past entry.

## Phase-transition detection
Before running staleness checks or writing CONTEXT.md, compare the
current BRIEF.md version against the Brief version field from the
most recent SESSIONS.md entry. If the MAJOR version has increased
(e.g., v1.x.x → v2.0.0), this is the first session of a new phase.
Flag this at the start of wrap-up's output: "This is the first
session wrap-up in phase [vX.0.0]. Applying phase-transition reset
to CONTEXT.md."

Phase-transition resets (applied only when a new phase is detected):
- Staleness counters reset: the 3-session counts for both Open
  Questions and Next steps staleness checks restart from zero.
  Items from the previous phase are not treated as stale — only
  items that recur within the current phase count toward the
  threshold.
- CONTEXT.md Open Questions: review each item from the previous
  snapshot against the new phase's scope (BRIEF.md "In" list).
  Items not relevant to the new scope are dropped after asking
  the user. Items still relevant carry forward.
- CONTEXT.md Recently completed: do not carry forward — start
  fresh. The phase boundary is a natural reset for this section.

Staleness checks — run both before writing Next steps (using
phase-reset counts if a new phase was detected above):
1. Open Questions: if the same item has appeared in Open Questions in
   memory/CONTEXT.md across 3 or more consecutive sessions within
   the current phase without resolving, flag this to the user before
   writing and prompt a decision: either log it formally via `decide`
   or explicitly defer it. Do not silently carry it forward again.
2. Next steps: scan the last 3 SESSIONS.md entries within the current
   phase (same Brief version MAJOR). If the same item has appeared
   across 3 or more consecutive entries without being acted on or
   formally deferred, flag this to the user before writing and prompt
   the same decision. Do not silently repeat it a fourth time.

Archive check: if appending this entry would bring the live entry
count to 11 or more, move all but the most recent 5 entries to
memory/SESSIONS-ARCHIVE/<year>-<quarter>.md before committing,
then append one archive-event line at the top of SESSIONS.md per
the schema.

## Writing memory/CONTEXT.md
Read the existing memory/CONTEXT.md in full before generating new
content — carry items forward per the read-before-write rule in
memory/CONTEXT-SCHEMA.md. If a phase transition was detected above,
apply the phase-transition reset rules from CONTEXT-SCHEMA.md instead
of the normal carry-forward rules.

Then fully overwrite the file using the structure defined in
CONTEXT-SCHEMA.md: state pointer (first line, always — format:
`[YYYY-MM-DD] [vX.Y.Z] <summary>`), Current focus, Active blockers,
Open questions, Recently completed.

Apply the 30-line hard cap per the schema's truncation order (cut
Recently completed first, then Open questions, then Current focus as
last resort — state pointer and Active blockers are never cut).

Truncation is never silent — two mandatory outputs whenever any
content is cut:
1. Tell the user which section was truncated before finishing.
2. Replace the truncated content in the file with:
   [Truncated — see SESSIONS.md SESS-NNN for this session's output]

If truncation has occurred in the last 3-4 sessions, flag this as a
signal to raise the cap rather than normalise repeated truncation.

## After writing
Closing summary first — before any git steps, give the user a 3-5
sentence plain-language summary covering: what was accomplished this
session, any decisions logged, and what's queued for next time (or
"nothing queued" if Next steps is None). This is for the user reading
in the moment, not a repeat of what was written to the files.

Git steps (only if inside a git work tree — check per AGENTS.md's
git-detection rule; skip entirely if not):
- If nothing in memory/ actually changed this session, skip the
  commit — do not force an empty commit.
- Otherwise, stage only memory/CONTEXT.md and memory/SESSIONS.md
  (+ memory/SESSIONS-ARCHIVE/<file> if archiving ran this turn).
- Commit message: `chore(memory): session wrap-up [SESS-NNN]` where
  SESS-NNN is the ID of the entry just written — read from the entry
  itself, do not invent.
- If the current branch is not the repo's default branch, say so
  explicitly after committing — see AGENTS.md, "Branch awareness."

## What this skill never does
- Never writes to memory/DECISIONS.md under any circumstance — not
  even to note that a decision was made. That job belongs to `decide`
  exclusively.
- Never writes to memory/BRIEF.md.
- Never edits a past SESSIONS.md entry.
- Never runs git push.
