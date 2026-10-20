# CONTEXT.md — Snapshot Schema

CONTEXT.md is fully overwritten on every `wrap-up` run — never appended
to, never edited in place between sessions. It reflects the current live
state only; history lives in memory/SESSIONS.md instead.

## Branch-merge policy
Because CONTEXT.md is fully overwritten, two branches that each ran
`wrap-up` will produce two incompatible versions of the whole file —
an ordinary git merge conflict, not a partial one. Resolution, done by
hand by whoever merges (including in GitHub's web editor): the `wrap-up` with
the later date on its first line wins (keep that version of the file as-is; on a
tie, keep the version from the branch being merged in); do not attempt to
hand-merge the two snapshots line by line. One exception: open `ITEM-NNN` items
(Active blockers and Open questions) that appear only in the losing version are
carried over into the kept version unchanged, with their IDs, because nothing
else records them, unless the merged SESSIONS.md records that item as closed. If
that pushes the file past its line cap, the next `wrap-up`'s overflow check
resolves it. The next `wrap-up` to run after the merge regenerates CONTEXT.md
fresh from its own read-before-write pass, so
anything genuinely still relevant from the losing branch's snapshot
gets a chance to be re-surfaced then, not reconstructed by the merge
itself.

## ID format
`ITEM-NNN`, zero-padded to 3 digits, never reused. One namespace covers
Open questions, Active blockers, and SESSIONS.md's Next steps — items
move between these categories over time (a Next step becomes a
blocker, an open question becomes a next step), so a single shared
numbering space avoids re-identifying an item when its category
changes. A category change is not a closure — see "moved to" in the
closure vocabulary below.

Assigned by `wrap-up` when an item is genuinely new: scan the current
CONTEXT.md snapshot for the highest `ITEM-NNN` already in use, **and**
scan memory/SESSIONS.md's Closed notes (live file and
SESSIONS-ARCHIVE/, if it exists) for the highest number ever recorded
as closed — mint one above whichever of the two is higher. If neither
scan finds anything (nothing is currently open and nothing has ever
been closed), start at `ITEM-001`. Checking only the current snapshot
is not enough: once the highest-numbered open item closes while a
lower-numbered one is still open, the snapshot's own visible maximum
drops, and minting from it alone would reuse a retired number. No
counter line, no cross-file *coordination*
(this is a read, not a shared piece of state two branches both have
to edit) — ID collisions across branches are not prevented upstream;
they are caught downstream by `memory-id-check` (where the project has it)
and fixed by hand.

Unlike `DEC-NNN`/`SESS-NNN`, there is no append-only archive of
`ITEM-NNN` definitions — CONTEXT.md is fully overwritten each run, so
an ID's presence there reflects only its current open/unresolved
state. The historical record of an ID's lifecycle lives in that
session's memory/SESSIONS.md entry instead, written as a closure note
— never in CONTEXT.md itself, and never silently.

### Closure vocabulary
When an item stops being open, that session's SESSIONS.md entry
records why, using exactly one of:
- **resolved** — the question was answered or the blocker cleared,
  without a formal `decide` entry.
- **decided per DEC-NNN** — a `decide` entry now covers this item.
  Always use this instead of "resolved" when a decision was actually
  logged — "resolved" must not be used as a vaguer substitute.
- **deferred per DEC-NNN** — formally set aside via `decide`. The item
  leaves Open questions; it does not keep recurring as stale, because
  a conscious decision already covers it.
- **merged into ITEM-MMM** — this item's identity ends; ITEM-MMM
  (the lowest-numbered of the group, a fixed tiebreaker) continues.
- **split into ITEM-MMM, ITEM-NNN** — this item's identity ends; the
  resulting items are new IDs, recorded on the parent's closure line.
  This one line records the relationship in both directions — the
  new items don't need (and have no field to carry) a note of their
  own pointing back.
- **dropped** — no longer relevant, and none of the above applies
  (e.g. a phase-transition scope change). Always requires asking the
  user first — see "Phase-transition reset" below.
