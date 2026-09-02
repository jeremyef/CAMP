# CONTEXT.md — Snapshot Schema

CONTEXT.md is fully overwritten on every `wrap-up` run — never appended
to, never edited in place between sessions. It reflects the current live
state only; history lives in memory/SESSIONS.md instead.

## Process — read before write
Before generating new content, `wrap-up` reads the existing CONTEXT.md
in full. Items in the previous snapshot carry forward unless one of
these conditions applies:
- The item is now complete — move it to "Recently completed" if still
  relevant for continuity, otherwise drop it.
- The item has been superseded by new information this session.
- Carrying it forward would push the file over the 30-line hard cap,
  in which case apply the truncation order below.
Nothing is silently dropped — if an item is being removed for any
reason other than the above, surface this to the user before writing.

## State pointer — format and content
The state pointer is always the first line of CONTEXT.md, with no
section header before it. It follows this exact format:

  [YYYY-MM-DD] [vX.Y.Z] <one-sentence summary of where the project stands>

The brief version is included so a cold reader immediately knows which
phase they're in without reading BRIEF.md. On a single-phase project
this is redundant but harmless; on a multi-phase project it is the
fastest possible orientation signal.

It answers the question "if someone reads only this one line, what's
the single most useful thing to know right now?" — typically the
current phase, what's immediately next, or a critical active blocker
if one exists. It is not a repeat of Current focus; it's a compressed
version meant to orient a reader in under 10 words (excluding the
version prefix).

Examples of acceptable state pointers:
  [2026-06-24] [v1.1.0] Reviewing schemas; CONTEXT and BRIEF still need passes.
  [2026-07-01] [v1.2.0] Auth complete; now starting payment integration.
  [2026-07-15] [v2.0.0] Phase 2 started; notifications and integrations in scope.
  [2026-08-10] [v2.0.0] Blocked on API credentials from third-party vendor.

## Phase-transition reset
When the first `wrap-up` of a new phase runs — see skills/wrap-up/SKILL.md
"Phase-transition detection" for how this is detected; that file is
the single source of truth for the detection mechanism, not this
schema — the following resets apply:

1. Do not carry Open Questions forward automatically. Review each item:
   - If it's relevant to the new phase's scope, carry it forward.
   - If it was phase-1-specific and no longer applies, drop it silently.
   - If it's unclear, surface it to the user: "This open question from
     the previous phase may no longer apply — carry forward or drop?"
2. Do not carry Recently completed forward. The phase boundary is a
   natural reset point for this section — start fresh.
3. Update the state pointer to reflect the new phase version and focus.

This reset is more aggressive than a normal session's read-before-write
carry-forward. The goal is to start the new phase with a clean,
phase-relevant CONTEXT.md rather than one cluttered with phase-1
artifacts.

## Structure and per-section line caps
After the state pointer, a blank line, then the following sections in
order. Section headers use ## exactly as shown.

## Current focus
1-3 lines. What's actively being worked on right now. If multiple
parallel workstreams exist and cannot be represented in 3 lines,
consolidate to the highest-priority one and note "plus N others" rather
than expanding past the cap — the cap exists for a reason.

## Active blockers
0-3 lines, or "None". A blocker is something external or unresolved
that is actively preventing progress right now — not a concern, not a
question, but a concrete dependency that cannot be worked around without
resolving it first. If it can be worked around, it's an Open question,
not a blocker.

## Open questions
0-3 lines, or "None". Things unresolved that aren't yet a logged
decision and aren't actively blocking progress. The distinction from
Active blockers: work can continue in parallel while these sit open.
Once something here becomes a real decision point (something that would
otherwise get re-litigated later), move it through the `decide` skill
rather than letting it live here indefinitely. If the same item
appears in Open questions for 3 or more consecutive sessions without
resolving, `wrap-up` must flag this to the user and prompt a decision
to either formally decide it via `decide` or formally defer it — not
silently carry it forward again.

## Recently completed
0-5 lines. What just finished, included for continuity across the
session boundary. Not a full log — that's what SESSIONS.md is for.
Zero is valid (write "None") for sessions where nothing was
completed, such as a pure research or planning session.

