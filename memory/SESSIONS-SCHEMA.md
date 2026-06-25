# SESSIONS.md — Entry Schema

## ID format
SESS-NNN, zero-padded to 3 digits, sequential, never reused, never
renumbered. Numbering continues across archive boundaries — an archived
entry keeps its original ID forever.

## Session boundary — what counts as "one session"
One SESSIONS.md entry corresponds to exactly one `wrap-up` invocation,
regardless of how much was covered or how many distinct topics came up
within it. This is a fixed, mechanical boundary, not a judgment call
about whether enough "happened" to warrant a new entry. Want finer-
grained history? Invoke `wrap-up` more often — the schema itself never
tries to detect natural breakpoints on its own.

## Field presence and formatting
- Summary — always present. Prose, one sentence per distinct thread of
  work covered. No fixed sentence cap; length tracks what the session
  actually covered.
- Brief version — always present. The current BRIEF.md version at the
  time `wrap-up` runs (e.g. `v1.2.0`). Makes phase context readable
  from the session log without cross-referencing git history.
- Decisions — always present. Zero items: write "None". One item:
  inline. Two or more: bulleted sub-list.
- Files touched — omitted entirely (not written, not "None") if zero
  items. One item: inline. Two or more: bulleted sub-list. Paths are
  relative to project root. Never includes anything under memory/
  itself — that's implied by the entry's own existence, not separately
  reported.
- Next steps — always present. Zero items: write "None". One item:
  inline. Two or more: bulleted sub-list. See "Purpose of Next steps"
  below for what belongs here.

## Entry template

Three formats are shown below — use whichever matches the actual
item count per field, per the rules in "Field presence and formatting."

### Zero or one item per field (inline)
## SESS-NNN — YYYY-MM-DD

Summary: What happened this session in plain prose.

Brief version: v1.0.0
Decisions: DEC-001
Files touched: src/auth/login.ts
Next steps: Draft the CONTEXT.md schema.

### Two or more items per field (bulleted)
## SESS-NNN — YYYY-MM-DD

Summary: First thread of work this session. Second distinct thread
of work this session.

Brief version: v1.2.0
Decisions:
- DEC-004
- DEC-005

Files touched:
- src/auth/login.ts
- src/auth/session.ts
- tests/auth.test.ts

Next steps:
- Review the wrap-up skill for the Next-steps staleness check.
- Save DECISIONS-SCHEMA.md as an artifact.

### Nothing to report on optional fields
## SESS-NNN — YYYY-MM-DD

Summary: Research session only — no code or files changed.

Brief version: v2.0.0
Decisions: None
Next steps: None

(Files touched is omitted entirely when there's nothing to list —
not written as "Files touched: None".)

Date used is the date `wrap-up` actually runs, not the date the
session started — relevant for sessions that cross midnight.

This entry is a historical record of what this specific session
concluded, frozen at write time. It is not edited after writing —
append a new entry rather than correcting an old one, even for minor
errors. If a later session's facts disagree with what an older entry
recorded, that disagreement is expected and informative — it shows how
understanding changed over time.

## Purpose of "Next steps" — and why it's not redundant with CONTEXT.md
This field is not primarily an instruction for what to do next — that
job belongs to memory/CONTEXT.md, which is always the current, live
answer. What "Next steps" actually provides is something CONTEXT.md
structurally cannot: a dated trail of what each session, in sequence,
believed was coming next. Read across several entries, this trail is
what lets a later review answer "did we consciously decide to drop X,
or did it just quietly stop being mentioned?" — a kind of silent scope
drift that a Deferred entry in DECISIONS.md cannot catch, since
DECISIONS.md only records things that were explicitly decided. An item
that fades out of "Next steps" across several sessions without ever
being formally deferred is itself a signal worth surfacing.

This value is only realized if something actually reads the trail back
— on its own, an unread historical field has no effect. `wrap-up`
should treat this the same way it already treats stale Open Questions
in CONTEXT.md: if the last several SESSIONS.md entries show the same
unresolved item recurring in "Next steps" without being acted on or
formally deferred, flag this to the user directly rather than silently
appending another repeat of it.

Phase-boundary reset: the 3-session staleness count resets when a
MAJOR brief version bump is detected (i.e., a new phase has started).
An item that appeared in Next steps at the end of phase 1 and is not
carried into phase 2 is not stale — it was consciously closed at the
phase boundary. Only items that recur within the same phase count
toward the staleness threshold.

## Archive
Trigger: once the live entry count exceeds 10 (i.e., reaches 11), move
all entries older than the most recent 5 to
memory/SESSIONS-ARCHIVE/<year>-<quarter>.md, based on each entry's
date. Re-triggers any time the live count exceeds 10 again. Full entry
content is preserved exactly — archiving is a move, not a
summarization.

No per-entry index is needed for token-budget purposes the way
DECISIONS.md needed one — the entry cap already keeps the live file
small regardless of project age. Findability over a long project still
needs a cheap answer, though: each time archiving runs, append one
line to the top of SESSIONS.md recording the range moved and its
destination, e.g. "Archived: SESS-001-SESS-006 -> 2026-Q1.md". This is
one line per archive event, not one per entry, so it doesn't
reintroduce unbounded growth — it just means a specific past session
can be located without opening every archive file in turn.