- **moved to [section]** — not a closure. The item is still open,
  just now shown under a different CONTEXT.md section (or in
  SESSIONS.md's Next steps). Written so the item's disappearance from
  its old section isn't mistaken for a real closure.

If `wrap-up` ever detects a duplicated or reused ID (e.g. from a bad
hand-edit, or two branches that both assigned a new ID before
merging), re-mint the later one (in file order) under a fresh ID and
note "ITEM-NNN re-minted as ITEM-MMM" in that session's SESSIONS.md
entry. This is a rare, hand-resolved event, not something the
ID-assignment mechanism tries to prevent by construction.

Items without an ID (from before this scheme existed, or carried over
from a project that hasn't run a `wrap-up` since adopting it) are valid
and are not retroactively assigned one — backfill is out of scope. A
new ID is assigned the first time such an item would otherwise be
rewritten by a `wrap-up` run.

**Accepted residual risk:** nothing mechanically stops an item from
being closed and a near-identical item reopened as "new" to dodge the
3-session staleness check (see Open questions below). No fix is
applied for this — it would require reintroducing judgment-based
prose matching, which this scheme exists to avoid. Revisit if CAMP
moves toward more autonomous, less human-reviewed operation.

## Process — read before write
Before generating new content, `wrap-up` reads the existing CONTEXT.md
in full. Items in the previous snapshot carry forward unless one of
these conditions applies:
- The item is now complete — move it to "Recently completed" if still
  relevant for continuity, otherwise drop it (with a closure note,
  per the vocabulary above).
- The item has been superseded by new information this session.
- The item moved to a different section (not a closure — write
  "moved to [section]", per the vocabulary above).
Nothing is silently dropped — if an item is being removed for any
reason other than the above, surface this to the user before writing.
Active blockers, Open questions, and Current focus can no longer be
removed just to fit the line cap — see "Hard cap and overflow
handling" below for what happens when the file genuinely overflows.

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
version meant to orient a reader in under 10 words — counting only
the summary sentence itself; neither bracketed prefix (`[YYYY-MM-DD]`
or `[vX.Y.Z]`) counts toward that budget.

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
   - If it's relevant to the new phase's scope, carry it forward (same
     ID).
   - If it was phase-1-specific and no longer applies, **ask the user
     before dropping it** — "This open question from the previous
     phase may no longer apply — carry forward or drop?" There is no
     auto-drop case; a phase boundary never waives asking. If dropped,
     the closure note ("ITEM-NNN dropped") is still required in that
     session's SESSIONS.md entry — the phase boundary changes nothing
     about the record, only confirms the user agreed to it.
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
consolidate to the highest-priority one and note "plus N others"
rather than expanding past the per-section guide. Never cut for space
— see "Hard cap and overflow handling" below.

Paused and In Progress plans (found by `wrap-up` scanning the plans
folder) each get one short line here: the plan's name and, for Paused,
why it is on hold. Beyond three, name the three most recent and add
"plus N others". These lines are part of Current focus, so they are
also never cut for space.

## Active blockers
0-3 lines, or "None" — a guide, not a binding sub-limit: since this
section is never cut for space (see "Hard cap and overflow handling"
below), the only real ceiling on it is the whole-file cap, not this
number. A blocker is something external or unresolved that is
actively preventing progress right now — not a concern, not a
question, but a concrete dependency that cannot be worked around without
resolving it first. If it can be worked around, it's an Open question,
not a blocker. Each line is a bullet prefixed `ITEM-NNN:` (see ID
format above) — never a prefix on the literal value "None", and never
more than one item per line.

## Open questions
0-3 lines, or "None" — a guide, not a binding sub-limit, same as
Active blockers above: this section is also never cut for space, so
the whole-file cap is the only real ceiling. Things unresolved that
aren't yet a logged decision and aren't actively blocking progress.
The distinction from Active blockers: work can continue in parallel
while these sit open. Once something here becomes a real decision
point (something that would otherwise get re-litigated later), move
it through the `decide` skill rather than letting it live here
indefinitely. Each line is a bullet prefixed `ITEM-NNN:` (see ID
format above) — never a prefix on the literal value "None", and never
more than one item per line. If the same ID appears in Open questions
across 3 or more
consecutive sessions without resolving — a check deterministic by ID,
not judged by prose similarity — `wrap-up` must flag this to the user
and prompt a decision to either formally decide it via `decide` or
formally defer it — not silently carry it forward again.

## Recently completed
0-5 lines. What just finished, included for continuity across the
session boundary. Not a full log — that's what SESSIONS.md is for.
Zero is valid (write "None") for sessions where nothing was
completed, such as a pure research or planning session. This is the
only section that may still be cut for space.

## Hard cap and overflow handling
Maximum 40 lines total. Every line counts toward this cap, including:
section headers, the state pointer, blank lines between sections, and
content lines. Blank lines between sections are part of the format —
do not remove them to squeeze under the cap.

Current focus, Active blockers, and Open questions are never cut.
Only Recently completed may be trimmed (cut oldest items first, then
omitted entirely if still over cap). If the file still doesn't fit
after fully clearing Recently completed, that is overflow, handled as
follows — never a silent cut of a never-cut section:

1. **Resolve or defer something now, via `decide`** — the preferred
   path. Brings the file back under 40 lines for real.
2. **A one-time, explicitly logged exception: +5 lines (45 max).**
   Record it as a marker line in that session's SESSIONS.md entry (see
   memory/SESSIONS-SCHEMA.md for the exact format). Before offering
   this option, `wrap-up` checks the immediately prior SESSIONS.md
   entry: if it already used this marker, the exception is not
   available again — option 1 is the only path this time. This check
   must happen, and the overflow decision must be made, **before**
   that session's SESSIONS.md entry is composed — not after — so the
   marker (or its absence) is correctly reflected in the entry being
   written.
3. If option 1 would require a decision the user isn't ready to make
   and option 2 isn't available (already used last session), `wrap-up`
   must still be able to end the session — do not let this become a
   deadlock. Surface this explicitly and accept the user's call on how
   to proceed, the same way a Stop hook's second attempt is allowed to
   succeed rather than loop forever.

If the exception marker (option 2) is used in 2 or more of the last 3
sessions, flag this to the user as a signal that the base 40-line cap
itself should be raised for real, rather than continuing to lean on
one-time exceptions.

## Truncation — visibility rules
Only Recently completed can be truncated under this scheme. When it is,
two mandatory outputs still apply:

1. Tell the user. Before finishing `wrap-up`, explicitly state that
   Recently completed was trimmed and why.

2. Leave a marker in the file:
     [Truncated — see SESSIONS.md SESS-NNN for this session's output]
   The reader knows something was cut and exactly where to find it —
   the information is recoverable, not invisible.

If this is occurring frequently (more than once every 3-4 sessions),
treat it as a signal this project generates unusually heavy
session-to-session output, worth a Notes mention — though note that
Recently completed being trimmed is lower-stakes than the overflow
handling above, since nothing here is a never-cut section.

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
- ITEM-003: Should BRIEF-TEMPLATE.md's MAJOR/MINOR/PATCH versioning
  rules go through an adversarial pass before being treated as locked?

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
- ITEM-011: Waiting on staging credentials from DevOps before payment
  integration can be tested end-to-end.

## Open questions
- ITEM-014: Should rate-limit retries use exponential backoff or fixed
  intervals?

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