## Hard cap and line counting
Maximum 30 lines total. Every line counts toward this cap, including:
section headers, the state pointer, blank lines between sections, and
content lines. Blank lines between sections are part of the format —
do not remove them to squeeze under the cap; instead apply the
truncation order below.

If new content would exceed the cap, cut in this order until it fits:
1. Recently completed — cut oldest items first.
2. Open questions — cut lowest-priority items first.
3. Current focus — reduce to the single highest-priority item only;
   this is an absolute last resort.
The state pointer and Active blockers are never cut under any
circumstance. If the cap genuinely cannot be met without cutting one
of these, stop and flag this to the user rather than cutting silently.

Per-section caps (1-3, 0-3, etc.) are defaults — if the global cap
has room and a section genuinely warrants one extra line, the global
cap takes precedence over the per-section cap. The per-section cap is
a guide, not an override of the 30-line hard limit.

## Truncation — visibility rules
Truncation is never silent, regardless of which section is cut.
Every truncation event has two mandatory outputs:

1. Tell the user. Before finishing `wrap-up`, explicitly state which
   section was truncated and why — even if the section cut was
   "Recently completed" (the lowest-priority section). Do not treat
   low-priority truncation as routine and skip the notification.

2. Leave a marker in the file. Replace the truncated content with a
   single line in the affected section pointing to where the
   information actually lives:
     [Truncated — see SESSIONS.md SESS-NNN for this session's output]
   This means the session-start read of CONTEXT.md surfaces the gap
   explicitly rather than presenting a silently-incomplete snapshot as
   if it were whole. The reader knows something was cut and exactly
   where to find it — the information is recoverable, not invisible.

If truncation is occurring frequently (more than once every 3-4
sessions), treat this as a signal that the 30-line cap is too tight
for this project's actual complexity and raise the cap rather than
normalising repeated truncation. The cap is a discipline tool, not a
hard technical constraint — raising it by 10-20 lines costs negligible
tokens against the session-start footprint.

## Relationship to memory/DECISIONS.md
Open questions is for things not yet formalized as a decision. It is
explicitly not a lightweight substitute for `decide` — if something
has been sitting here across 3 sessions, it has already demonstrated
it matters enough to log properly.

---

## Example — fully populated CONTEXT.md

[2026-06-24] [v1.1.0] Reviewing schemas; CONTEXT and BRIEF still need passes.

## Current focus
Running adversarial review passes on each schema file in turn before
moving to platform-specific wiring and the HOW-TO-USE.md.

## Active blockers
None

## Open questions
- Should BRIEF-TEMPLATE.md's MAJOR/MINOR/PATCH versioning rules go
  through an adversarial pass before being treated as locked?

## Recently completed
- AGENTS.md finalized and saved as artifact.
- DECISIONS-SCHEMA.md finalized across three review passes.
- SESSIONS-SCHEMA.md revised: formatting template expanded to three
  concrete examples; Next steps field re-justified as audit trail.

---

## Example — minimal CONTEXT.md (research-only session)

[2026-06-25] [v1.0.0] Research phase complete; ready to begin scaffold script.

## Current focus
Writing project-init.sh scaffold script.

## Active blockers
None

## Open questions
None

## Recently completed
None

---

## Example — CONTEXT.md with truncation marker applied

[2026-07-10] [v1.2.0] Mid-sprint; three features in parallel, recently completed
truncated.

## Current focus
Auth flow refactor, payment integration groundwork, and API rate-limit
handling — all active in parallel this sprint.

## Active blockers
Waiting on staging credentials from DevOps before payment integration
can be tested end-to-end.

## Open questions
- Should rate-limit retries use exponential backoff or fixed intervals?

## Recently completed
[Truncated — see SESSIONS.md SESS-022 for this session's output]

---

## Example — CONTEXT.md at start of a new phase (phase-transition reset)

[2026-09-01] [v2.0.0] Phase 2 started — notifications and integrations now in scope.

## Current focus
Scoping the Twilio integration (DEC-031 resolved). First working
session of phase 2.

## Active blockers
None

## Open questions
None

## Recently completed
None
